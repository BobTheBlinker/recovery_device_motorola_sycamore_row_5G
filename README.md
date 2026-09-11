# TWRP for Motorola Moto Pad 2026

Device tree for building Team Win Recovery Project for the Motorola Moto Pad 2026 / XT2575-4, codenamed `sycamore_row_5G`.

The device uses the MediaTek MT8755 SoC on the MT6835 Android platform and stores recovery in a version 4 `vendor_boot` image.

## Device specifications

| Component | Specification |
|---|---|
| Model | Motorola XT2575-4 |
| Codename | `sycamore_row_5G` |
| SoC | MediaTek MT8755 |
| Android platform | MT6835 |
| Architecture | ARM64 |
| CPU | Cortex-A76 / Cortex-A55 |
| GPU | ARM Mali |
| Shipping Android version | Android 15 |
| Tested firmware | Android 16 / ZUI 17.5 |
| Storage | UFS |
| Display | 2560 x 1600, 90 Hz |
| Partition scheme | A/B, Virtual A/B, dynamic partitions |
| Userdata | F2FS |
| Dynamic partitions | EROFS / EXT4 |
| Encryption | FBE v2 with metadata encryption |
| Recovery location | `vendor_boot` |
| Vendor boot header | Version 4 |

## Working

- Display and touch
- ADB
- Dynamic partitions
- A/B slot handling
- Fastbootd
- EROFS, F2FS and EXT4
- exFAT and NTFS removable-storage support
- External SD card
- Stock PLATFORM vendor ramdisk preservation
- TWRP RECOVERY vendor ramdisk fragment
- Android 16 FBE v2 decryption
- Metadata encryption
- PIN/password protected userdata decryption
- Decrypted `/data/media`
- MediaTek / Microtrust TEE
- KeyMint
- Gatekeeper
- Keystore2
- SELinux enforcing
- MTP
- Vibration
- Thermal sensor support

## Validation remaining

A final hardware-validation pass should cover:

- ADB sideload
- ZIP flashing

## Building

Place this tree at:

```text
device/motorola/sycamore_row_5G
```

Build with:

```bash
source build/envsetup.sh
lunch twrp_sycamore_row_5G-eng
m vendorbootimage -j$(nproc)
```

Output:

```text
out/target/product/sycamore_row_5G/vendor_boot.img
```

## Dual-boot variant

The normal build uses the standard `metadata` and `userdata` partitions.

The optional A-Team dual-boot configuration keeps the canonical `metadata` and `userdata` block names, but enables `slotselect` for `/metadata` and `/data` and uses the matching dual-boot PLATFORM vendor ramdisk:

```bash
export DUALBOOT=Y
source build/envsetup.sh
lunch twrp_sycamore_row_5G-eng
m vendorbootimage -j$(nproc)
```

Only use the dual-boot image on a device configured for the corresponding slotted dual-boot layout.

## NODECRYPT development variant

A recovery build without the device-specific crypto stack can be produced with:

```bash
export NODECRYPT=Y
source build/envsetup.sh
lunch twrp_sycamore_row_5G-eng
m vendorbootimage -j$(nproc)
```

`NODECRYPT=Y` is intended for bring-up and troubleshooting. It omits the KeyMint, Gatekeeper, Keystore2 and Microtrust components required for normal userdata decryption.

When switching between normal, `DUALBOOT=Y`, and `NODECRYPT=Y` configurations, clean the product output first to prevent artifacts from another configuration being reused.

## Implementation notes

Recovery is stored in `vendor_boot` using the Android vendor boot header version 4 layout.

The stock PLATFORM vendor ramdisk is preserved rather than reconstructed. TWRP is supplied as the RECOVERY vendor ramdisk fragment.

This preserves the production MediaTek module layout and early-boot environment while allowing TWRP to provide the recovery userspace.

The tree also contains the device-specific components required for Android 16 FBE decryption through the MediaTek / Microtrust trusted execution environment.

## Device reference

[Motorola Moto Pad (2026) - GSMArena](https://www.gsmarena.com/motorola_moto_pad_(2026)-14582.php)

## Credits

- Team Win Recovery Project
- Motorola / Lenovo
- MediaTek
- A-Team Digital Solutions
- BOBtheBlinker & PizzaG

Copyright (C) 2026 A-Team Digital Solutions
