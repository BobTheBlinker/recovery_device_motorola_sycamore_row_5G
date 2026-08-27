# Sycamore stock-vs-TWRP vendor_boot fragment audit

Date: 2026-08-27

## Inputs

- Factory: `/home/nicholas/Downloads/sycamore-twrp-info/vendor_boot_a.img`
  - SHA-256: `e542af82e8bb153faa96a44ec480548b21ac99abf7ca26ffca0eafcc9b6a9fe`
- Hardware-tested V14: `/home/nicholas/Downloads/sycamore-twrp-info/first-hardware-boot/fbe-a16-v14-wrapped-first/vendor_boot.img`
  - SHA-256: `d657365e5c14ba0bc1e93e9fc0ec38acb18f935e222d1bae66377011b96b9d15`
- Current untested output: `out/target/product/sycamore_row_5G/vendor_boot.img`
  - SHA-256: `eb3388b6da20ce487976e40ff1a30ca8ee488680f01aeaaedb483e0aed555d18`

All images are exactly 67,108,864 bytes.

## Common header and retained sections

The local AOSP `unpack_bootimg.py` reports these identical values for all three:

- magic: `VNDRBOOT`
- header version: 4
- header size: 2,128
- page size: 4,096
- kernel load address: `0x40000000`
- ramdisk load address: `0x66f00000`
- tags load address: `0x47c80000`
- DTB load address: `0x47c80000`
- vendor cmdline: `bootopt=64S3,32N2,64N2`
- product name: empty
- bootconfig: empty (0 bytes; SHA-256 of empty content
  `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`)
- DTB: 192,119 bytes; SHA-256
  `0e93b71aacf707a5fbb7a58eff73995b92d766a31a98d8d70e91f548c9e1d5af`

## Factory fragment table

| Index | Name | Type | Table offset | Image offset | Compressed size | Compression | board_id |
|---:|---|---|---:|---:|---:|---|---|
| 0 | empty | PLATFORM (1) | 0 | 4,096 | 27,422,144 | LZ4 legacy | 16 zero words |

Compressed payload SHA-256:
`06738f638a745075511c571347c5511331dda16b84d1ee88cda160c2dc7ebb14`

Uncompressed CPIO: 67,875,584 bytes; SHA-256
`cdf1d9fd1658989a4c198ca889802660f3a2d52a8fc527e40013c35da917642c`

Factory total vendor ramdisk size is 27,422,144 bytes. Its table is 108 bytes
with one entry. There is no RECOVERY entry and no DLKM entry.

## Hardware-tested V14 fragment table

| Index | Name | Type | Table offset | Image offset | Compressed size | Compression | board_id | Compressed SHA-256 | Uncompressed size | Uncompressed SHA-256 |
|---:|---|---|---:|---:|---:|---|---|---|---:|---|
| 0 | empty | PLATFORM (1) | 0 | 4,096 | 27,422,144 | LZ4 legacy | 16 zero words | `06738f638a745075511c571347c5511331dda16b84d1ee88cda160c2dc7ebb14` | 67,875,584 | `cdf1d9fd1658989a4c198ca889802660f3a2d52a8fc527e40013c35da917642c` |
| 1 | `recovery` | RECOVERY (2) | 27,422,144 | 27,426,240 | 31,391,394 | LZ4 legacy | 16 zero words | `ae0c2ab5adba18a2a5bdaa79760b4d8aa474bd2de9f82ba25a1a343e6d810467` | 69,037,312 | `9c3945cd24333659f8aea5bc78a01bd5d9c4762603ad4a943be4cb62a874d01f` |

Total vendor ramdisk size is 58,813,538 bytes. Its table is 216 bytes with
two entries, ordered PLATFORM then RECOVERY.

## Current output fragment table

| Index | Name | Type | Table offset | Image offset | Compressed size | Compression | board_id | Compressed SHA-256 | Uncompressed size | Uncompressed SHA-256 |
|---:|---|---|---:|---:|---:|---|---|---|---:|---|
| 0 | empty | PLATFORM (1) | 0 | 4,096 | 27,422,144 | LZ4 legacy | 16 zero words | `06738f638a745075511c571347c5511331dda16b84d1ee88cda160c2dc7ebb14` | 67,875,584 | `cdf1d9fd1658989a4c198ca889802660f3a2d52a8fc527e40013c35da917642c` |
| 1 | `recovery` | RECOVERY (2) | 27,422,144 | 27,426,240 | 31,677,990 | LZ4 legacy | 16 zero words | `b4e9de040d9d1c4e78a4fa8ab056a6bb7a42fafff6f99303f08fb43c54aa76ca` | 69,607,424 | `a1401628c4ca65d2fe1ab267e049d40c5e3a0c4d91187ad44d14b46808d2c001` |

Total vendor ramdisk size is 59,100,134 bytes. Its table is 216 bytes with
two entries, ordered PLATFORM then RECOVERY.

## Differential conclusion

- **A. Stock multi-fragment:** NO. It has a valid v4 table but only one entry.
- **B. Stock PLATFORM:** entry 0, unnamed, type 1.
- **C. Stock RECOVERY:** none. Stock recovery content is contained in PLATFORM.
- **D. Stock PLATFORM preserved by TWRP:** YES, byte-for-byte in both V14 and
  current output, for both compressed and uncompressed payloads.
- **E. Stock non-recovery fragment regenerated/replaced:** NO. PLATFORM is the
  only stock fragment and is exact. Stock has no DLKM or other fragment.

The hybrid principle is already implemented by
`tools/assemble_vendor_boot.sh`: the exact stock PLATFORM archive is entry 0 and
the generated TWRP ramdisk is appended as entry 1/RECOVERY. A new “hybrid” build
would not change this variable. PLATFORM preservation is therefore **PROVEN**
and is not a remaining explanation for the V14 cmd `0x18` failure.

The required aggregate/table changes are limited to total ramdisk size, table
size/count, downstream aligned section positions, and the AVB hash/footer.
V14 and current output retain the stock DTB, cmdline, bootconfig, core header
values, fragment-0 metadata, and fragment-0 bytes.

## Dynamic-partition corroboration

Read-only live recovery inspection showed liblp/TWRP preparing logical
partitions from `super` and mapping:

- `odm_dlkm_a` -> `dm-0`
- `product_a` -> `dm-1`
- `system_a` -> `dm-2`
- `system_b` -> `dm-3`
- `system_dlkm_a` -> `dm-4`
- `system_ext_a` -> `dm-5`
- `vendor_a` -> `dm-6`
- `vendor_dlkm_a` -> `dm-7`

The active-slot convenience links resolve `system`, `system_ext`, `product`,
`vendor`, `vendor_dlkm`, `odm_dlkm`, and `system_dlkm` to those mapper nodes.
Any resulting `/dev/block/by-name/<logical>` links are runtime-created links to
`dm-*`, not physical GPT partitions. The existing `recovery.fstab` correctly
uses `logical,first_stage_mount`; no invented physical by-name paths are needed.

No image was built, flashed, booted, or otherwise written to hardware during
this audit.
