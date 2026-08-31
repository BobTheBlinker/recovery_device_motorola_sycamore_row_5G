# V18.1 cold stock tee identity static audit

Date: 2026-08-27

Result: **PASS — surgical init/DAC/tee-permissive experiment; not flashed.**

Immutable baseline:
`fbe-a16-v18-stock-tee-identity`

Baseline SHA-256:
`7c6817d5b29055ac337b26a87e3c29281e8ff2df2209521546c75bb8064642ac`

V18.1 artifact SHA-256:
`5f57030d1cd10d6ef0c3987c8a1b3119f7e51ef23ddc21f647970cf4efb6a26d`

Artifact size: 67,108,864 bytes.

## Task-scoped source changes

- `device/motorola/sycamore_row_5G/recovery/root/init.recovery.crypto.rc`
  - moves exact stock Microtrust DAC and first daemon start to `on fs`;
  - restores the daemon executable context before starting it;
  - gates Beanpod/Gatekeeper on `vendor.soter.teei.init=INIT_OK`;
  - uses stock `post-fs-data` logini lifecycle.
- `device/motorola/sycamore_row_5G/sepolicy/vendor/teei_device.te`
  - adds only `permissive tee;` for this diagnostic build.

No other source file was modified for V18.1.

Task-scoped diff stat:

```text
recovery/root/init.recovery.crypto.rc | 48 +++++++++++++++++++++++++++--------
sepolicy/vendor/teei_device.te        |  4 +++
2 files changed, 41 insertions(+), 11 deletions(-)
```

## A. teei_daemon service

The final unpacked recovery contains the complete V18 `-r`/`-t` UUID sequence
unchanged and exactly:

```rc
user system
group system
disabled
capabilities SYS_RAWIO
seclabel u:r:tee:s0
```

There is one primary `group system` declaration and no supplementary group.
`SYS_RAWIO` is the only capability. The final daemon binary is byte-identical
to V18:

`fb79a0c59dab04edbf5ff4cd10af601c4d3dba5378b5ba3d981553f818fbb014`

## B. executable runtime context

Final `vendor_file_contexts` still contains:

```text
/vendor/bin/teei_daemon u:object_r:tee_exec:s0
```

The final init action executes:

```rc
on fs
    restorecon /vendor/bin/teei_daemon
    ...
    start teei_daemon
```

`restorecon` precedes every Microtrust DAC operation and the first daemon start.

## C. exact stock DAC sequence

The final `on fs` action contains, in the requested order:

```rc
restorecon /vendor/bin/teei_daemon
chmod 0660 /dev/teei_client
chown system system /dev/teei_client
chmod 0660 /dev/teei_config
chown system system /dev/teei_config
chmod 0666 /dev/isee_tee0
chown system drmrpc /dev/isee_tee0
chmod 0660 /dev/tz_vfs
chown system system /dev/tz_vfs
chmod 0660 /dev/teei_fp
chown system /dev/teei_fp
chown system drmrpc /dev/ut_keymaster
chmod 0660 /dev/ut_keymaster
chmod 0660 /dev/0:0:0:49476
chown system system /dev/0:0:0:49476
chmod 0660 /dev/rpmb0
chown system system /dev/rpmb0
chmod 0660 /dev/emmcrpmb0
chown system system /dev/emmcrpmb0
chown system system /dev/utr_tui
chmod 0660 /dev/utr_tui
start teei_daemon
```

No node is manufactured. `/dev/teeperf` remains separately handled in
`on init` at mode 0660.

The persist setup remains byte-for-byte equivalent to V18:

```rc
mkdir /mnt/vendor/persist 0771 system system
mount ext4 /dev/block/sdc14 /mnt/vendor/persist ro noatime nosuid nodev wait noload
```

## D. sequencing

- no `init.svc.teei_daemon=running` action starts security services;
- `vendor.soter.teei.init=INIT_OK` starts Beanpod and Gatekeeper;
- `on post-fs-data` sets `vendor.soter.teei.logini=start`;
- no init property action sets `vendor.soter.teei.persist` or
  `vendor.soter.teei.rpmb.flag`;
- no sleep was introduced.

## E. SELinux

The final compiled-policy permissive-domain set differs from V18 by exactly one
entry: `tee`. Existing recovery-build permissive domains are unchanged.

`tee` is intentionally permissive for V18.1. Global kernel/recovery enforcing
configuration was not changed, no other domain was added, existing node types
and allow rules were preserved, and policy/neverallow compilation passed.

Final policy SHA-256:
`5d9a65cc5a28d3f7ef8ca79f1a40ba4d2548b91a6be0f115085df54b3ae7d055`

## F. frozen crypto comparison against V18

Complete unpacked-file manifests differ only at:

- `init.recovery.crypto.rc`;
- `sepolicy`;
- generated `ramdisk-files.sha256sum` and `ramdisk-files.txt`.

Everything else is byte-identical, including:

| Payload | SHA-256 |
|---|---|
| `teei_daemon` | `fb79a0c59dab04edbf5ff4cd10af601c4d3dba5378b5ba3d981553f818fbb014` |
| Beanpod | `e066ff6e4f0aaa803e6633aa8fad1f54335e5b969f6422fedc44f77b033851e9` |
| Gatekeeper | `7460ce26460376b24c29d2f46820ecc5646505fe24090f57aa7d05141e77d3b9` |
| Keymaster TA | `af4d1dc971c80b539de9e73ee792285944dd9b132d267be3bb0496bd82bb75ab` |
| diagnostic preload | `0642e36b25589ebdf16423cb3a81c8ba5dab3ffc0dcb32a58386efa8b2d7293d` |
| Keystore2 | `31a9f7d9de497e06c465343ddb4d3aa3e8064c3051059c206b53d061d59f6256` |
| `libkeystore2_crypto.so` | `6e46dbfbf135c41131d64b91ce93fedf7c62077059fdbc24a5ca62b94e195132` |
| cmd0x18-bearing recovery binary | `986d25bac8ceb0df6edee2731c5b92c30090f30c84977229022e33c97e9a3a89` |

All eight private KeyMint libraries compare byte-for-byte with V18. The full
15-file THH directory, including `isee_model.json`, compares byte-for-byte with
V18. Product/model/platform and FBE property subsets are identical to V18.

## G. stock hybrid / final image

- header v4; page size 4096
- cmdline `bootopt=64S3,32N2,64N2`; bootconfig empty
- fragment 0: unnamed PLATFORM/type 1, 27,422,144 bytes
- PLATFORM SHA-256:
  `06738f638a745075511c571347c5511331dda16b84d1ee88cda160c2dc7ebb14`
- fragment 1: `recovery`/type 2, 32,078,214 bytes
- total vendor ramdisk: 59,500,358 bytes
- DTB SHA-256:
  `0e93b71aacf707a5fbb7a58eff73995b92d766a31a98d8d70e91f548c9e1d5af`
- recovery `.ko` count: zero; same five module metadata files
- algorithm-NONE AVB footer and vendor_boot hash verify
- image re-unpacks successfully
- final size exactly 67,108,864 bytes

Static audit: **PASS. Stop before flashing.**
