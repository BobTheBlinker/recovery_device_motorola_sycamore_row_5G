# V17 stock THH identity static audit

Date: 2026-08-27

Result: **PASS — controlled stock-THH/product-identity experiment; not flashed.**

Artifact SHA-256:
`f23330a09d0b0ea4a7c902342dd62f36dcf5179cd72ed40d316819deb7c9ec50`

Artifact size: 67,108,864 bytes.

## Hypothesis

V16 initialized Microtrust with an incomplete `/vendor/thh/ta` namespace and
the recovery codename as `ro.product.device`.  The exact signed stock model
configuration recognizes `platform=mt8755`, `model=XT2575-4`, while V16 secure
world logged `model:sycamore_row_5G`, model verification failures, and TA load
error 18.  V17 tests whether presenting the complete exact-stock THH payload
and production Microtrust-facing identity before the first `teei_daemon`
launch restores cold TA/model validation and changes cmd 0x18 behavior.

All V16 FBE/logini behavior and crypto diagnostics are retained unchanged.

## Exact stock source

The files were copied from the preserved exact-firmware vendor extraction:

`/home/nicholas/Downloads/sycamore-twrp-info/first-hardware-boot/fbe-a16-v3/ta-forensics/stock-vendor-thh/ta`

This extraction belongs to factory baseline
`XT2575-4_ROW_OPEN_USER_M1317.3_W_ZUI_17.5.10.017_ST`.  Both the staged source
tree and the final unpacked recovery fragment were compared byte-for-byte with
all 15 source files.  Both comparisons pass.

## Stock THH manifest

| File | Bytes | SHA-256 |
|---|---:|---|
| `0102030405060708090a0b0c0d0e0f10.ta` | 20,777 | `19a5e15a2f17a6c1418c5edc6fc63a3ddd279966540930b2e97f227ce0d897ae` |
| `020f0000000000000000000000000000.ta` | 22,649 | `aba910dfbdccbf177eb107853669c6eff689b4f36e9afb2f8e04e30d8e97108b` |
| `06090000000000000000000000000000.ta` | 6,953 | `2d5cd2e906a1dab1636c59bbe037f8502aec7c25edc9172cba8da158fc6d8c36` |
| `08030000000000000000000000000000.ta` | 24,393 | `ba29286b7d24edc04275b195db120032e116828ff73241241d6d8c40855b4f03` |
| `08110000000000000000000000000000.ta` | 72,073 | `0fb3e0b70a972d4a58088978aec706399009f32f5133061efe6b7033f1ae9f17` |
| `40188311faf343488db888ad39496f9a.ta` | 9,177 | `5cb79b594721523700fe4708ea764c80144979dc698db27a18a2383159028a1c` |
| `5020170115e016302017012521300000.ta` | 10,393 | `0865a891c965a201d4e64f3b9e2f4a3f0fe899f80ff24ab88cf75b1622dc5d40` |
| `5f7a5b3b29b041bca249524a031a00e3.ta` | 32,737 | `2911bd3726ae4110877409d501329f36f5958a6686262b93814d8bb89fdb629c` |
| `8888c04fc30c4dd0a319ea29643d4d4c.ta` | 32,129 | `5b812b524f5eea79c1bc944b06d00cddc8738274166d888bf255080ab0feab09` |
| `abcd270ea5c44c58bcd3384a2fa2539e.ta` | 39,833 | `c4d5811efd695ba0550960f9c5649e6476289cbb00cb8c9d7f5cb11b7a2e2f18` |
| `c09c9c5daa504b78b0e46eda61556c3a.ta` | 930,857 | `af4d1dc971c80b539de9e73ee792285944dd9b132d267be3bb0496bd82bb75ab` |
| `c1882f2d885e4e13a8c8e2622461b2fa.ta` | 55,537 | `0a5f34be1d73535c563aaece231b2e93193ae5f2c69b8050e71b14f48956081d` |
| `d91f322ad5a441d5955110eda3272fc0.ta` | 22,177 | `4432d3f85370e41f57bf5fb6b5945326c441a394d0cbe298be5c29b2b056b954` |
| `e97c270ea5c44c58bcd3384a2fa2539e.ta` | 447,769 | `c76352a8115aba85e963d2e39466530daa8ac5db411ccea403eaf84d2c308e96` |
| `isee_model.json` | 2,794 | `67c019209942f9a68408d998e5d478b0dba5e3f5dbbc6582b146af8aaa05e3c6` |

