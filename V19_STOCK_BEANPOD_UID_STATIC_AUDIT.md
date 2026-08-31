# V19 stock Beanpod UID static audit

Date: 2026-08-27

Result: **PASS — one-line Beanpod Unix-identity experiment; not flashed.**

Immutable baseline:
`fbe-a16-v18.1-cold-stock-tee-identity`

Baseline SHA-256:
`5f57030d1cd10d6ef0c3987c8a1b3119f7e51ef23ddc21f647970cf4efb6a26d`

V19 artifact SHA-256:
`549e214d0e58888e6d9b449fd9dafb3fa2912d76295bef18a1409e1ca60b761a`

Artifact size: 67,108,864 bytes.

## Hypothesis and exact change

V19 tests whether Microtrust KeyMint storage-key cmd 0x18 depends on Beanpod's
stock Linux UID 9999. It intentionally retains the V18.1 recovery SELinux
domain so the Unix identity is the only runtime variable.

The sole task source change is:

`device/motorola/sycamore_row_5G/recovery/root/init.recovery.crypto.rc`

```diff
-    user root
+    user nobody
```

Task-scoped V18.1-to-V19 diff stat:

```text
init.recovery.crypto.rc | 2 +-
1 file changed, 1 insertion(+), 1 deletion(-)
```

## 1–3. Final Beanpod service

The final unpacked ramdisk contains:

```rc
service vendor.keymint-beanpod /vendor/bin/hw/android.hardware.security.keymint@2.0-service.beanpod
    class early_hal
    user nobody
    group root
    disabled
    seclabel u:r:recovery:s0
    setenv LD_LIBRARY_PATH /vendor/lib64:/vendor/lib64/hw:/system/lib64:/system/lib64/hw
    setenv LD_PRELOAD /vendor/lib64/libsycamore_keytrace.so
```

There is no capability declaration and no supplementary group. Expected Linux
credentials are UID 9999, primary GID 0, empty supplementary groups, and zero
inheritable/permitted/effective/ambient capabilities.

## 4–7. Frozen secure payloads

Every listed final file compares byte-for-byte with the unpacked archived
V18.1 baseline:

| Payload | SHA-256 |
|---|---|
| Beanpod | `e066ff6e4f0aaa803e6633aa8fad1f54335e5b969f6422fedc44f77b033851e9` |
| `teei_daemon` | `fb79a0c59dab04edbf5ff4cd10af601c4d3dba5378b5ba3d981553f818fbb014` |
| Gatekeeper | `7460ce26460376b24c29d2f46820ecc5646505fe24090f57aa7d05141e77d3b9` |
| Keymaster TA | `af4d1dc971c80b539de9e73ee792285944dd9b132d267be3bb0496bd82bb75ab` |
| diagnostic preload | `0642e36b25589ebdf16423cb3a81c8ba5dab3ffc0dcb32a58386efa8b2d7293d` |
| Keystore2 | `31a9f7d9de497e06c465343ddb4d3aa3e8064c3051059c206b53d061d59f6256` |
| `libkeystore2_crypto.so` | `6e46dbfbf135c41131d64b91ce93fedf7c62077059fdbc24a5ca62b94e195132` |
| cmd0x18-bearing recovery binary | `986d25bac8ceb0df6edee2731c5b92c30090f30c84977229022e33c97e9a3a89` |

All eight private KeyMint libraries are byte-identical. The complete 15-file
THH directory, including `isee_model.json`, is byte-identical.

## 8–11. Frozen ordering/configuration/diagnostics

Replacing the V18.1 `user root` line with `user nobody` produces a file
byte-identical to V19 `init.recovery.crypto.rc`; therefore every other byte of
the service definitions, UUID arguments, cold `on fs` DAC sequence, INIT_OK
gate, post-fs-data logini action, persist mount, and RPMB handling is unchanged.

Final `prop.default`, compiled SELinux policy, and `vendor_file_contexts` are
byte-identical to V18.1. This preserves:

- V18.1 tee-domain policy and permissive state;
- all product/model/platform and FBE properties;
- all Microtrust file contexts;
- `SYCA_V16_PRE_0X18`, `SYCA_SOTER_PRE_0X18`,
  `SYCA_DEKEY_A/B/C/D`, and `SYCA_TA_TRACE` instrumentation.

## 12–16. Final vendor_boot audit

- header v4; page size 4096
- cmdline `bootopt=64S3,32N2,64N2`; bootconfig empty
- fragment 0: unnamed PLATFORM/type 1, 27,422,144 bytes
- PLATFORM SHA-256:
  `06738f638a745075511c571347c5511331dda16b84d1ee88cda160c2dc7ebb14`
- fragment 1: `recovery`/type 2, 32,078,223 bytes
- total vendor ramdisk: 59,500,367 bytes
- DTB SHA-256:
  `0e93b71aacf707a5fbb7a58eff73995b92d766a31a98d8d70e91f548c9e1d5af`
- no kernel payload was changed; recovery `.ko` count is zero and the five
  module metadata filenames match V18.1
- algorithm-NONE AVB footer and vendor_boot hash verify
- final image re-unpacks successfully
- final partition-padded size exactly 67,108,864 bytes

Complete final ramdisk manifests differ from V18.1 only at
`init.recovery.crypto.rc` and the two generated ramdisk inventory files.

Static audit: **PASS. Stop before flashing.**
