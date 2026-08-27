// Diagnostic-only Beanpod STORAGE_KEY boundary tracer.
// Logs only length and SHA-256, then calls the stock A16 implementation.

#include <atomic>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <cstring>
#include <dlfcn.h>
#include <string>

#include <android/log.h>
#include <openssl/sha.h>

namespace {

constexpr const char* kSetKeyMaterialSymbol =
        "_ZN9keymaster16ExportKeyRequest14SetKeyMaterialEPKvm";
constexpr const char* kGetPropertySymbol =
        "_ZN7android4base11GetPropertyERKNSt3__112basic_stringIcNS1_11char_traitsIcEENS1_9allocatorIcEEEES9_";

// Microtrust uses the GlobalPlatform client ABI, but its headers are not
// shipped in this recovery tree.  These declarations contain only the stable
// ABI prefix needed to inspect the four operation parameters.  The 24-byte
// parameter union and 112-byte operation layout are also verified against the
// exact stock libTEECommon.so used by Beanpod.
struct TEEC_Context;
struct TEEC_Session;

struct TEEC_SharedMemory {
    void* buffer;
    size_t size;
};

struct TEEC_TempMemoryReference {
    void* buffer;
    size_t size;
};

struct TEEC_RegisteredMemoryReference {
    TEEC_SharedMemory* parent;
    size_t size;
    size_t offset;
};

union TEEC_Parameter {
    TEEC_TempMemoryReference tmpref;
    TEEC_RegisteredMemoryReference memref;
    uint8_t abi_size[24];
};

struct TEEC_Operation {
    uint32_t started;
    uint32_t paramTypes;
    TEEC_Parameter params[4];
    void* session;
};

static_assert(sizeof(TEEC_Parameter) == 24);
static_assert(sizeof(TEEC_Operation) == 112);

using TEEC_Result = uint32_t;
using InvokeCommand = TEEC_Result (*)(TEEC_Session*, uint32_t, TEEC_Operation*, uint32_t*);

constexpr uint32_t kTeecSuccess = 0;
constexpr uint32_t kTempInput = 0x5;
constexpr uint32_t kTempOutput = 0x6;
constexpr uint32_t kTempInout = 0x7;
constexpr uint32_t kWhole = 0xc;
constexpr uint32_t kPartialInput = 0xd;
constexpr uint32_t kPartialOutput = 0xe;
constexpr uint32_t kPartialInout = 0xf;

struct ByteRange {
    const uint8_t* data = nullptr;
    size_t size = 0;
    bool found = false;
};

uint32_t ParamType(const TEEC_Operation* operation, size_t index) {
    return (operation->paramTypes >> (index * 4)) & 0xf;
}

ByteRange FindInput(const TEEC_Operation* operation) {
    if (operation == nullptr) return {};
    for (size_t i = 0; i < 4; ++i) {
        const uint32_t type = ParamType(operation, i);
        if (type == kTempInput || type == kTempInout) {
            const auto& ref = operation->params[i].tmpref;
            return {static_cast<const uint8_t*>(ref.buffer), ref.size, true};
        }
        if (type == kWhole || type == kPartialInput || type == kPartialInout) {
            const auto& ref = operation->params[i].memref;
            if (ref.parent == nullptr) return {};
            const size_t offset = type == kWhole ? 0 : ref.offset;
            const size_t size = type == kWhole ? ref.parent->size : ref.size;
            return {static_cast<const uint8_t*>(ref.parent->buffer) + offset, size, true};
        }
    }
    return {};
}

ByteRange FindOutput(const TEEC_Operation* operation) {
    if (operation == nullptr) return {};
    for (size_t i = 0; i < 4; ++i) {
        const uint32_t type = ParamType(operation, i);
        if (type == kTempOutput || type == kTempInout) {
            const auto& ref = operation->params[i].tmpref;
            return {static_cast<const uint8_t*>(ref.buffer), ref.size, true};
        }
        if (type == kWhole || type == kPartialOutput || type == kPartialInout) {
            const auto& ref = operation->params[i].memref;
            if (ref.parent == nullptr) return {};
            const size_t offset = type == kWhole ? 0 : ref.offset;
            const size_t size = type == kWhole ? ref.parent->size : ref.size;
            return {static_cast<const uint8_t*>(ref.parent->buffer) + offset, size, true};
        }
    }
    return {};
}

void DigestHex(const uint8_t* data, size_t size, char (&hex)[SHA256_DIGEST_LENGTH * 2 + 1]) {
    static constexpr uint8_t empty = 0;
    uint8_t digest[SHA256_DIGEST_LENGTH];
    SHA256(size == 0 ? &empty : data, size, digest);
    static constexpr char digits[] = "0123456789abcdef";
    for (size_t i = 0; i < SHA256_DIGEST_LENGTH; ++i) {
        hex[i * 2] = digits[digest[i] >> 4];
        hex[i * 2 + 1] = digits[digest[i] & 0x0f];
    }
    hex[sizeof(hex) - 1] = '\0';
}

bool HasKeymasterError(uint32_t command) {
    switch (command) {
        case 0x04:
        case 0x08:
        case 0x0c:
        case 0x18:
        case 0x48:
        case 0x4c:
        case 0x50:
        case 0x84:
        case 0x340000:
            return true;
        default:
            return false;
    }
}

void LogDigest(const void* data, size_t size) {
    if (size != 64) return;

    static std::atomic_flag logged = ATOMIC_FLAG_INIT;
    if (logged.test_and_set()) return;

    uint8_t digest[SHA256_DIGEST_LENGTH];
    SHA256(static_cast<const uint8_t*>(data), size, digest);
    char hex[SHA256_DIGEST_LENGTH * 2 + 1];
    static constexpr char digits[] = "0123456789abcdef";
    for (size_t i = 0; i < SHA256_DIGEST_LENGTH; ++i) {
        hex[i * 2] = digits[digest[i] >> 4];
        hex[i * 2 + 1] = digits[digest[i] & 0x0f];
    }
    hex[sizeof(hex) - 1] = '\0';
    __android_log_print(ANDROID_LOG_INFO, "SYCA_DEKEY",
                        "SYCA_DEKEY_D len=%zu sha256=%s", size, hex);
}

}  // namespace

