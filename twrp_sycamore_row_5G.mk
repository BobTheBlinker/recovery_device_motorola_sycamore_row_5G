$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/aosp_base.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/virtual_ab_ota.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/emulated_storage.mk)
$(call inherit-product, vendor/twrp/config/common.mk)
$(call inherit-product, device/motorola/sycamore_row_5G/device.mk)

PRODUCT_DEVICE := sycamore_row_5G
PRODUCT_NAME := twrp_sycamore_row_5G
PRODUCT_BRAND := Motorola
PRODUCT_MODEL := XT2575-4
PRODUCT_MANUFACTURER := MOTOROLA
PRODUCT_RELEASE_NAME := moto_pad_2026
