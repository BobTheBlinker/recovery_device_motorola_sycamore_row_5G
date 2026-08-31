#include <android-base/logging.h>
#include <errno.h>
#include <linux/un.h>
#include <signal.h>
#include <sys/socket.h>
#include <sys/types.h>
#include <unistd.h>

#include <algorithm>
#include <cstdint>
#include <cstring>
#include <string>
#include <vector>

#include "FsCrypt.h"
#include "SycamoreFscryptIpc.h"

namespace sycamore = android::vold::sycamore;

namespace {

bool ReadFully(int fd, void* data, size_t size) {
    auto* p = static_cast<uint8_t*>(data);
    while (size != 0) {
        ssize_t n = TEMP_FAILURE_RETRY(read(fd, p, size));
        if (n <= 0) return false;
        p += n;
        size -= n;
    }
    return true;
}

bool WriteFully(int fd, const void* data, size_t size) {
    const auto* p = static_cast<const uint8_t*>(data);
    while (size != 0) {
        ssize_t n = TEMP_FAILURE_RETRY(write(fd, p, size));
        if (n <= 0) return false;
        p += n;
        size -= n;
    }
    return true;
}

template <typename T>
bool Consume(const std::vector<uint8_t>& payload, size_t* offset, T* value) {
    if (*offset > payload.size() || sizeof(T) > payload.size() - *offset) return false;
    memcpy(value, payload.data() + *offset, sizeof(T));
    *offset += sizeof(T);
    return true;
}

template <typename T>
void Append(std::vector<uint8_t>* payload, const T& value) {
    const auto* p = reinterpret_cast<const uint8_t*>(&value);
    payload->insert(payload->end(), p, p + sizeof(value));
}

bool IsRecoveryPeer(int fd) {
    ucred cred = {};
    socklen_t cred_len = sizeof(cred);
    if (getsockopt(fd, SOL_SOCKET, SO_PEERCRED, &cred, &cred_len) == -1 || cred.uid != 0) {
        return false;
    }
    char context[128] = {};
    socklen_t context_len = sizeof(context);
    if (getsockopt(fd, SOL_SOCKET, SO_PEERSEC, context, &context_len) == -1) return false;
    return std::string(context, strnlen(context, context_len)) == "u:r:recovery:s0";
}

int32_t Dispatch(sycamore::Command command, std::vector<uint8_t>* request,
                 std::vector<uint8_t>* response) {
    size_t offset = 0;
    switch (command) {
        case sycamore::Command::kPing:
            return request->empty() ? 0 : -EINVAL;
        case sycamore::Command::kInitSystemwide:
            if (!request->empty()) return -EINVAL;
            LOG(INFO) << "sycamore_fscryptd: INIT_SYSTEMWIDE begin";
            if (!fscrypt_initialize_systemwide_keys()) {
                LOG(ERROR) << "sycamore_fscryptd: INIT_SYSTEMWIDE fail";
                return -EIO;
            }
            LOG(INFO) << "sycamore_fscryptd: INIT_SYSTEMWIDE success";
            return 0;
        case sycamore::Command::kInitUser0:
            if (!request->empty()) return -EINVAL;
            LOG(INFO) << "sycamore_fscryptd: INIT_USER0 begin";
            if (!fscrypt_init_user0()) {
                LOG(ERROR) << "sycamore_fscryptd: INIT_USER0 fail";
                return -EIO;
            }
            LOG(INFO) << "sycamore_fscryptd: INIT_USER0 success";
            return 0;
        case sycamore::Command::kUnlockUser: {
            int32_t user_id;
            int32_t serial;
            uint32_t secret_size;
            if (!Consume(*request, &offset, &user_id) || !Consume(*request, &offset, &serial) ||
                !Consume(*request, &offset, &secret_size) || user_id < 0 || user_id > 9999 ||
                secret_size > 1024 || secret_size != request->size() - offset) {
                return -EINVAL;
            }
            std::string secret(reinterpret_cast<const char*>(request->data() + offset), secret_size);
            LOG(INFO) << "sycamore_fscryptd: UNLOCK_USER user=" << user_id << " begin";
            bool ok = fscrypt_unlock_user_key(user_id, serial, secret);
            std::fill(secret.begin(), secret.end(), '\0');
            std::fill(request->begin(), request->end(), 0);
            if (ok) {
                LOG(INFO) << "sycamore_fscryptd: UNLOCK_USER user=" << user_id << " success";
            } else {
                LOG(ERROR) << "sycamore_fscryptd: UNLOCK_USER user=" << user_id << " fail";
            }
            return ok ? 0 : -EIO;
        }
        case sycamore::Command::kPrepareUserStorage: {
            int32_t user_id;
            int32_t serial;
            int32_t flags;
            uint32_t uuid_size;
            if (!Consume(*request, &offset, &user_id) || !Consume(*request, &offset, &serial) ||
                !Consume(*request, &offset, &flags) || !Consume(*request, &offset, &uuid_size) ||
                user_id < 0 || user_id > 9999 || uuid_size > 128 ||
                uuid_size != request->size() - offset || (flags & ~3) != 0 || flags == 0) {
                return -EINVAL;
            }
            std::string uuid(reinterpret_cast<const char*>(request->data() + offset), uuid_size);
            return fscrypt_prepare_user_storage(uuid, user_id, serial, flags) ? 0 : -EIO;
        }
        case sycamore::Command::kClassifyPolicy: {
            uint32_t ref_size;
            if (!Consume(*request, &offset, &ref_size) || ref_size == 0 || ref_size > 64 ||
                ref_size != request->size() - offset) {
                return -EINVAL;
            }
            std::string ref(reinterpret_cast<const char*>(request->data() + offset), ref_size);
            FscryptPolicyKind kind = FscryptPolicyKind::kUnknown;
            userid_t user_id = 0;
            if (!fscrypt_classify_policy_ref(ref, &kind, &user_id)) return -ENOENT;
            int32_t kind_value = static_cast<int32_t>(kind);
            int32_t uid = user_id;
            Append(response, kind_value);
            Append(response, uid);
            return 0;
        }
        case sycamore::Command::kResolvePolicy: {
            int32_t kind_value;
            int32_t user_id;
            if (!Consume(*request, &offset, &kind_value) || !Consume(*request, &offset, &user_id) ||
                offset != request->size() || user_id < 0 || user_id > 9999) {
                return -EINVAL;
            }
            std::string ref;
            if (!fscrypt_resolve_policy_ref(static_cast<FscryptPolicyKind>(kind_value), user_id,
                                            &ref) ||
                ref.empty() || ref.size() > 64) {
                return -ENOENT;
            }
            response->assign(ref.begin(), ref.end());
            return 0;
        }
        default:
            return -ENOTSUP;
    }
}

void HandleClient(int fd) {
    if (!IsRecoveryPeer(fd)) {
        LOG(ERROR) << "sycamore_fscryptd: rejected unauthorized peer";
        return;
    }
    sycamore::RequestHeader header = {};
    if (!ReadFully(fd, &header, sizeof(header)) || header.magic != sycamore::kMagic ||
        header.version != sycamore::kVersion || header.payload_size > sycamore::kMaxPayload) {
        return;
    }
    std::vector<uint8_t> request(header.payload_size);
    if (!request.empty() && !ReadFully(fd, request.data(), request.size())) return;
    std::vector<uint8_t> response;
    int32_t status = Dispatch(static_cast<sycamore::Command>(header.command), &request, &response);
    sycamore::ResponseHeader reply{sycamore::kMagic, sycamore::kVersion, header.command, status,
                                    static_cast<uint32_t>(response.size())};
    WriteFully(fd, &reply, sizeof(reply));
    if (!response.empty()) WriteFully(fd, response.data(), response.size());
    std::fill(request.begin(), request.end(), 0);
}

int CreateServerSocket() {
    int fd = socket(AF_UNIX, SOCK_STREAM | SOCK_CLOEXEC, 0);
    if (fd == -1) return -1;
    sockaddr_un addr = {};
    addr.sun_family = AF_UNIX;
    static_assert(sizeof(sycamore::kSocketName) <= sizeof(addr.sun_path));
    memcpy(addr.sun_path + 1, sycamore::kSocketName, sizeof(sycamore::kSocketName) - 1);
    socklen_t len = offsetof(sockaddr_un, sun_path) + 1 + sizeof(sycamore::kSocketName) - 1;
    if (bind(fd, reinterpret_cast<sockaddr*>(&addr), len) == -1 || listen(fd, 4) == -1) {
        close(fd);
        return -1;
    }
    return fd;
}

}  // namespace

int main() {
    signal(SIGPIPE, SIG_IGN);
    int server = CreateServerSocket();
    if (server == -1) {
        PLOG(ERROR) << "sycamore_fscryptd: unable to create private socket";
        return 1;
    }
    LOG(INFO) << "sycamore_fscryptd: started";
    for (;;) {
        int client = TEMP_FAILURE_RETRY(accept4(server, nullptr, nullptr, SOCK_CLOEXEC));
        if (client == -1) {
            if (errno == EINTR) continue;
            PLOG(ERROR) << "sycamore_fscryptd: accept failed";
            return 1;
        }
        HandleClient(client);
        close(client);
    }
}
