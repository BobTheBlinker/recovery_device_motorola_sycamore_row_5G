#!/bin/bash
set -euo pipefail

if [[ $# -ne 4 ]]; then
    echo "usage: $0 PRODUCT_OUT DEVICE_TREE MKBOOTIMG AVBTOOL" >&2
    exit 2
fi

product_out=$1
device_tree=$2
mkbootimg=$3
avbtool=$4

platform_ramdisk="$device_tree/prebuilt/vendor_ramdisk/platform.cpio.lz4"
recovery_ramdisk="$product_out/obj/PACKAGING/vendor_ramdisk_fragments_intermediates/recovery.cpio.lz4"
recovery_root="$product_out/recovery/root"
filtered_recovery_root=""
keystore2_source="$product_out/system/bin/keystore2"
keystore2_crypto_source="$product_out/system/lib64/libkeystore2_crypto.so"
keystore2_staged="$recovery_root/system/bin/keystore2"
keystore2_crypto_staged="$recovery_root/system/lib64/libkeystore2_crypto.so"
dtb="$product_out/dtb.img"
output="$product_out/vendor_boot.img"
raw_output="$product_out/vendor_boot.pre-avb.img"
temporary_output="$product_out/vendor_boot.assembling.img"
host_bin="$(dirname "$mkbootimg")"
mkbootfs="$host_bin/mkbootfs"
lz4="$host_bin/lz4"

cleanup() {
    if [[ -n "$filtered_recovery_root" && -d "$filtered_recovery_root" ]]; then
        rm -rf -- "$filtered_recovery_root"
    fi
}
trap cleanup EXIT

expected_keystore2=31a9f7d9de497e06c465343ddb4d3aa3e8064c3051059c206b53d061d59f6256
expected_keystore2_crypto=6e46dbfbf135c41131d64b91ce93fedf7c62077059fdbc24a5ca62b94e195132

for required in "$platform_ramdisk" "$recovery_ramdisk" "$dtb" "$mkbootimg" "$avbtool" \
                "$mkbootfs" "$lz4" "$keystore2_source" "$keystore2_crypto_source"; do
    if [[ ! -f "$required" ]]; then
        echo "missing required input: $required" >&2
        exit 1
    fi
done

verify_hash() {
    local file=$1
    local expected=$2
    local actual
    actual=$(sha256sum "$file" | cut -d ' ' -f 1)
    if [[ "$actual" != "$expected" ]]; then
        echo "unexpected SHA-256 for $file: $actual (expected $expected)" >&2
        exit 1
    fi
}

# TWRP's relink phony targets express their source modules as order-only
# dependencies.  A rebuilt executable or library can therefore leave an older
# copy in recovery/root.  Refresh this critical pair from their canonical
# build outputs immediately before archiving, and fail closed on either hash.
verify_hash "$keystore2_source" "$expected_keystore2"
verify_hash "$keystore2_crypto_source" "$expected_keystore2_crypto"
install -m 0755 "$keystore2_source" "$keystore2_staged"
install -m 0644 "$keystore2_crypto_source" "$keystore2_crypto_staged"
verify_hash "$keystore2_staged" "$expected_keystore2"
verify_hash "$keystore2_crypto_staged" "$expected_keystore2_crypto"

(
    cd "$recovery_root"
    find -type f \
        | sed '\|^./ramdisk-files.sha256sum$|d' \
        | sed '\|/lib/modules|d' \
        | sed '\|^./prop.default$|d' \
        | sort \
        | xargs sha256sum > ramdisk-files.sha256sum
)

# The pristine PLATFORM fragment already supplies the complete module tree,
# including the normal and recovery load lists.  Sycamore's boot chain exposes
# later RECOVERY paths during normal first stage, so duplicate module metadata
# here can shadow PLATFORM's normal modules.load.  Filter only the archive input;
# leave recovery/root and the stock PLATFORM fragment untouched.
filtered_recovery_root=$(mktemp -d "$product_out/recovery-root-filtered.XXXXXX")
cp -a "$recovery_root/." "$filtered_recovery_root/"
rm -rf -- "$filtered_recovery_root/lib/modules"
test ! -e "$filtered_recovery_root/lib/modules"

"$mkbootfs" -d "$product_out/system" "$filtered_recovery_root" \
    | "$lz4" -l -12 --favor-decSpeed > "$recovery_ramdisk"

# PLATFORM must be first because its stock recovery files overlap paths in the
# generated RECOVERY archive. The recovery CPIO is therefore the later overlay.
"$mkbootimg" \
    --header_version 4 \
    --pagesize 4096 \
    --base 0x40000000 \
    --kernel_offset 0x00000000 \
    --ramdisk_offset 0x26f00000 \
    --tags_offset 0x07c80000 \
    --dtb_offset 0x07c80000 \
    --vendor_cmdline "bootopt=64S3,32N2,64N2" \
    --dtb "$dtb" \
    --vendor_ramdisk "$platform_ramdisk" \
    --ramdisk_type RECOVERY \
    --ramdisk_name recovery \
    --vendor_ramdisk_fragment "$recovery_ramdisk" \
    --vendor_boot "$temporary_output"

mv -f "$temporary_output" "$raw_output"
cp -f "$raw_output" "$output"

# Match the pristine algorithm-NONE hash-footer structure. This authenticates
# the image contents but deliberately invents no RSA key.
"$avbtool" add_hash_footer \
    --image "$output" \
    --partition_size 67108864 \
    --partition_name vendor_boot \
    --salt 11503e95ee971adc6c444e3ae47f564f178032ee9bbcf99d2ccfdc0895c67ed7 \
    --prop 'com.android.build.vendor_boot.fingerprint:Motorola/XT2575-4/XT2575-4:15/AP3A.240905.015.A2/9bdeac_017:user/release-keys'

test "$(stat -c %s "$output")" -eq 67108864
sha256sum "$platform_ramdisk" "$recovery_ramdisk" "$dtb" "$raw_output" "$output"
"$avbtool" info_image --image "$output"