// Diagnostic V13: interpose the single GlobalPlatform boundary used by both
// Beanpod request wrappers.  This observes the registered-memory ranges but
// never writes to the operation, shared memory, result, or return-origin.
extern "C" TEEC_Result TEEC_InvokeCommand(TEEC_Session* session, uint32_t command,
                                           TEEC_Operation* operation, uint32_t* return_origin) {
    static const InvokeCommand original =
            reinterpret_cast<InvokeCommand>(dlsym(RTLD_NEXT, "TEEC_InvokeCommand"));
    if (original == nullptr) {
        __android_log_print(ANDROID_LOG_FATAL, "SYCA_TA_TRACE",
                            "stock TEEC_InvokeCommand symbol unavailable");
        __builtin_trap();
    }

    static std::atomic<uint64_t> next_sequence{0};
    const uint64_t sequence = next_sequence.fetch_add(1, std::memory_order_relaxed) + 1;
    const ByteRange input = FindInput(operation);
    const ByteRange output_before = FindOutput(operation);
    const uint8_t* input_data = input.found ? input.data : nullptr;
    const size_t input_size = input.found ? input.size : 0;
    char input_hash[SHA256_DIGEST_LENGTH * 2 + 1];
    DigestHex(input_data, input_size, input_hash);

    __android_log_print(ANDROID_LOG_INFO, "SYCA_TA_TRACE",
                        "SYCA_TA_SEQ=%llu session=0x%llx cmd=0x%x in_len=%zu "
                        "in_sha256=%s out_capacity=%zu",
                        static_cast<unsigned long long>(sequence),
                        static_cast<unsigned long long>(reinterpret_cast<uintptr_t>(session)),
                        command, input_size, input_hash,
                        output_before.found ? output_before.size : 0);

    const TEEC_Result result = original(session, command, operation, return_origin);

    const ByteRange output_after = FindOutput(operation);
    // A failed TEEC transport did not return a serialized TA response.  The
    // memref can still retain its pre-call capacity, which must not be logged
    // or hashed as though it were returned data.
    const bool has_response = result == kTeecSuccess && output_after.found;
    const uint8_t* output_data = has_response ? output_after.data : nullptr;
    const size_t output_size = has_response ? output_after.size : 0;
    char output_hash[SHA256_DIGEST_LENGTH * 2 + 1];
    DigestHex(output_data, output_size, output_hash);
    char origin[16];
    if (return_origin == nullptr) {
        memcpy(origin, "NA", 3);
    } else {
        snprintf(origin, sizeof(origin), "%u", *return_origin);
    }

    if (result == kTeecSuccess && HasKeymasterError(command) && output_size >= sizeof(int32_t)) {
        int32_t keymaster_error;
        memcpy(&keymaster_error, output_data, sizeof(keymaster_error));
        __android_log_print(ANDROID_LOG_INFO, "SYCA_TA_TRACE",
                            "SYCA_TA_RET_SEQ=%llu cmd=0x%x teec_ret=%u origin=%s out_len=%zu "
                            "out_sha256=%s km_error=%d",
                            static_cast<unsigned long long>(sequence), command, result, origin,
                            output_size, output_hash, keymaster_error);
    } else {
        __android_log_print(ANDROID_LOG_INFO, "SYCA_TA_TRACE",
                            "SYCA_TA_RET_SEQ=%llu cmd=0x%x teec_ret=%u origin=%s out_len=%zu "
                            "out_sha256=%s",
                            static_cast<unsigned long long>(sequence), command, result, origin,
                            output_size, output_hash);
    }
    return result;
}