## Source/change scope

- `device/motorola/sycamore_row_5G/device.mk`
  - packages all 15 stock THH files and the early diagnostic script;
  - adds only global `ro.product.device=XT2575-4` to the existing V16 initial
    system-default property set.
- `build/make/core/Makefile`
  - recovery-only, target-gated, fail-closed replacement of the two generated
    vendor device/name values in final `prop.default`; vendor model was already
    stock-correct.
- `device/motorola/sycamore_row_5G/recovery/root/init.recovery.crypto.rc`
  - synchronously executes the readiness diagnostic immediately before the
    existing first `start teei_daemon`.
- `device/motorola/sycamore_row_5G/recovery/root/system/bin/syca_v17_thh_ready.sh`
  - logs only public properties, four existence results, and total file count.
- fourteen stock THH files were added under
  `device/motorola/sycamore_row_5G/recovery/root/vendor/thh/ta`; the fifteenth,
  the KeyMint TA, was already present and byte-identical.

## Final initial properties

- `ro.product.device=XT2575-4`
- `ro.product.vendor.device=XT2575-4`
- `ro.product.vendor.name=XT2575-4`
- `ro.product.vendor.model=XT2575-4`
- `ro.build.product=sycamore_row_5G` (preserved)
- `ro.crypto.type=file` (V16 preserved)
- `ro.crypto.state=encrypted` (V16 preserved)

`PRODUCT_DEVICE=sycamore_row_5G`, the TWRP product name, target assertions, and
`ro.twrp.target.devices` behavior were not changed.

## Cold-boot ordering

1. Recovery ramdisk, all 15 THH files, production identity, and V16 FBE
   properties exist before init actions.
2. Existing TEE/RPMB nodes and read-only persist mount are prepared.
3. Init synchronously runs `syca_v17_thh_ready.sh` and emits
   `SYCA_V17_THH_READY`; expected `thh_file_count=15`.
4. Init launches the unchanged exact-stock `teei_daemon` for the first time.
5. The daemon performs cold secure-world TA/model validation.
6. Existing `init.svc.teei_daemon=running` action starts Beanpod/Gatekeeper.
7. Existing V16 healthy-state conjunction sets `logini=start`.
8. Existing vold/Keystore2 path reaches the first cmd 0x18.

No sleep, restart, bind mount, or post-initialization substitution was added.

## V16-to-V17 final-image differential

Complete unpacked relative-path SHA-256 manifests show only:

- modified: `init.recovery.crypto.rc`, `prop.default`, and generated ramdisk
  inventory files;
- added: readiness script and the 14 THH files absent from V16;
- unchanged: `system/bin/recovery`, existing KeyMint TA, all secure binaries,
  private libraries, Keytrace, and every other ramdisk payload.

## Frozen architecture/binary verification

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
- Keytrace:
  `0642e36b25589ebdf16423cb3a81c8ba5dab3ffc0dcb32a58386efa8b2d7293d`

The final recovery has zero `.ko` files and the same five module metadata
files.  V16 `SYCA_V16_PRE_0X18`, `SYCA_SOTER_PRE_0X18`,
`SYCA_DEKEY_A/B/C/D`, and `SYCA_TA_TRACE` markers remain present.

## Final vendor_boot audit

- header v4; page size 4096
- cmdline `bootopt=64S3,32N2,64N2`; bootconfig empty
- fragment 0: unnamed PLATFORM/type 1, 27,422,144 bytes, exact stock hash
- fragment 1: `recovery`/type 2, 32,078,301 bytes
- total vendor ramdisk: 59,500,445 bytes
- stock DTB exact; all board IDs zero
- PLATFORM first, RECOVERY second
- algorithm-NONE AVB footer and vendor_boot hash verify
- final image re-unpacks successfully
- final partition-padded size exactly 67,108,864 bytes

Static audit: **PASS. Stop before flashing.**
