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

- [x] Correct screen/recovery size
- [x] Working display
- [x] Working touch
- [x] Screen brightness control
- [x] Power off
- [x] Reboot to system
- [x] Reboot to bootloader
- [x] Reboot to recovery
- [x] Fastboot / fastbootd
- [x] ADB
- [x] Internal storage detected
- [x] External SD card detected
- [x] exFAT external storage
- [x] F2FS userdata support
- [x] EXT4 support
- [x] EROFS support
- [x] Dynamic partition support
- [x] A/B slot handling
- [x] `vendor_boot` v4 support
- [x] Stock PLATFORM vendor ramdisk preserved
- [x] TWRP RECOVERY vendor ramdisk fragment
- [x] Metadata encryption successfully decrypted
- [x] `/data` block device successfully decrypted and mounted
- [x] KeyMint service
- [x] Gatekeeper service
- [x] Keystore2 service
- [ ] Full FBE decryption
- [ ] User PIN/password decryption
- [ ] Decrypted `/data/media`
- [ ] MTP
- [ ] Vibration / haptics
- [ ] USB mass storage export
- [ ] TWRP native `vendor_boot` installation from pristine stock image
- [ ] All commonly modified partitions exposed for image flashing

## Encryption status

Metadata encryption is working and TWRP successfully creates and mounts the decrypted userdata block device.

Current testing reaches the Android hardware-wrapped storage key path but fails during system-wide fscrypt key initialization.

The current failure occurs in the MediaTek Beanpod KeyMint trusted application while processing storage-key conversion:

```text
cmd 0x18 / cmd 24
km_error = -33

AES_decrypt_ctr:
decrypt keyblob compare hash failed

DeserializeAuthEncryptedBlob:
decrypt keyblob failed (-33)

**Copyright (C) 2023 A-Team Digital Solutions**
