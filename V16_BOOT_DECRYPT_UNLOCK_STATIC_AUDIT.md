# V16 boot-decrypt-unlock static audit

Date: 2026-08-27

Result: **PASS — one-variable boot-decrypt lifecycle experiment; not flashed.**

Artifact SHA-256:
`1fe86baa602403638e2f0c0b2b7a29bc4cd768ec2bed9256b12aa92c8ca81e09`

Artifact size: 67,108,864 bytes.

## Hypothesis

The exact stock `teei_daemon` snapshots `ro.crypto.state` and
`ro.crypto.type` in its boot-decrypt thread.  With `ro.crypto.type=file`, it
logs `fbe mode late` and issues the `/dev/teei_config` boot-decrypt-unlock
ioctl.  V15 did not expose that initial FBE state and never set
`vendor.soter.teei.logini=start`; consequently it showed neither the daemon
unlock message nor a boot-decrypt-lock result before cmd 0x18.

V16 tests whether reproducing those stock lifecycle inputs before the first
storage-key conversion changes cmd 0x18 from `KM_ERROR_INVALID_KEY_BLOB`.

## Exact source changes

- `device/motorola/sycamore_row_5G/device.mk:16-22`
  - adds `ro.crypto.state=encrypted` and `ro.crypto.type=file` through
    `PRODUCT_SYSTEM_DEFAULT_PROPERTIES`, placing both in the initial recovery
    `prop.default` before `teei_daemon` starts.
- `device/motorola/sycamore_row_5G/recovery/root/init.recovery.crypto.rc:69-73`
  - sets `vendor.soter.teei.logini=start` once the existing Soter init,
    persist-VFS, and RPMB health properties simultaneously report their stock
    terminal values.
- `system/vold/Keymaster.cpp:187-213`
  - adds the secret-free `SYCA_V16_PRE_0X18` state snapshot immediately before
    `convertStorageKeyToEphemeral()`; V15 tracing remains present.

No other functional source was changed for V16.  Cmd 0x18 serialization,
wrapped-key bytes, Beanpod, TA, private libraries, SharedSecret, patch levels,
DTB, PLATFORM, and kernel modules are unchanged.

## Implemented ordering

1. Initial property load exposes the real recovery FBE mode:
   `ro.crypto.state=encrypted`, `ro.crypto.type=file`.
2. `on init` prepares the existing TEE device nodes and starts the exact stock
   `teei_daemon`.
3. `init.svc.teei_daemon=running` starts Beanpod and Gatekeeper as in V15.
4. Once `vendor.soter.teei.init=INIT_OK`,
   `vendor.soter.teei.persist=OPEN`, and
   `vendor.soter.teei.rpmb.flag=ok` are all true, init sets
   `vendor.soter.teei.logini=start`.
5. Existing vold flow reaches the first storage-key conversion, where V16 logs
   the complete pre-0x18 public-state snapshot.

No sleep or repeated trigger was added.  `vold.post_fs_data_done` and
`vendor.soter.teei.crypto.state` were not set: the exact daemon does not
reference the former, and its `ro.crypto.type=file` startup branch does not
require the latter.

## Final recovery-fragment differential against archived V15

Complete relative-path SHA-256 manifests differ only at:

- `init.recovery.crypto.rc` (intentional logini trigger)
- `prop.default` (intentional two FBE defaults)
- `system/bin/recovery` (intentional V16 marker)
- `ramdisk-files.sha256sum` and `ramdisk-files.txt` (generated inventory)

There are no added or removed payload paths.

## Frozen binary/content verification

- stock PLATFORM:
  `06738f638a745075511c571347c5511331dda16b84d1ee88cda160c2dc7ebb14`
- stock DTB:
  `0e93b71aacf707a5fbb7a58eff73995b92d766a31a98d8d70e91f548c9e1d5af`
- exact stock `teei_daemon`:
  `fb79a0c59dab04edbf5ff4cd10af601c4d3dba5378b5ba3d981553f818fbb014`
- Beanpod:
  `e066ff6e4f0aaa803e6633aa8fad1f54335e5b969f6422fedc44f77b033851e9`
- KeyMint TA:
  `af4d1dc971c80b539de9e73ee792285944dd9b132d267be3bb0496bd82bb75ab`
- Keystore2:
  `31a9f7d9de497e06c465343ddb4d3aa3e8064c3051059c206b53d061d59f6256`
- `libkeystore2_crypto.so`:
  `6e46dbfbf135c41131d64b91ce93fedf7c62077059fdbc24a5ca62b94e195132`

All nine stock KeyMint private-library hashes and the V15 keytrace library hash
match the frozen V15 family.  The recovery fragment contains zero `.ko` files
and only the same five module metadata files.

## Final vendor_boot audit

- header version 4; page size 4096
- command line `bootopt=64S3,32N2,64N2`
- bootconfig empty
- fragment 0: unnamed PLATFORM, type 1, 27,422,144 bytes, exact stock hash
- fragment 1: `recovery`, RECOVERY type 2, 31,679,640 bytes
- total vendor ramdisk size: 59,101,784 bytes
- all board IDs zero; PLATFORM first and RECOVERY second
- exact stock DTB, 192,119 bytes
- algorithm-NONE AVB footer verifies
- final image re-unpacks successfully
- final partition-padded size exactly 67,108,864 bytes

## Expected hardware-test markers

- `SYCA_V16_PRE_0X18`
- `daemon unlock keymaster signal to tz-driver`
- `keymaster unlock boot_decrypt_lock success` or `failed!`
- existing `SYCA_SOTER_PRE_0X18`, `SYCA_DEKEY_A/B/C/D`, `SYCA_TA_TRACE`,
  cmd 0x18 hashes, and cmd result

Static audit: **PASS. Stop before flashing.**