namespace android::base {

// V10-IDENTITY one-variable experiment.  Beanpod obtains these two fields
// through android::base::GetProperty() while constructing BPConfigureRequest
// for command 0x48.  Override only these Beanpod-facing lookups and delegate
// every other property unchanged.
std::string GetProperty(const std::string& key, const std::string& default_value) {
    if (key == "ro.product.name" || key == "ro.product.device") {
        constexpr const char* kStockIdentity = "XT2575-4";
        __android_log_print(ANDROID_LOG_INFO, "SYCA_IDENTITY",
                            "%s=%s", key.c_str(), kStockIdentity);
        return kStockIdentity;
    }

    using Original = std::string (*)(const std::string&, const std::string&);
    static const Original original =
            reinterpret_cast<Original>(dlsym(RTLD_NEXT, kGetPropertySymbol));
    if (original == nullptr) {
        __android_log_print(ANDROID_LOG_FATAL, "SYCA_IDENTITY",
                            "stock GetProperty symbol unavailable");
        __builtin_trap();
    }
    return original(key, default_value);
}

}  // namespace android::base

namespace keymaster {

// V9-OSVERSION one-variable experiment.  Beanpod dynamically imports this
// helper when building BPConfigureRequest for command 0x48.  Keep recovery's
// global Android 12 properties intact and change only the value observed by
// this Beanpod process.
uint32_t GetOsVersion() {
    constexpr uint32_t kAndroid16OsVersion = 160000;
    __android_log_print(ANDROID_LOG_INFO, "SYCA_OSVERSION",
                        "Beanpod ConfigDeviceInfo os_version=%u",
                        kAndroid16OsVersion);
    return kAndroid16OsVersion;
}

class ExportKeyRequest {
  public:
    void SetKeyMaterial(const void* key_material, size_t length);
};

void ExportKeyRequest::SetKeyMaterial(const void* key_material, size_t length) {
    using Original = void (*)(ExportKeyRequest*, const void*, size_t);
    static const Original original = reinterpret_cast<Original>(
            dlsym(RTLD_NEXT, kSetKeyMaterialSymbol));

    LogDigest(key_material, length);
    if (original == nullptr) {
        __android_log_print(ANDROID_LOG_FATAL, "SYCA_DEKEY",
                            "stock SetKeyMaterial symbol unavailable");
        __builtin_trap();
    }
    original(this, key_material, length);
}

}  // namespace keymaster
