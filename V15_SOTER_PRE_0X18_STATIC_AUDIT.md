# V15 Soter pre-0x18 state snapshot

Date: 2026-08-27

Result: **PASS — diagnostic-only one-variable build; not flashed.**

Artifact SHA-256:
`d2f542f8d475bc3699487647a041e16235f20847ee43d23e5545b55e6f2b8b1c`

Artifact size: 67,108,864 bytes.

## Hypothesis and change scope

The retained V14 property dump did not prove the exact values of seven public
Microtrust/Soter properties at the instant immediately before the first cmd 0x18.

The only functional source delta from V14 is in
`system/vold/Keymaster.cpp::Keymaster::exportKey()`: immediately after the existing
length/SHA-256 checkpoint B and before
`securityLevel->convertStorageKeyToEphemeral()`, recovery reads and logs:

- `vendor.soter.teei.googlekey.status`
- `vendor.soter.teei.init`
- `vendor.soter.teei.km.init`
- `vendor.soter.teei.km.version`
- `vendor.soter.teei.logini`
- `vendor.soter.teei.persist`
- `vendor.soter.teei.rpmb.flag`

The marker is `SYCA_SOTER_PRE_0X18`. The patch sets no property, changes no
service ordering, changes no request bytes, and exposes no key material.

## Final-image differential

Against the preserved pre-V15 current recovery fragment, complete unpacked-file
SHA-256 manifests differ only at:

- `system/bin/recovery`
  - before: `439d1fa5a5080e3ff5f293d18deb1e34aa21b48dc9ba9fd01e7e982fa83840e3`
  - V15: `53683ad4e34ffb6ebe4ffb705037f224f62334d2e355b5359230cc60e106077a`
- `ramdisk-files.sha256sum`
- `ramdisk-files.txt`

The final recovery binary contains `SYCA_SOTER_PRE_0X18`, the requested property
names, and the existing `SYCA_DEKEY_A/B` diagnostics.

## Frozen final-image hashes

- PLATFORM:
  `06738f638a745075511c571347c5511331dda16b84d1ee88cda160c2dc7ebb14`
- DTB:
  `0e93b71aacf707a5fbb7a58eff73995b92d766a31a98d8d70e91f548c9e1d5af`
- Beanpod:
  `e066ff6e4f0aaa803e6633aa8fad1f54335e5b969f6422fedc44f77b033851e9`
- `libTEECommon.so`:
  `d700e663bd3f68611cadef9bfc929aeb819e199cc9ef3f61a9c8d0afc2bed5b0`
- KeyMint TA:
  `af4d1dc971c80b539de9e73ee792285944dd9b132d267be3bb0496bd82bb75ab`
- `teei_daemon`:
  `fb79a0c59dab04edbf5ff4cd10af601c4d3dba5378b5ba3d981553f818fbb014`
- `libteei_daemon_vfs.so`:
  `6012c5ccb298a411c8f7c0572b26ca237c3209ad348cd6e509a2cf71f4fccc13`
- Keystore2:
  `31a9f7d9de497e06c465343ddb4d3aa3e8064c3051059c206b53d061d59f6256`
- `libkeystore2_crypto.so`:
  `6e46dbfbf135c41131d64b91ce93fedf7c62077059fdbc24a5ca62b94e195132`

## vendor_boot audit

- header v4; page size 4096
- cmdline: `bootopt=64S3,32N2,64N2`
- fragment 0: exact stock PLATFORM, 27,422,144 bytes
- fragment 1: RECOVERY named `recovery`, 31,678,798 bytes
- total vendor ramdisk: 59,100,942 bytes
- stock DTB exact
- bootconfig empty
- PLATFORM first, RECOVERY second
- all board_id words zero
- recovery fragment `.ko` count: zero
- only five expected module metadata files retained
- algorithm-NONE AVB footer and vendor_boot hash verify
- post-AVB image re-unpacks successfully
- final size exactly 67,108,864 bytes

Static audit: **PASS. Stop before flashing.**
