DEVICE_PATH := device/motorola/sycamore_row_5G

# Architecture (64-bit recovery; runtime CPU properties identify Cortex-A55/A76 cores).
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := generic
TARGET_CPU_VARIANT_RUNTIME := cortex-a55
TARGET_USES_64_BIT_BINDER := true

# Platform and assertions.
TARGET_BOARD_PLATFORM := mt6835
TARGET_BOOTLOADER_BOARD_NAME := sycamore_row_5G
TARGET_NO_BOOTLOADER := true
TARGET_OTA_ASSERT_DEVICE := sycamore_row_5G,XT2575-4
# Stock first API level is 35, but twrp-12.1 is an API 32 build and rejects a
# BOARD_SHIPPING_API_LEVEL newer than its platform SDK. Keep the measured value
# in the bring-up log rather than emitting a false API-32 build property.

# The stock Beanpod KeyMint service configures its TA from these properties.
# Pristine A16 vendor_boot supplies 2026-07-05 for both, and the live metadata
# key blob is bound to OS patch level 202607.  Leaving the TWRP 12.1 defaults
# (202204 / empty) makes secure world reject that newer blob as a downgrade.
# These are exact stock inputs, not the old twrpdtgen 2099 bypass.
PLATFORM_SECURITY_PATCH := 2026-07-05
VENDOR_SECURITY_PATCH := 2026-07-05

# Exact factory kernel, DTB, and vendor_boot v4 header addresses. These values
# are mechanically extracted from the pristine ZUI 17.5 vendor_boot image.
TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/kernel
BOARD_INCLUDE_DTB_IN_BOOTIMG := true
BOARD_PREBUILT_DTBIMAGE_DIR := $(DEVICE_PATH)/prebuilt/dtb
BOARD_BOOT_HEADER_VERSION := 4
BOARD_KERNEL_PAGESIZE := 4096
BOARD_KERNEL_BASE := 0x40000000
BOARD_RAMDISK_USE_LZ4 := true
BOARD_KERNEL_SEPARATED_DTBO := true
BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOT_HEADER_VERSION)
BOARD_MKBOOTIMG_ARGS += --kernel_offset 0x00000000
BOARD_MKBOOTIMG_ARGS += --ramdisk_offset 0x26f00000
BOARD_MKBOOTIMG_ARGS += --tags_offset 0x07c80000
BOARD_MKBOOTIMG_ARGS += --dtb_offset 0x07c80000
BOARD_MKBOOTIMG_ARGS += --vendor_cmdline "bootopt=64S3,32N2,64N2"

# Preserve the pristine stock vendor ramdisk byte-for-byte as the unnamed base
# PLATFORM ramdisk. AOSP then appends the generated TWRP RECOVERY fragment.
# This matches the factory vendor_boot v4 layout and preserves overlay ordering.
BOARD_PREBUILT_VENDOR_RAMDISK := \
    $(DEVICE_PATH)/prebuilt/vendor_ramdisk/platform.cpio.lz4

# Physical partition sizes measured from GPT/factory images.
BOARD_BOOTIMAGE_PARTITION_SIZE := 67108864
BOARD_VENDOR_BOOTIMAGE_PARTITION_SIZE := 67108864
BOARD_INIT_BOOT_IMAGE_PARTITION_SIZE := 8388608
BOARD_DTBOIMG_PARTITION_SIZE := 8388608
BOARD_PREBUILT_DTBOIMAGE := $(DEVICE_PATH)/prebuilt/dtbo.img

# Live liblp metadata: v10.2, 64 KiB max metadata, three slots, virtual A/B.
BOARD_SUPER_PARTITION_SIZE := 11811160064
BOARD_SUPER_PARTITION_GROUPS := main_dynamic_partitions
BOARD_MAIN_DYNAMIC_PARTITIONS_SIZE := 11809062912
# API-32 build/make cannot generate system_dlkm. It remains in recovery.fstab
# and live liblp metadata; this recovery-only target does not build super.
BOARD_MAIN_DYNAMIC_PARTITIONS_PARTITION_LIST := \
    odm_dlkm product system system_ext vendor vendor_dlkm

TARGET_COPY_OUT_SYSTEM_EXT := system_ext
TARGET_COPY_OUT_PRODUCT := product
TARGET_COPY_OUT_VENDOR := vendor
TARGET_COPY_OUT_VENDOR_DLKM := vendor_dlkm
TARGET_COPY_OUT_ODM_DLKM := odm_dlkm

BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_SYSTEM_EXTIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_VENDOR_DLKMIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_ODM_DLKMIMAGE_FILE_SYSTEM_TYPE := erofs
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := f2fs
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true

# Recovery lives in vendor_boot. AOSP build/make emits a v4 RECOVERY ramdisk
# fragment when both switches below are true; stock's platform fragment already
# proves that all recovery resources belong in vendor_boot on this device.
TARGET_NO_RECOVERY := true
TW_HAS_NO_RECOVERY_PARTITION := true
BOARD_EXCLUDE_KERNEL_FROM_RECOVERY_IMAGE := true
BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT := true
BOARD_INCLUDE_RECOVERY_RAMDISK_IN_VENDOR_BOOT := true
# Optional A-Team dual-boot layout
# N = standard metadata / userdata
# Y = secondary metadata2 / userdata2
SYCA_DUALBOOT ?= N

