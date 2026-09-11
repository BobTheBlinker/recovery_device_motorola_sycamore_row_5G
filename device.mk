DEVICE_PATH := device/motorola/sycamore_row_5G

PRODUCT_USE_DYNAMIC_PARTITIONS := true
ENABLE_VIRTUAL_AB := true

# This is the exact list exposed by ro.product.ab_ota_partitions on the live build.
AB_OTA_PARTITIONS := \
    init_boot \
    product \
    system \
    system_ext \
    vendor

PRODUCT_SOONG_NAMESPACES += $(DEVICE_PATH)

# fastbootd uses the HIDL fastboot HAL for optional vendor-specific commands.
# This device has no recovery-side OEM implementation, so package AOSP's 1.1
# passthrough stub while keeping the generic fastbootd logical-partition path.
PRODUCT_PACKAGES += \
    android.hardware.fastboot@1.1-impl-mock \
    sycamore_boot_hal_stock_libbase

# Let TWRP publish ro.crypto.state/type when it detects /data FBE.
# Stock teei_daemon begins polling before ro.crypto.type=file appears; Beanpod
# establishes its persistent KeyMint session first, then the daemon observes
# the late FBE transition and signals boot_decrypt_lock.
PRODUCT_SYSTEM_DEFAULT_PROPERTIES += \
    ro.product.device=XT2575-4

ifeq ($(strip $(DUALBOOT)),Y)
SYCA_RECOVERY_FSTAB := $(DEVICE_PATH)/recovery-dualboot.fstab
else
SYCA_RECOVERY_FSTAB := $(DEVICE_PATH)/recovery.fstab
endif

PRODUCT_COPY_FILES += \
    $(SYCA_RECOVERY_FSTAB):$(TARGET_COPY_OUT_RECOVERY)/root/system/etc/recovery.fstab \
    $(DEVICE_PATH)/recovery/root/init.recovery.mt6835.rc:$(TARGET_COPY_OUT_RECOVERY)/root/init.recovery.mt6835.rc \
    $(DEVICE_PATH)/recovery/root/init.recovery.mt8755.rc:$(TARGET_COPY_OUT_RECOVERY)/root/init.recovery.mt8755.rc \
    $(DEVICE_PATH)/recovery/root/init.recovery.crypto.rc:$(TARGET_COPY_OUT_RECOVERY)/root/init.recovery.crypto.rc \
    $(DEVICE_PATH)/recovery/root/system/etc/vintf/manifest.xml:$(TARGET_COPY_OUT_RECOVERY)/root/system/etc/vintf/manifest.xml \
    $(DEVICE_PATH)/recovery/root/system/etc/vintf/manifest/android.hardware.health-service.example.xml:$(TARGET_COPY_OUT_RECOVERY)/root/system/etc/vintf/manifest/android.hardware.health-service.example.xml \
    $(DEVICE_PATH)/recovery/root/vendor/manifest.xml:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/manifest.xml \
    $(DEVICE_PATH)/recovery/root/vendor/thh/ta/0102030405060708090a0b0c0d0e0f10.ta:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/thh/ta/0102030405060708090a0b0c0d0e0f10.ta \
    $(DEVICE_PATH)/recovery/root/vendor/thh/ta/020f0000000000000000000000000000.ta:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/thh/ta/020f0000000000000000000000000000.ta \
    $(DEVICE_PATH)/recovery/root/vendor/thh/ta/06090000000000000000000000000000.ta:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/thh/ta/06090000000000000000000000000000.ta \
    $(DEVICE_PATH)/recovery/root/vendor/thh/ta/08030000000000000000000000000000.ta:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/thh/ta/08030000000000000000000000000000.ta \
    $(DEVICE_PATH)/recovery/root/vendor/thh/ta/08110000000000000000000000000000.ta:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/thh/ta/08110000000000000000000000000000.ta \
    $(DEVICE_PATH)/recovery/root/vendor/thh/ta/40188311faf343488db888ad39496f9a.ta:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/thh/ta/40188311faf343488db888ad39496f9a.ta \
    $(DEVICE_PATH)/recovery/root/vendor/thh/ta/5020170115e016302017012521300000.ta:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/thh/ta/5020170115e016302017012521300000.ta \
    $(DEVICE_PATH)/recovery/root/vendor/thh/ta/5f7a5b3b29b041bca249524a031a00e3.ta:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/thh/ta/5f7a5b3b29b041bca249524a031a00e3.ta \
    $(DEVICE_PATH)/recovery/root/vendor/thh/ta/8888c04fc30c4dd0a319ea29643d4d4c.ta:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/thh/ta/8888c04fc30c4dd0a319ea29643d4d4c.ta \
    $(DEVICE_PATH)/recovery/root/vendor/thh/ta/abcd270ea5c44c58bcd3384a2fa2539e.ta:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/thh/ta/abcd270ea5c44c58bcd3384a2fa2539e.ta \
    $(DEVICE_PATH)/recovery/root/vendor/thh/ta/c09c9c5daa504b78b0e46eda61556c3a.ta:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/thh/ta/c09c9c5daa504b78b0e46eda61556c3a.ta \
    $(DEVICE_PATH)/recovery/root/vendor/thh/ta/c1882f2d885e4e13a8c8e2622461b2fa.ta:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/thh/ta/c1882f2d885e4e13a8c8e2622461b2fa.ta \
    $(DEVICE_PATH)/recovery/root/vendor/thh/ta/d91f322ad5a441d5955110eda3272fc0.ta:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/thh/ta/d91f322ad5a441d5955110eda3272fc0.ta \
    $(DEVICE_PATH)/recovery/root/vendor/thh/ta/e97c270ea5c44c58bcd3384a2fa2539e.ta:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/thh/ta/e97c270ea5c44c58bcd3384a2fa2539e.ta \
    $(DEVICE_PATH)/recovery/root/vendor/thh/ta/isee_model.json:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/thh/ta/isee_model.json \
    $(DEVICE_PATH)/recovery/root/vendor/etc/vintf/manifest/android.hardware.security.keymint-service.beanpod.xml:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/etc/vintf/manifest/android.hardware.security.keymint-service.beanpod.xml \
    $(DEVICE_PATH)/recovery/root/vendor/etc/vintf/manifest/android.hardware.security.secureclock-service.beanpod.xml:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/etc/vintf/manifest/android.hardware.security.secureclock-service.beanpod.xml \
    $(DEVICE_PATH)/recovery/root/vendor/etc/vintf/manifest/android.hardware.security.sharedsecret-service.beanpod.xml:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/etc/vintf/manifest/android.hardware.security.sharedsecret-service.beanpod.xml \
    $(DEVICE_PATH)/recovery/root/vendor/etc/vintf/manifest/android.hardware.gatekeeper@1.0-service.xml:$(TARGET_COPY_OUT_RECOVERY)/root/vendor/etc/vintf/manifest/android.hardware.gatekeeper@1.0-service.xml

