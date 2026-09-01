Device configuration for Motorola Moto Pad 2026 (codenamed "sycamore_row_5G")
=========================================

The Motorola Moto Pad 2026 / XT2575-4 (codenamed _"sycamore_row_5G"_) is an Android tablet from Motorola Mobility based on the MediaTek MT8755 platform.

This device tree is intended for building Team Win Recovery Project (TWRP).

## Device specifications

Basic   | Spec Sheet
-------:|:-------------------------
Model   | Motorola XT2575-4
Codename | sycamore_row_5G
SoC     | MediaTek MT8755 (MT6835 platform)
CPU     | 64-bit ARM, Cortex-A76 / Cortex-A55
GPU     | ARM Mali
Shipped Android Version | Android 15
Tested Stock Firmware | Android 16 / ZUI 17.5
Storage | UFS
Display | 2560 x 1600 pixels, 90 Hz
Partition Scheme | A/B, Virtual A/B, Dynamic Partitions
Encryption | File-Based Encryption (FBE v2) with metadata encryption
Filesystem | F2FS userdata, EROFS/EXT4 dynamic partitions
Recovery Layout | TWRP recovery ramdisk stored in `vendor_boot`
Vendor Boot Header | Version 4

## Device picture

![Motorola Moto Pad (2026)](https://fdn2.gsmarena.com/vv/bigpic/motorola-moto-pad-2026-.jpg)

## Device reference

[Motorola Moto Pad (2026) - GSMArena](https://www.gsmarena.com/motorola_moto_pad_(2026)-14582.php)

# Status

Current state of features:

- Correct screen/recovery size
- Working touch and display
- ADB
- Support EROFS/F2FS/EXT4/exFAT/NTFS
- External SD card support
- Dynamic partition support
- A/B slot handling
- `vendor_boot` v4 support
- Stock PLATFORM vendor ramdisk preserved
- TWRP RECOVERY vendor ramdisk fragment
- Decrypt `/data` with user PIN/password
- Decrypted `/data/media`
- Metadata encryption
- KeyMint service
- Gatekeeper service
- Keystore2 service
- MediaTek/Microtrust TEE
- MTP export
- SELinux enforcing
- Vibrate and set vibration

Still to validate before final release:

- Backup/restore to/from internal/external storage and ADB
- ADB sideload
- Poweroff and all reboot targets
- Flashing zip/images from the TWRP UI
- All important partitions listed in wipe/mount/backup lists
- Input devices via USB-OTG
- Correct date/time configuration
- Battery level reporting
- Brightness adjustment
- Screenshot
- Advanced recovery features

# Building

```bash
export ALLOW_MISSING_DEPENDENCIES=true
source build/envsetup.sh
lunch twrp_sycamore_row_5G-eng
mka vendorbootimage -j$(nproc --all)
```

**Copyright (C) 2026 BOBtheBlinker | A-Team Digital Solutions**
