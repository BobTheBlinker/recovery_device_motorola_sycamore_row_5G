# Sycamore vendor_boot module-list pathname collision

## Architecture

Sycamore uses vendor_boot header v4. The device-specific assembler preserves the
factory Android 16 PLATFORM fragment byte-for-byte as table entry 0, then appends the
generated TWRP ramdisk as entry 1, type RECOVERY, named `recovery`. Both fragments use
legacy LZ4. PLATFORM contains the stock recovery/module infrastructure: all 203 `.ko`
files and `modules.alias`, `modules.dep`, `modules.load`, `modules.load.recovery`, and
`modules.softdep` under `/lib/modules`.

The early device tree copied the five metadata files into TWRP's recovery root as
well. Consequently the RECOVERY archive contained duplicate canonical paths, despite
containing no `.ko` payloads. Because RECOVERY follows PLATFORM, a boot chain that
extracts both archives presents the later copy at those paths.

## Isolation methodology and hardware evidence

Compressed size, expanded size, compression ratio, payload data, entry count, and
general CPIO structure were separately controlled. A deterministic pathname-only
bisection retained neutral file payloads while restoring original V20.5 paths in
archive order.

- `RESTORE-PREFIX-0029`: normal Android boot PASS
- `RESTORE-PREFIX-0030`: normal Android boot FAIL

Those images differ only by restoring entry 30 to
`lib/modules/modules.dep`. Replacing its neutral 25,966-byte payload with the exact
stock dependency database produced `MODULES-DEP-STOCKPAYLOAD-CONTROL`, which PASSed.
This verifies that the canonical RECOVERY path reaches the normal first-stage module
consumer and that a valid payload removes the synthetic control failure.

The real V20.5 PLATFORM and RECOVERY `modules.dep` are identical, so that file was
not the real-image cause. The actual differing metadata was `modules.load`:

- stock normal: 179 entries, 3,020 bytes, SHA-256
  `1e9fe08beeb555147fbb39483f5fb4126046427bfa5432aa049cc4efa30b2f05`
- V20.5 RECOVERY: 199 entries, 3,351 bytes, SHA-256
  `1b61df29e9b0f9aef57fd5d7503779903f24fcf2a962d4f19bed166ae8b85d2b`

The recovery list adds 24 modules and omits four relative to stock normal. Starting
from exact real V20.5 and replacing only the RECOVERY `modules.load` payload with the
stock normal payload produced `REAL-V20.5-STOCK-NORMAL-MODULES-LOAD`; normal Android
boot PASSed.

## Conclusions

**VERIFIED:** the differing RECOVERY `/lib/modules/modules.load` is sufficient to
cause real V20.5 normal-Android boot failure.

**STRONG INFERENCE:** the later RECOVERY pathname shadows PLATFORM before normal
first-stage `libmodprobe` consumes `/lib/modules/modules.load`.

**UNKNOWN:** the exact proprietary LK/vendor-ramdisk fragment selection or extraction
implementation that exposes a type-2 RECOVERY path during normal boot.

## Implementation rationale

The device assembler filters `lib/modules/**` only from the generated RECOVERY
archive. It does not modify the checked-out recovery staging tree, kernel modules,
generic TWRP/AOSP code, or the pristine PLATFORM fragment. PLATFORM remains the
single authoritative provider for both normal and recovery module metadata and all
203 module payloads.

Hardcoding a second stock-normal `modules.load` in RECOVERY would repair the observed
collision but preserve unnecessary duplicate metadata and invite future drift.
Removing the duplicate RECOVERY tree instead preserves the factory pairing of module
payloads and metadata, including `modules.load.recovery` for recovery first stage.

The canonical AOSP `m vendorbootimage` path does not invoke the standalone
`tools/assemble_vendor_boot.sh`. `BoardConfig.mk` therefore sets
`BOARD_RECOVERY_IMAGE_PREPARE` to remove the staged RECOVERY `lib/modules` directory
after device-root population and before `mkbootfs`. The standalone assembler applies
the same filter to its temporary archive root. Source prebuilts remain available for
forensics, while both assembly paths emit the same no-duplicate architecture.

## Recovery runtime confirmation

The hardware-validated `V20.5-NO-RECOVERY-LIB-MODULES` image booted TWRP. In that
running recovery, all five `/lib/modules` metadata hashes exactly matched pristine
PLATFORM:

```text
modules.alias          47aa8d900c4bfe1a94f3fee6f405b5d674e33b806ac0fdbf02d17dc283f4ef55
modules.dep            190915e985dc55ac4177914f17f5691eb486f0ae4891eca92b9cc8ee5f004fc4
modules.load           1e9fe08beeb555147fbb39483f5fb4126046427bfa5432aa049cc4efa30b2f05
modules.load.recovery  f7a08319941624be65fcd12e7682b244dcdc7df079a7bf448415768e2641949e
modules.softdep        68b8d79bf7bdf36216f722f07ebc265fed0741025b376e3899b568dd31ecf641
```

**VERIFIED:** with RECOVERY `lib/modules/**` absent, recovery receives the pristine
PLATFORM metadata; PLATFORM `modules.load.recovery` is visible in running TWRP; and
the PLATFORM module tree successfully serves both normal Android and recovery.

## Canonical build integration

The canonical `m vendorbootimage -j8` path was traced through
`build/make/core/Makefile`: device recovery files are copied into
`TARGET_RECOVERY_ROOT_OUT`, `BOARD_RECOVERY_IMAGE_PREPARE` runs, then `mkbootfs` and
legacy LZ4 create the RECOVERY fragment. The standard vendor_boot rule combines it
with `BOARD_PREBUILT_VENDOR_RAMDISK` and the DTB before adding AVB.

The successful canonical build emitted no RECOVERY `lib/modules/**` paths and retained
the exact PLATFORM and DTB hashes. Its artifact SHA-256 is
`7aa012d093e53922cd97100d083f0ae5fc34ecbcbe5bdef4f84c67d11843d7d0`.

## Final canonical hardware validation — CLOSED

The canonical artifact booted both targets successfully:

- normal Android: PASS; `sys.boot_completed=1`
- TWRP: PASS; ADB recovery, GUI/touch and storage functional
- effective `modules.load.recovery`: 197 lines
- `/proc/modules`: populated
- no `Failed to load kernel modules`
- no `Module .* not in dependency file`

Runtime hashes of all five effective metadata files again exactly matched pristine
PLATFORM.

Final classification:

- **VERIFIED:** duplicate RECOVERY module metadata affected normal first-stage boot;
  the differing RECOVERY `modules.load` was sufficient to cause V20.5's failure;
  removing RECOVERY `lib/modules/**` restores normal boot; the canonical
  `m vendorbootimage` integration works on hardware; recovery receives pristine
  PLATFORM metadata and loads modules successfully; both Android and TWRP boot.
- **STRONG INFERENCE:** proprietary boot handling overlays or shadows later RECOVERY
  paths over PLATFORM before first-stage `libmodprobe` consumes them.
- **UNKNOWN:** the exact proprietary LK implementation.

**Investigation status: CLOSED.** Do not alter this implementation without new
contradictory evidence.

Persistent detailed evidence:

- `/home/nicholas/Downloads/sycamore-twrp-info/MODULES_DEP_NORMAL_BOOT_ANALYSIS.md`
- `/home/nicholas/Downloads/sycamore-twrp-info/MODULES_LOAD_NORMAL_BOOT_ANALYSIS.md`
- `/home/nicholas/Downloads/sycamore-twrp-info/normal-boot-name-controls/`