ifneq ($(strip $(NODECRYPT)),Y)
PRODUCT_PACKAGES += \
    sycamore_gatekeeper_impl \
    sycamore_gatekeeper_hidl \
    sycamore_gatekeeper_service \
    sycamore_gatekeeper_soft \
    sycamore_gatekeeper_tee \
    sycamore_keymint_ndk_v2 \
    sycamore_keymint_private_utils \
    sycamore_keymaster_messages \
    sycamore_keymaster_portable \
    sycamore_keymint_private \
    sycamore_puresoft_keymaster \
    sycamore_soft_attestation \
    sycamore_cppbor_external \
    sycamore_cppcose_rkp \
    sycamore_keymint_service \
    sycamore_secureclock_ndk_v1 \
    sycamore_sharedsecret_ndk_v1 \
    sycamore_tee_common \
    sycamore_tee_imsg_log \
    sycamore_tee_vfs \
    sycamore_teei_daemon
endif

PRODUCT_VENDOR_PROPERTIES += \
    ro.vendor.mtk_ufs_support=1 \
    ro.vendor.mtk_boot_devices=soc/112b0000.ufshci \
    ro.hardware.gatekeeper=beanpod \
    ro.crypto.volume.filenames_mode=aes-256-cts

# Sycamore BootControl HAL compatibility shim.
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/recovery/root/system/etc/init/zz_sycamore_boot_hal.rc:$(TARGET_COPY_OUT_RECOVERY)/root/system/etc/init/zz_sycamore_boot_hal.rc \
    $(DEVICE_PATH)/recovery/root/system/etc/init/zz_sycamore_servicemanager.rc:$(TARGET_COPY_OUT_RECOVERY)/root/system/etc/init/zz_sycamore_servicemanager.rc

PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/recovery/root/system/etc/init/zz_sycamore_hwservicemanager.rc:$(TARGET_COPY_OUT_RECOVERY)/root/system/etc/init/zz_sycamore_hwservicemanager.rc

# Device-side Keystore2 database staging for Android 16 FBE.
ifneq ($(strip $(NODECRYPT)),Y)
PRODUCT_COPY_FILES += \
    $(DEVICE_PATH)/recovery/root/system/bin/sycamore_keystore2_stage.sh:$(TARGET_COPY_OUT_RECOVERY)/root/system/bin/sycamore_keystore2_stage.sh
endif

# Stock MT8755 generic ADC thermal provider.
# Recovery needs this for charger/flash/wifi/USB/board NTC thermal zones;
# keep it outside /lib/modules so the pristine PLATFORM module tree and
# its stock module metadata remain untouched.
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/recovery/root/thermal-modules/thermal-generic-adc.ko:$(TARGET_COPY_OUT_RECOVERY)/root/thermal-modules/thermal-generic-adc.ko

# Android packed timezone database for recovery Bionic.
# Without this, libc emits __bionic_open_tzdata warnings whenever
# recovery formats local timestamps.
PRODUCT_COPY_FILES += \
    system/timezone/output_data/iana/tzdata:$(TARGET_COPY_OUT_RECOVERY)/root/system/usr/share/zoneinfo/tzdata

# Stock MT8755 / MT6377 TIA NTC thermal provider.
# Restores ap_ntc, ltepa_ntc, nrpa_ntc, and tsx_ntc in recovery.
PRODUCT_COPY_FILES += \
    $(LOCAL_PATH)/recovery/root/thermal-modules/board_temp.ko:$(TARGET_COPY_OUT_RECOVERY)/root/thermal-modules/board_temp.ko
