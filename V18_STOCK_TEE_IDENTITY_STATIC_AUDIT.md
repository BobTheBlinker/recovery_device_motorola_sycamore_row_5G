# V18 stock tee identity static audit

Date: 2026-08-27

Result: **PASS — controlled teei_daemon execution-identity experiment; not flashed.**

Artifact SHA-256:
`7c6817d5b29055ac337b26a87e3c29281e8ff2df2209521546c75bb8064642ac`

Artifact size: 67,108,864 bytes.

## Hypothesis

V17 fixed cold THH/model validation but still ran the unchanged stock
`teei_daemon` as root in `u:r:recovery:s0`. V18 tests whether the missing
boot-decrypt-unlock transition and cmd 0x18 key-blob failure depend on the
daemon's production process identity: UID/GID 1000, no supplementary groups,
only `CAP_SYS_RAWIO`, and enforcing `u:r:tee:s0`.

No KeyMint, wrapped-key, FBE, secure-storage, vendor_boot, kernel, or binary
behavior was otherwise changed.

## Service declaration differential

V17:

```rc
user root
group root system
capabilities SYS_RAWIO
seclabel u:r:recovery:s0
```

V18:

```rc
user system
group system
capabilities SYS_RAWIO
seclabel u:r:tee:s0
```

The complete 21-entry `-r`/`-t` UUID argument sequence is byte-for-byte
unchanged. A single `group system` entry establishes the primary GID only; no
supplementary group is declared. `SYS_RAWIO` is the sole capability token.

## SELinux audit and implementation

The pre-V18 platform policy already defined:

- `tee` with the `domain` attribute;
- `tee_exec` as an executable vendor-file type;
- `init_daemon_domain(tee)`, producing
  `type_transition init tee_exec:process tee`.

V17 lacked a `tee_exec` path label for `/vendor/bin/teei_daemon`, so merely
changing `seclabel` could not prove a valid launch environment.

V18 adds the exact executable context and the narrowly scoped stock Microtrust
device contexts under `device/motorola/sycamore_row_5G/sepolicy/vendor`. The
final combined policy:

- compiles successfully;
- passes neverallow checks;
- contains `tee` in the `domain` attribute;
- contains the init→`tee` transition;
- permits `tee` to use only the declared Microtrust node types;
- permits `tee` `sys_rawio` capability use;
- does **not** mark `tee` permissive.

Final policy SHA-256:
`0b23e52b72848a03649e78fe005b88827d35a37bcab2ce8d394fc6d395fd94d3`

## Exact node contexts

These are copied from the exact stock vendor_boot `vendor_file_contexts`:

| Path | Final type |
|---|---|
| `/dev/isee_tee0` | `teei_client_device` |
| `/dev/teei_client` | `teei_client_device` |
| `/dev/teei_config` | `teei_config_device` |
| `/dev/tz_vfs` | `teei_vfs_device` |
| `/dev/teei_fp` | `teei_fp_device` |
| `/dev/ut_keymaster` | `ut_keymaster_device` |
| `/dev/0:0:0:49476` | `teei_rpmb_device` |
| `/dev/rpmb0` | `teei_rpmb_device` |
| `/dev/utr_tui` | `utr_tui_device` |
| `/vendor/bin/teei_daemon` | `tee_exec` |

No non-Microtrust device path was relabeled. These labels are required for the
enforcing `tee` domain to use the same interfaces that V17 accessed from the
permissive recovery domain.

## Removed failed V17 diagnostic

The packaged `syca_v17_thh_ready.sh` and its synchronous init `exec` were
removed. This eliminates the known invalid-domain exec failure and does not add
a replacement delay or process. V16/V17 crypto diagnostics remain intact.

## Frozen V17/V16 state

- all 15 stock THH files: byte-identical to the exact stock extraction;
- `isee_model.json`: unchanged;
- `ro.product.device=XT2575-4`;
- all three vendor product identity fields: `XT2575-4`;
- `ro.build.product=sycamore_row_5G`;
- `ro.crypto.type=file` and `ro.crypto.state=encrypted`;
- healthy-state `vendor.soter.teei.logini=start` ordering;
- `SYCA_V16_PRE_0X18`, `SYCA_SOTER_PRE_0X18`,
  `SYCA_DEKEY_A/B/C/D`, and `SYCA_TA_TRACE`.

## Frozen hashes

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
- Keytrace:
  `0642e36b25589ebdf16423cb3a81c8ba5dab3ffc0dcb32a58386efa8b2d7293d`

## V17-to-V18 final-image differential

Complete unpacked relative-path SHA-256 manifests differ only at:

- `init.recovery.crypto.rc` — intended service identity and failed-diagnostic
  removal;
- `sepolicy`, `vendor_file_contexts`, and `file_contexts.bin` — intended narrow
  tee-domain implementation;
- removal of `system/bin/syca_v17_thh_ready.sh`;
- generated ramdisk inventory files.

No secure binary, THH payload, property file, kernel module, or crypto
diagnostic binary changed.

## Final vendor_boot audit

- header v4; page size 4096
- cmdline `bootopt=64S3,32N2,64N2`; bootconfig empty
- fragment 0: unnamed PLATFORM/type 1, 27,422,144 bytes, exact stock hash
- fragment 1: `recovery`/type 2, 32,078,200 bytes
- total vendor ramdisk: 59,500,344 bytes
- exact stock DTB; all board IDs zero
- PLATFORM first, RECOVERY second
- recovery `.ko` count: zero; same five module metadata files
- algorithm-NONE AVB footer and vendor_boot hash verify
- final image re-unpacks successfully
- final partition-padded size exactly 67,108,864 bytes

Static audit: **PASS. Stop before flashing.**
