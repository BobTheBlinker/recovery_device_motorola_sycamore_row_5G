LOCAL_PATH := $(call my-dir)

ifeq ($(TARGET_DEVICE),sycamore_row_5G)

define sycamore-recovery-binary
include $$(CLEAR_VARS)
LOCAL_MODULE := $(1)
LOCAL_MODULE_STEM := $(2)
LOCAL_MODULE_CLASS := EXECUTABLES
LOCAL_MODULE_PATH := $$(TARGET_RECOVERY_ROOT_OUT)/$(3)
LOCAL_SRC_FILES := recovery/root/$(3)/$(2)
LOCAL_MODULE_TAGS := optional
LOCAL_CHECK_ELF_FILES := false
LOCAL_STRIP_MODULE := false
include $$(BUILD_PREBUILT)
endef

define sycamore-recovery-library
include $$(CLEAR_VARS)
LOCAL_MODULE := $(1)
LOCAL_MODULE_STEM := $(2)
LOCAL_MODULE_CLASS := SHARED_LIBRARIES
LOCAL_MODULE_PATH := $$(TARGET_RECOVERY_ROOT_OUT)/$(3)
LOCAL_SRC_FILES := recovery/root/$(3)/$(2)
LOCAL_MODULE_TAGS := optional
LOCAL_CHECK_ELF_FILES := false
LOCAL_STRIP_MODULE := false
include $$(BUILD_PREBUILT)
endef

$(eval $(call sycamore-recovery-binary,sycamore_teei_daemon,teei_daemon,vendor/bin))
$(eval $(call sycamore-recovery-binary,sycamore_keymint_service,android.hardware.security.keymint@2.0-service.beanpod,vendor/bin/hw))
$(eval $(call sycamore-recovery-binary,sycamore_gatekeeper_service,android.hardware.gatekeeper@1.0-service,vendor/bin/hw))

$(eval $(call sycamore-recovery-library,sycamore_keymint_ndk_v2,android.hardware.security.keymint-V2-ndk.so,vendor/lib64))
$(eval $(call sycamore-recovery-library,sycamore_secureclock_ndk_v1,android.hardware.security.secureclock-V1-ndk.so,vendor/lib64))
$(eval $(call sycamore-recovery-library,sycamore_sharedsecret_ndk_v1,android.hardware.security.sharedsecret-V1-ndk.so,vendor/lib64))
$(eval $(call sycamore-recovery-library,sycamore_tee_common,libTEECommon.so,vendor/lib64))
$(eval $(call sycamore-recovery-library,sycamore_tee_imsg_log,libimsg_log.so,vendor/lib64))
$(eval $(call sycamore-recovery-library,sycamore_tee_vfs,libteei_daemon_vfs.so,vendor/lib64))
$(eval $(call sycamore-recovery-library,sycamore_gatekeeper_impl,android.hardware.gatekeeper@1.0-impl.so,vendor/lib64/hw))
$(eval $(call sycamore-recovery-library,sycamore_gatekeeper_tee,gatekeeper.beanpod.so,vendor/lib64/hw))
$(eval $(call sycamore-recovery-library,sycamore_gatekeeper_soft,libSoftGatekeeper.so,vendor/lib64/hw))
$(eval $(call sycamore-recovery-library,sycamore_gatekeeper_hidl,android.hardware.gatekeeper@1.0.so,vendor/lib64))

# Keep the stock Android 16 private KeyMint C++ ABI family coherent. These are
# selected only by the KeyMint/Gatekeeper service-specific LD_LIBRARY_PATH.
$(eval $(call sycamore-recovery-library,sycamore_keymint_private_utils,lib_android_keymaster_keymint_utils.so,vendor/lib64))
$(eval $(call sycamore-recovery-library,sycamore_keymaster_messages,libkeymaster_messages.so,vendor/lib64))
$(eval $(call sycamore-recovery-library,sycamore_keymaster_portable,libkeymaster_portable.so,vendor/lib64))
$(eval $(call sycamore-recovery-library,sycamore_keymint_private,libkeymint.so,vendor/lib64))
$(eval $(call sycamore-recovery-library,sycamore_puresoft_keymaster,libpuresoftkeymasterdevice.so,vendor/lib64))
$(eval $(call sycamore-recovery-library,sycamore_soft_attestation,libsoft_attestation_cert.so,vendor/lib64))
$(eval $(call sycamore-recovery-library,sycamore_cppbor_external,libcppbor_external.so,vendor/lib64))
$(eval $(call sycamore-recovery-library,sycamore_cppcose_rkp,libcppcose_rkp.so,vendor/lib64))

endif

# ============================================================================
# Sycamore final vendor_boot assembly
#
# Build TWRP normally, then replace the final vendor_boot.img with Sycamore's
# required vendor_boot v4 layout:
#   unnamed stock PLATFORM ramdisk
#   generated TWRP RECOVERY fragment
# ============================================================================

ifeq ($(TARGET_DEVICE),sycamore_row_5G)

SYCA_DEVICE_PATH := device/motorola/sycamore_row_5G
SYCA_VENDOR_BOOT_ASSEMBLER := $(SYCA_DEVICE_PATH)/tools/assemble_vendor_boot.sh
SYCA_FINAL_VENDOR_BOOT := $(PRODUCT_OUT)/vendor_boot.img

.PHONY: sycamore-final-vendorboot

sycamore-final-vendorboot: $(SYCA_FINAL_VENDOR_BOOT) $(SYCA_VENDOR_BOOT_ASSEMBLER)
	@echo "============================================================"
	@echo " SYCAMORE FINAL VENDOR_BOOT ASSEMBLY"
	@echo "============================================================"
	$(hide) bash $(SYCA_VENDOR_BOOT_ASSEMBLER) \
		$(PRODUCT_OUT) \
		$(SYCA_DEVICE_PATH) \
		$(HOST_OUT_EXECUTABLES)/mkbootimg \
		$(HOST_OUT_EXECUTABLES)/avbtool
	$(hide) test -f $(SYCA_FINAL_VENDOR_BOOT)
	$(hide) test "$$(stat -c %s $(SYCA_FINAL_VENDOR_BOOT))" -eq 67108864
	@echo "Final vendor_boot:"
	@sha256sum $(SYCA_FINAL_VENDOR_BOOT)

vendorbootimage: sycamore-final-vendorboot

endif