ifeq ($(strip $(SYCA_DUALBOOT)),Y)
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/recovery-dualboot.fstab
else
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/recovery.fstab
endif
# PLATFORM already provides the complete stock module tree. Remove the duplicate
# device recovery metadata after recovery-root population and before mkbootfs;
# otherwise its recovery-oriented modules.load shadows the stock normal list.
# Final recovery-root preparation:
# - remove duplicate recovery module metadata so the pristine PLATFORM ramdisk wins
# - present the exact production XT2575-4 vendor identity before Microtrust starts
BOARD_RECOVERY_IMAGE_PREPARE = test -n "$(TARGET_RECOVERY_ROOT_OUT)" && \
    rm -rf -- "$(TARGET_RECOVERY_ROOT_OUT)/lib/modules" && \
    sed -i \
        -e 's/^ro.product.vendor.device=sycamore_row_5G$$/ro.product.vendor.device=XT2575-4/' \
        -e 's/^ro.product.vendor.name=twrp_sycamore_row_5G$$/ro.product.vendor.name=XT2575-4/' \
        "$(TARGET_RECOVERY_ROOT_OUT)/prop.default" && \
    grep -Fqx 'ro.product.device=XT2575-4' "$(TARGET_RECOVERY_ROOT_OUT)/prop.default" && \
    grep -Fqx 'ro.product.vendor.device=XT2575-4' "$(TARGET_RECOVERY_ROOT_OUT)/prop.default" && \
    grep -Fqx 'ro.product.vendor.name=XT2575-4' "$(TARGET_RECOVERY_ROOT_OUT)/prop.default" && \
    grep -Fqx 'ro.product.vendor.model=XT2575-4' "$(TARGET_RECOVERY_ROOT_OUT)/prop.default" && \
    grep -Fqx 'ro.build.product=sycamore_row_5G' "$(TARGET_RECOVERY_ROOT_OUT)/prop.default"
TARGET_RECOVERY_PIXEL_FORMAT := RGBX_8888
BOARD_HAS_NO_SELECT_BUTTON := true

# Exact production teei_daemon domain and narrowly scoped Microtrust
# device labels.  The platform policy already defines tee/tee_exec and its
# init transition; this directory supplies only Sycamore-specific paths/types.
BOARD_VENDOR_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy/vendor

# Display values measured from Android.
TARGET_SCREEN_WIDTH := 1600
TARGET_SCREEN_HEIGHT := 2560
TARGET_SCREEN_DENSITY := 320
TW_THEME := portrait_hdpi
TW_FRAMERATE := 30
TW_CUSTOM_CPU_TEMP_PATH := /sys/class/thermal/thermal_zone0/temp

# A/B, dynamic partitions, fastbootd and storage.
AB_OTA_UPDATER := true
TW_INCLUDE_FASTBOOTD := true
# Preserve the device recovery.fstab mount options. The stock additional fstab
# otherwise reparses /metadata and drops its recovery-only context= option.
TW_SKIP_ADDITIONAL_FSTAB := true
TW_INTERNAL_STORAGE_PATH := "/data/media/0"
TW_INTERNAL_STORAGE_MOUNT_POINT := "data"
TW_USB_STORAGE := false
# TWRP 12.1's APEX loader is incompatible with this recovery's crypto path.
# Sycamore packages the required Android 16 crypto binaries and libraries
# directly in the recovery ramdisk, so recovery APEX mounting is unnecessary.
TW_EXCLUDE_APEX := true

# Stock FBE v2 with metadata encryption.
TW_INCLUDE_CRYPTO := true
TW_INCLUDE_CRYPTO_FBE := true
TW_INCLUDE_FBE_METADATA_DECRYPT := true
BOARD_USES_METADATA_PARTITION := true

# Bring-up/debug essentials; no missing-dependency escape hatch.
TARGET_USES_LOGD := true
TWRP_INCLUDE_LOGCAT := true
TW_INCLUDE_REPACKTOOLS := true
TW_INCLUDE_RESETPROP := true
TW_INCLUDE_LIBRESETPROP := true
TW_EXCLUDE_DEFAULT_USB_INIT := true
TW_DEFAULT_LANGUAGE := en
TW_EXTRA_LANGUAGES := true
TW_USE_SERIALNO_PROPERTY_FOR_DEVICE_ID := true
# Preserve the exact factory vendor_boot AVB fingerprint independently of the
# recovery build fingerprint.
BOARD_AVB_VENDOR_BOOT_FINGERPRINT := Motorola/XT2575-4/XT2575-4:15/AP3A.240905.015.A2/9bdeac_017:user/release-keys

# Match the stock algorithm-NONE vendor_boot hash-footer design. The salt is
# extracted from the pristine footer; no signing key is used or invented.
BOARD_AVB_ENABLE := true
BOARD_AVB_VENDOR_BOOT_ADD_HASH_FOOTER_ARGS += \
    --salt 11503e95ee971adc6c444e3ae47f564f178032ee9bbcf99d2ccfdc0895c67ed7

# Removable storage filesystem support.
TW_INCLUDE_NTFS_3G := true

# Platform-side TWRP FBE property definition.
SYSTEM_EXT_PUBLIC_SEPOLICY_DIRS += device/motorola/sycamore_row_5G/sepolicy/public

# Platform-side TWRP FBE property context.
SYSTEM_EXT_PRIVATE_SEPOLICY_DIRS += device/motorola/sycamore_row_5G/sepolicy/private
