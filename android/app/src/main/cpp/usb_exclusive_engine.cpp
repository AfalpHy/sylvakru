#include <jni.h>
#include <android/log.h>
#include <errno.h>
#include <fcntl.h>
#include <linux/usbdevice_fs.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <unistd.h>

#include <algorithm>
#include <mutex>
#include <string>

namespace {

constexpr const char* kTag = "SylvakruUsbExclusive";
constexpr int kMaxIsoPacketsPerUrb = 32;

std::mutex g_mutex;
int g_fd = -1;
int g_interface_number = -1;
int g_endpoint_address = -1;
int g_max_packet_size = 0;

std::string errorMessage(const char* action) {
    return std::string(action) + " failed: " + strerror(errno);
}

jstring toJString(JNIEnv* env, const std::string& value) {
    return env->NewStringUTF(value.c_str());
}

jstring nullableError(JNIEnv* env, const std::string& error) {
    if (error.empty()) {
        return nullptr;
    }
    __android_log_print(ANDROID_LOG_WARN, kTag, "%s", error.c_str());
    return toJString(env, error);
}

void closeLocked() {
    if (g_fd < 0) {
        return;
    }

    if (g_interface_number >= 0) {
        ioctl(g_fd, USBDEVFS_RELEASEINTERFACE, &g_interface_number);
    }
    close(g_fd);
    g_fd = -1;
    g_interface_number = -1;
    g_endpoint_address = -1;
    g_max_packet_size = 0;
}

std::string submitIsoChunkLocked(const uint8_t* data, int length) {
    if (g_fd < 0) {
        return "USB exclusive device is not open.";
    }
    if (g_endpoint_address < 0 || g_max_packet_size <= 0) {
        return "USB exclusive endpoint is not configured.";
    }

    const int packets = std::max(
        1,
        std::min(kMaxIsoPacketsPerUrb, (length + g_max_packet_size - 1) / g_max_packet_size));
    const size_t urb_size =
        sizeof(usbdevfs_urb) + sizeof(usbdevfs_iso_packet_desc) * packets;
    auto* urb = static_cast<usbdevfs_urb*>(calloc(1, urb_size));
    auto* buffer = static_cast<uint8_t*>(malloc(length));
    if (urb == nullptr || buffer == nullptr) {
        free(urb);
        free(buffer);
        return "Failed to allocate USB isochronous transfer.";
    }

    memcpy(buffer, data, length);
    urb->type = USBDEVFS_URB_TYPE_ISO;
    urb->endpoint = static_cast<unsigned char>(g_endpoint_address);
    urb->status = 0;
    urb->flags = USBDEVFS_URB_ISO_ASAP;
    urb->buffer = buffer;
    urb->buffer_length = length;
    urb->number_of_packets = packets;

    int remaining = length;
    for (int i = 0; i < packets; ++i) {
        const int packet_length = std::min(g_max_packet_size, remaining);
        urb->iso_frame_desc[i].length = packet_length;
        remaining -= packet_length;
    }

    if (ioctl(g_fd, USBDEVFS_SUBMITURB, urb) < 0) {
        const auto error = errorMessage("USBDEVFS_SUBMITURB");
        free(buffer);
        free(urb);
        return error;
    }

    void* completed = nullptr;
    if (ioctl(g_fd, USBDEVFS_REAPURB, &completed) < 0) {
        const auto error = errorMessage("USBDEVFS_REAPURB");
        free(buffer);
        free(urb);
        return error;
    }

    std::string error;
    if (urb->status != 0) {
        error = "USB isochronous transfer completed with status " + std::to_string(urb->status) + ".";
    }

    free(buffer);
    free(urb);
    return error;
}

}  // namespace

extern "C" JNIEXPORT jstring JNICALL
Java_com_afalphy_sylvakru_UsbExclusiveNative_open(
    JNIEnv* env,
    jobject,
    jint fd,
    jint interface_number,
    jint alternate_setting,
    jint endpoint_address,
    jint max_packet_size) {
    std::lock_guard<std::mutex> lock(g_mutex);
    closeLocked();

    const int duplicated = dup(fd);
    if (duplicated < 0) {
        return nullableError(env, errorMessage("dup"));
    }

    g_fd = duplicated;
    g_interface_number = interface_number;
    g_endpoint_address = endpoint_address;
    g_max_packet_size = max_packet_size;

    if (ioctl(g_fd, USBDEVFS_CLAIMINTERFACE, &g_interface_number) < 0) {
        const auto error = errorMessage("USBDEVFS_CLAIMINTERFACE");
        closeLocked();
        return nullableError(env, error);
    }

    usbdevfs_setinterface set_interface = {};
    set_interface.interface = interface_number;
    set_interface.altsetting = alternate_setting;
    if (ioctl(g_fd, USBDEVFS_SETINTERFACE, &set_interface) < 0) {
        const auto error = errorMessage("USBDEVFS_SETINTERFACE");
        closeLocked();
        return nullableError(env, error);
    }

    return nullptr;
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_afalphy_sylvakru_UsbExclusiveNative_writePcm(
    JNIEnv* env,
    jobject,
    jbyteArray bytes,
    jint length) {
    if (bytes == nullptr || length <= 0) {
        return nullptr;
    }

    const jsize array_length = env->GetArrayLength(bytes);
    const int safe_length = std::min<int>(length, array_length);
    auto* input = reinterpret_cast<uint8_t*>(env->GetByteArrayElements(bytes, nullptr));
    if (input == nullptr) {
        return nullableError(env, "Failed to access PCM buffer.");
    }

    std::string error;
    int offset = 0;
    {
        std::lock_guard<std::mutex> lock(g_mutex);
        const int max_chunk = std::max(1, g_max_packet_size * kMaxIsoPacketsPerUrb);
        while (offset < safe_length && error.empty()) {
            const int chunk = std::min(max_chunk, safe_length - offset);
            error = submitIsoChunkLocked(input + offset, chunk);
            offset += chunk;
        }
    }

    env->ReleaseByteArrayElements(bytes, reinterpret_cast<jbyte*>(input), JNI_ABORT);
    return nullableError(env, error);
}

extern "C" JNIEXPORT void JNICALL
Java_com_afalphy_sylvakru_UsbExclusiveNative_close(JNIEnv*, jobject) {
    std::lock_guard<std::mutex> lock(g_mutex);
    closeLocked();
}
