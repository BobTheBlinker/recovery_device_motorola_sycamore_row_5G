# Sycamore Android 16 FBE cmd 0x18 investigation

Date: 2026-08-27

Baseline: hardware-tested V14 wrapped-first vendor_boot, SHA-256
`d657365e5c14ba0bc1e93e9fc0ec38acb18f935e222d1bae66377011b96b9d15`.

Evidence labels in this report are **PROVEN**, **EXPECTED**, **UNKNOWN**, and
**EXCLUDED**.

## A. Recovery state immediately before the first cmd 0x18

The first V14 conversion is at `v14-native-runtime-failure/logcat-all.txt:2942-2957`,
at 19:01:29.957-19:01:29.959. Before that point recovery had already proven:

- `vendor.soter.teei.init=INIT_OK`
- `vendor.soter.teei.km.init=config_patch_level_sucess`
- `vendor.soter.teei.km.version=v2.0.0`
- `vendor.soter.teei.persist=OPEN`
- `vendor.soter.teei.rpmb.flag=ok`
- persist selector 3
- successful c09 TA load, secure-storage manager startup, physical RPMB commands,
  `rpmb key is programmed`, KeyMint configuration, SharedSecret, metadata unwrap,
  systemwide outer unwrap, and one stock-shaped Begin/Update/Finish sequence.

The retained recovery property dump does not contain:

- `vendor.soter.teei.googlekey.status`
- `vendor.soter.teei.logini`

Recovery later logs `logini thread failed` at 19:02:05.108, about 35 seconds after
the first failure. This proves a final recovery-state difference, but does not prove
that logini participates in cmd 0x18.

## B. Healthy-stock Soter comparison

The archived stock snapshot contains:

| Property | Stock snapshot | V14 retained state before/around failure |
|---|---|---|
| `vendor.soter.teei.googlekey.status` | `ok` | absent |
| `vendor.soter.teei.init` | `INIT_OK` | `INIT_OK` |
| `vendor.soter.teei.km.init` | `config_patch_level_sucess` | same |
| `vendor.soter.teei.km.version` | `v2.0.0` | `v2.0.0` |
| `vendor.soter.teei.logini` | `start` | absent; later logini thread failure |
| `vendor.soter.teei.persist` | `OPEN` | `OPEN` |
| `vendor.soter.teei.rpmb.flag` | `ok` | `ok` |

Stock `microtrust.rc:245-246` sets `vendor.soter.teei.logini=start` on the Android
`post-fs-data` trigger. It is an init-set request to `teei_daemon`, not proof by
itself that a secure-world transition completed. The stock property snapshot was
captured after DE storage was available, so it cannot prove that logini preceded
stock's first storage-key conversion. Android init describes `post-fs-data` as the
stage at which `/data` has already been mounted; therefore forcing logini before
conversion would not reproduce a proven stock ordering.

No local rc file was found that directly sets `googlekey.status`. The value is
therefore **EXPECTED** to be service/secure-world-derived, but its exact setter and
pre-conversion timing remain **UNKNOWN**.

Conclusion: `persist=OPEN` and `rpmb.flag=ok` are matched and correspond to observed
real VFS/RPMB activity. `logini` and `googlekey.status` differ in final visibility,
but neither is yet connected to cmd 0x18 timing.

## C. Exact 64-byte storage-key provenance

The source directory is `/data/unencrypted/key`:

1. `keymaster_key_blob` is a 444-byte ordinary KeyMint AES wrapping-key blob,
   SHA-256
   `24449b28dedeecc82b0abfb571ef6aa93151608e841fbbf9dd9bdb907ff89c87`.
2. `secdiscardable` contributes to the application ID computed by
   `KeyStorage.cpp::generateAppId()`.
3. `encrypted_key` is a 92-byte AES-GCM container: 12-byte nonce, 64-byte
   ciphertext/plaintext length, and 16-byte tag. Its SHA-256 is
   `7700695d0e5c1605d9d1c56669cb4130588c1054766ac735488fa76f4fd47312`.
4. `retrieveKey()` reads the files at `system/vold/KeyStorage.cpp:630-652`.
5. `decryptWithKeymasterKey()` authenticates and decrypts the 92-byte container.
6. The resulting 64-byte plaintext is the proprietary `TAG_STORAGE_KEY` blob.
7. `exportWrappedStorageKey()` at `system/vold/KeyStorage.cpp:189-197` copies it
   without transformation into `Keymaster::exportKey()`.
8. `Keymaster::exportKey()` at `system/vold/Keymaster.cpp:167-191` places the same
   bytes in a `Domain::BLOB` descriptor.
9. Keystore2 at `system/security/keystore2/src/security_level.rs:892-962` passes
   the byte vector unchanged to `IKeyMintDevice::convertStorageKeyToEphemeral()`.
10. Beanpod serializes the legacy export request as 12-byte empty AuthorizationSet,
    4-byte RAW KeyFormat, 4-byte blob length, and the 64-byte blob: 84 bytes total.

V14 hash-only checkpoints A, B, C, and D all report 64 bytes with SHA-256
`3c36a06c93c07adeda069dd413b2df8f2e9b54371f3920e5de40ea6f318e8f83`.
The complete 84-byte request SHA-256 is
`7c4f5fdd21de15b396f5b739cbb41f32a3944046902c786ceed9a2b829e56647`.

No raw key, nonce, HMAC, or credential bytes are recorded. This is intentional:
lengths and hashes prove transport identity without exposing live key material.

The 64-byte length is **PROVEN expected for this exact existing Sycamore blob**:
stock decrypts the same key lineage, the authenticated outer container has a
64-byte plaintext, and the TA reports `DeserializeAuthEncryptedBlob ... (64)`.

## D. Recovery code path and cmd 0x18 construction

`fscrypt_initialize_systemwide_keys()` at `system/vold/FsCrypt.cpp:452-495`
retrieves `/data/unencrypted/key`, then `install_storage_key()` at lines 268-279
calls `exportWrappedStorageKey()` when hardware-wrapped mode is selected.

The request contains:

- empty client/application AuthorizationSets;
- `KeyFormat::RAW`;
- the unmodified 64-byte opaque blob;
- no credential, SID, auth token, application ID, or application data.

Beanpod command `0x18` is its legacy Keymaster export-key command encoding. It is
not a distinct 0x18-only userspace serializer invented by TWRP.

## E. Android 16 comparison

Android 16 AOSP `system/vold` retains the same architecture:

- vold passes the opaque storage key as `Domain::BLOB` to Keystore2;
- Keystore2 calls `convertStorageKeyToEphemeral()` directly;
- only `KEY_REQUIRES_UPGRADE` invokes `upgradeKey()` and retries;
- vold intentionally continues storing its original storage blob because its outer
  wrapper already handles version binding.

V14 follows this behavior. Beanpod returns `INVALID_KEY_BLOB`, not
`KEY_REQUIRES_UPGRADE`, so the absent upgrade retry is correct.

Material source drift found in the old tree is creation-side, not conversion-side:

- the local `generateWrappedStorageKey()` requests rollback resistance through its
  generic generator and adds private `KM_TAG_FBE_ICE`;
- newer AOSP avoids rollback resistance for newly generated storage keys.

Neither changes the already-existing 64-byte stock blob or its conversion request.
The exact stock A16 vold binary contains `wrappedkey_v0`,
`fscrypt_initialize_systemwide_keys`, and the same ephemeral-key path. A
syntactically or semantically obsolete recovery request is therefore **EXCLUDED at
the presently visible boundary**.

## F. Public recovery references

- Agate: credible working TWRP + Microtrust/Beanpod + FBE/metadata reference, but
  userdata lacks `wrappedkey_v0`; it does not exercise cmd 0x18.
- Pissarro: useful Beanpod/TEEI startup ordering, but no proven hardware-wrapped
  storage-key decryption.
- Air: closest MT6835 architecture reference, but crypto flags are disabled and the
  tree is explicitly WIP.
- Dew: modern AIDL KeyMint/Keystore2 architecture, but WIP and no verified
  hardware-wrapped-key decryption result.
- TB351FU: valuable modern Lenovo Soter property control; its published recovery
  reports encrypted internal storage inaccessible and its stock fstab does not
  establish hardware-wrapped-key use.

No verified public “unicorn” was found that simultaneously demonstrates MediaTek,
Microtrust/TEEI, Beanpod, `wrappedkey_v0`, and successful recovery decryption.

## G. Microtrust hidden state

The MT6895 public driver names `boot_decryto_lock`, `boot_soter_flag`,
`keymaster_call_flag`, `soter_error_flag`, and `teei_capi_ready`, and enforces
`teei_daemon` identity for VFS calls. These establish that hidden kernel/secure-world
state exists. Sycamore runtime proves VFS, TA load, RPMB, and ordinary KeyMint calls
advance far enough to work.

No local Sycamore kernel source exposes equivalent variables, and no retained trace
connects any one of them to cmd 0x18. They remain architectural context, not a
root-cause result.

The exact Sycamore TA is a 930,857-byte signed/encrypted Microtrust container, not
an ELF image, so normal `readelf`/`objdump` analysis cannot isolate its dispatcher.
Runtime secure-world diagnostics nevertheless identify the decisive path:

`ParseKeyBlob()` -> `DeserializeAuthEncryptedBlob()` -> `AES_decrypt_ctr()` ->
integrity/hash comparison failure -> `-33`.

This is after the 64-byte blob has reached authenticated blob decoding. It strongly
favors a structurally recognized blob whose authentication/derivation context does
not reproduce stock over a malformed 84-byte request.

## H. Ranked remaining causes

1. **Medium-high:** secure-world storage-key authentication/KDF context differs
   between normal boot and recovery. This best matches the TA's integrity comparison
   failure while ordinary blobs and the same session work.
2. **Medium:** a storage-specific secure-world initialization transition occurs in
   stock but not recovery before conversion. `googlekey.status`/logini are observable
   leads, but their timing and causal relationship are unproven.
3. **Medium-low:** the retained 64-byte blob depends on secure-storage lineage/state
   not exercised by ordinary metadata keys. RPMB transport works, but that does not
   prove every SST namespace/derived key is identical.
4. **Low:** userspace serialization or Android-version drift. A16 and recovery paths
   match, and A/B/C/D plus the complete request hash exclude mutation.
5. **Low:** malformed length/version presented by vold. The outer container
   authenticates, 64 bytes is the actual stored object, and TA reaches integrity
   comparison rather than rejecting request structure.

Root-of-Trust/device-lock state remains a possible input to item 1, not a proven
cause. Current-stock success under the same raw unlocked/orange boot properties
prevents asserting a simple property-level ROT mismatch.

## I. Best next controlled experiment

The smallest justified next artifact is diagnostic-only: snapshot the seven Soter
properties inside `Keymaster::exportKey()` immediately before the first
`convertStorageKeyToEphemeral()` call. This proves exact boundary-time recovery
state without setting properties, changing service order, exposing secrets, or
altering the request.

Do **not** set `logini=start` yet. Stock sets it on `post-fs-data`, and available
evidence does not prove that doing so before cmd 0x18 is stock-equivalent or safe.

The stock-side unresolved requirement is a trustworthy early-boot timing capture.
The existing post-DE stock property dump cannot answer it, and invasive stock
instrumentation could invalidate the control.

## J. Exact proposed change

One diagnostic addition in `system/vold/Keymaster.cpp`, immediately before
`securityLevel->convertStorageKeyToEphemeral(...)`:

- read and log only the seven public `vendor.soter.teei.*` property strings;
- keep the existing 64-byte length/SHA-256 checkpoint;
- do not set any property or alter control flow.

No TA, Beanpod, Keystore2, KeyStorage, init, fstab, DTB, PLATFORM fragment, or key
file would change functionally.
