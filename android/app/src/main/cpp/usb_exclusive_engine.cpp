#include <jni.h>
#include <android/log.h>
#include <errno.h>
#include <fcntl.h>
#include <linux/usbdevice_fs.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <time.h>
#include <unistd.h>

#include <algorithm>
#include <mutex>
#include <string>
#include <vector>

namespace {

constexpr const char* kTag = "SylvakruUsbExclusive";
constexpr int kMaxIsoPacketsPerUrb = 16;
constexpr int kMaxPendingUrbs = 8;

struct PendingUrb {
    usbdevfs_urb* urb;
    uint8_t* buffer;
    int length;
    int packets;
    bool feedback;
};

std::mutex g_mutex;
int g_fd = -1;
int g_interface_number = -1;
int g_endpoint_address = -1;
int g_max_packet_size = 0;
int g_iso_packet_size = 0;
int g_feedback_endpoint_address = 0;
int g_feedback_packet_size = 0;
int g_feedback_frames_per_packet_q16 = 0;
int g_feedback_log_count = 0;
int g_write_log_count = 0;
long long g_total_bytes = 0;
long long g_total_urbs = 0;
long long g_total_iso_packets = 0;
long long g_last_stats_ms = 0;
std::vector<PendingUrb> g_pending_urbs;

long long monotonicMillis() {
    timespec now = {};
    clock_gettime(CLOCK_MONOTONIC, &now);
    return static_cast<long long>(now.tv_sec) * 1000LL + now.tv_nsec / 1000000LL;
}

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

void freePendingUrb(PendingUrb pending) {
    free(pending.buffer);
    free(pending.urb);
}

std::string submitFeedbackLocked();

void logCompletedUrb(PendingUrb pending) {
    if (pending.feedback) {
        return;
    }
    if (pending.urb->status != 0) {
        __android_log_print(
            ANDROID_LOG_WARN,
            kTag,
            "URB completed with status=%d length=%d packets=%d",
            pending.urb->status,
            pending.length,
            pending.packets);
    }
    for (int i = 0; i < pending.packets; ++i) {
        if (pending.urb->iso_frame_desc[i].status != 0) {
            __android_log_print(
                ANDROID_LOG_WARN,
                kTag,
                "iso frame status=%d actual=%u requested=%u index=%d/%d",
                pending.urb->iso_frame_desc[i].status,
                pending.urb->iso_frame_desc[i].actual_length,
                pending.urb->iso_frame_desc[i].length,
                i,
                pending.packets);
        }
    }
}

void handleFeedbackUrb(PendingUrb pending) {
    if (pending.urb->status != 0 || pending.packets <= 0) {
        if (pending.urb->status != 0) {
            __android_log_print(
                ANDROID_LOG_WARN,
                kTag,
                "feedback URB status=%d length=%d packets=%d",
                pending.urb->status,
                pending.length,
                pending.packets);
        }
        return;
    }

    const auto& frame = pending.urb->iso_frame_desc[0];
    if (frame.status != 0 || frame.actual_length < 3) {
        if (frame.status != 0 && g_feedback_log_count < 8) {
            __android_log_print(
                ANDROID_LOG_WARN,
                kTag,
                "feedback frame status=%d actual=%u requested=%u",
                frame.status,
                frame.actual_length,
                frame.length);
        }
        return;
    }

    const int actual = std::min<int>(frame.actual_length, pending.length);
    int raw = 0;
    for (int i = 0; i < std::min(actual, 4); ++i) {
        raw |= static_cast<int>(pending.buffer[i]) << (i * 8);
    }

    int q16 = 0;
    if (actual >= 4) {
        q16 = raw;
    } else {
        q16 = raw << 2;
    }

    if (q16 > 0) {
        g_feedback_frames_per_packet_q16 = q16;
    }
    if (g_feedback_log_count < 12) {
        ++g_feedback_log_count;
        __android_log_print(
            ANDROID_LOG_INFO,
            kTag,
            "USB feedback actual=%d raw=0x%x framesPerPacketQ16=%d approxFrames=%.6f",
            actual,
            raw,
            q16,
            static_cast<double>(q16) / 65536.0);
    }
}

std::string reapOneLocked(bool blocking) {
    if (g_pending_urbs.empty()) {
        return {};
    }

    void* completed = nullptr;
    const int request = blocking ? USBDEVFS_REAPURB : USBDEVFS_REAPURBNDELAY;
    if (ioctl(g_fd, request, &completed) < 0) {
        if (!blocking && errno == EAGAIN) {
            return {};
        }
        return errorMessage(blocking ? "USBDEVFS_REAPURB" : "USBDEVFS_REAPURBNDELAY");
    }
    auto found = std::find_if(
        g_pending_urbs.begin(),
        g_pending_urbs.end(),
        [completed](const PendingUrb& pending) { return pending.urb == completed; });
    if (found == g_pending_urbs.end()) {
        return "USBDEVFS_REAPURB returned an unknown URB.";
    }

    const PendingUrb completed_pending = *found;
    if (completed_pending.feedback) {
        handleFeedbackUrb(completed_pending);
    } else {
        logCompletedUrb(completed_pending);
    }
    freePendingUrb(completed_pending);
    g_pending_urbs.erase(found);
    if (completed_pending.feedback && g_fd >= 0 && g_feedback_endpoint_address != 0) {
        const auto feedback_error = submitFeedbackLocked();
        if (!feedback_error.empty()) {
            return feedback_error;
        }
    }
    return {};
}

std::string reapCompletedLocked() {
    std::string error;
    while (error.empty() && !g_pending_urbs.empty()) {
        error = reapOneLocked(false);
        if (error.empty()) {
            break;
        }
    }
    while (error.empty() && static_cast<int>(g_pending_urbs.size()) >= kMaxPendingUrbs) {
        error = reapOneLocked(true);
    }
    return error;
}

void discardPendingLocked() {
    for (const auto& pending : g_pending_urbs) {
        ioctl(g_fd, USBDEVFS_DISCARDURB, pending.urb);
    }
}

void freeAllPendingLocked() {
    for (auto& pending : g_pending_urbs) {
        freePendingUrb(pending);
    }
    g_pending_urbs.clear();
}

std::string claimInterfaceLocked() {
    usbdevfs_disconnect_claim disconnect_claim = {};
    disconnect_claim.interface = static_cast<unsigned int>(g_interface_number);

    if (ioctl(g_fd, USBDEVFS_DISCONNECT_CLAIM, &disconnect_claim) == 0) {
        __android_log_print(
            ANDROID_LOG_INFO,
            kTag,
            "USBDEVFS_DISCONNECT_CLAIM ok interface=%d",
            g_interface_number);
        return {};
    }

    const int disconnect_claim_errno = errno;
    __android_log_print(
        ANDROID_LOG_WARN,
        kTag,
        "USBDEVFS_DISCONNECT_CLAIM failed interface=%d: %s",
        g_interface_number,
        strerror(disconnect_claim_errno));

    if (ioctl(g_fd, USBDEVFS_CLAIMINTERFACE, &g_interface_number) == 0) {
        __android_log_print(
            ANDROID_LOG_INFO,
            kTag,
            "USBDEVFS_CLAIMINTERFACE ok interface=%d",
            g_interface_number);
        return {};
    }

    return errorMessage("USBDEVFS_CLAIMINTERFACE");
}

void closeLocked() {
    if (g_fd < 0) {
        return;
    }

    __android_log_print(
        ANDROID_LOG_INFO,
        kTag,
        "closing exclusive USB fd=%d interface=%d endpoint=0x%x pendingUrbs=%zu",
        g_fd,
        g_interface_number,
        g_endpoint_address,
        g_pending_urbs.size());
    discardPendingLocked();
    if (g_interface_number >= 0) {
        ioctl(g_fd, USBDEVFS_RELEASEINTERFACE, &g_interface_number);
    }
    close(g_fd);
    freeAllPendingLocked();
    g_fd = -1;
    g_interface_number = -1;
    g_endpoint_address = -1;
    g_max_packet_size = 0;
    g_iso_packet_size = 0;
    g_feedback_endpoint_address = 0;
    g_feedback_packet_size = 0;
    g_feedback_frames_per_packet_q16 = 0;
    g_feedback_log_count = 0;
    g_write_log_count = 0;
    g_total_bytes = 0;
    g_total_urbs = 0;
    g_total_iso_packets = 0;
    g_last_stats_ms = 0;
}

std::string submitIsoPacketsLocked(
    const uint8_t* data,
    int length,
    const int* packet_lengths,
    int packet_count) {
    if (g_fd < 0) {
        return "USB exclusive device is not open.";
    }
    if (g_endpoint_address < 0 || g_max_packet_size <= 0) {
        return "USB exclusive endpoint is not configured.";
    }
    if (data == nullptr || length <= 0 || packet_lengths == nullptr || packet_count <= 0) {
        return {};
    }

    const int packets = std::min(packet_count, kMaxIsoPacketsPerUrb);
    int described_length = 0;
    for (int i = 0; i < packets; ++i) {
        if (packet_lengths[i] <= 0 || packet_lengths[i] > g_max_packet_size) {
            return "USB exclusive iso packet length is invalid.";
        }
        described_length += packet_lengths[i];
    }
    if (described_length != length) {
        return "USB exclusive iso packet lengths do not match PCM length.";
    }

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

    for (int i = 0; i < packets; ++i) {
        urb->iso_frame_desc[i].length = packet_lengths[i];
    }

    if (ioctl(g_fd, USBDEVFS_SUBMITURB, urb) < 0) {
        const auto error = errorMessage("USBDEVFS_SUBMITURB");
        free(buffer);
        free(urb);
        return error;
    }

    g_pending_urbs.push_back(PendingUrb{urb, buffer, length, packets, false});
    g_total_bytes += length;
    g_total_urbs += 1;
    g_total_iso_packets += packets;
    const long long now_ms = monotonicMillis();
    if (g_last_stats_ms == 0) {
        g_last_stats_ms = now_ms;
    } else if (now_ms - g_last_stats_ms >= 1000) {
        __android_log_print(
            ANDROID_LOG_INFO,
            kTag,
            "USB write stats bytes=%lld urbs=%lld isoPackets=%lld pendingUrbs=%zu isoPacketSize=%d endpoint=0x%x",
            g_total_bytes,
            g_total_urbs,
            g_total_iso_packets,
            g_pending_urbs.size(),
            g_iso_packet_size,
            g_endpoint_address);
        g_last_stats_ms = now_ms;
    }
    return reapCompletedLocked();
}

std::string submitIsoChunkLocked(const uint8_t* data, int length) {
    const int iso_packet_size =
        g_iso_packet_size > 0 ? std::min(g_iso_packet_size, g_max_packet_size) : g_max_packet_size;
    const int packets = std::max(
        1,
        std::min(kMaxIsoPacketsPerUrb, (length + iso_packet_size - 1) / iso_packet_size));
    int remaining = length;
    int packet_lengths[kMaxIsoPacketsPerUrb] = {};
    for (int i = 0; i < packets; ++i) {
        packet_lengths[i] = std::min(iso_packet_size, remaining);
        remaining -= packet_lengths[i];
    }
    return submitIsoPacketsLocked(data, length, packet_lengths, packets);
}

std::string submitFeedbackLocked() {
    if (g_fd < 0 || g_feedback_endpoint_address == 0 || g_feedback_packet_size <= 0) {
        return {};
    }

    const int packets = 1;
    const int length = std::min(4, std::max(3, g_feedback_packet_size));
    const size_t urb_size =
        sizeof(usbdevfs_urb) + sizeof(usbdevfs_iso_packet_desc) * packets;
    auto* urb = static_cast<usbdevfs_urb*>(calloc(1, urb_size));
    auto* buffer = static_cast<uint8_t*>(calloc(1, length));
    if (urb == nullptr || buffer == nullptr) {
        free(urb);
        free(buffer);
        return "Failed to allocate USB feedback transfer.";
    }

    urb->type = USBDEVFS_URB_TYPE_ISO;
    urb->endpoint = static_cast<unsigned char>(g_feedback_endpoint_address);
    urb->status = 0;
    urb->flags = USBDEVFS_URB_ISO_ASAP;
    urb->buffer = buffer;
    urb->buffer_length = length;
    urb->number_of_packets = packets;
    urb->iso_frame_desc[0].length = length;

    if (ioctl(g_fd, USBDEVFS_SUBMITURB, urb) < 0) {
        const auto error = errorMessage("USBDEVFS_SUBMITURB feedback");
        free(buffer);
        free(urb);
        return error;
    }

    g_pending_urbs.push_back(PendingUrb{urb, buffer, length, packets, true});
    return {};
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
    jint max_packet_size,
    jint feedback_endpoint_address,
    jint feedback_max_packet_size,
    jboolean interface_already_claimed) {
    std::lock_guard<std::mutex> lock(g_mutex);
    closeLocked();

    __android_log_print(
        ANDROID_LOG_INFO,
        kTag,
        "open requested fd=%d interface=%d alt=%d endpoint=0x%x maxPacket=%d",
        fd,
        interface_number,
        alternate_setting,
        endpoint_address,
        max_packet_size);

    const int duplicated = dup(fd);
    if (duplicated < 0) {
        return nullableError(env, errorMessage("dup"));
    }

    g_fd = duplicated;
    g_interface_number = interface_number;
    g_endpoint_address = endpoint_address;
    g_max_packet_size = max_packet_size;
    g_feedback_endpoint_address = feedback_endpoint_address;
    g_feedback_packet_size = feedback_max_packet_size;

    if (interface_already_claimed == JNI_TRUE) {
        __android_log_print(
            ANDROID_LOG_INFO,
            kTag,
            "USB interface already claimed by UsbDeviceConnection interface=%d",
            g_interface_number);
    } else {
        const auto claim_error = claimInterfaceLocked();
        if (!claim_error.empty()) {
            closeLocked();
            return nullableError(env, claim_error);
        }
    }

    usbdevfs_setinterface set_interface = {};
    set_interface.interface = interface_number;
    set_interface.altsetting = alternate_setting;
    if (ioctl(g_fd, USBDEVFS_SETINTERFACE, &set_interface) < 0) {
        const auto error = errorMessage("USBDEVFS_SETINTERFACE");
        closeLocked();
        return nullableError(env, error);
    }
    __android_log_print(
        ANDROID_LOG_INFO,
        kTag,
        "USBDEVFS_SETINTERFACE ok interface=%d alt=%d",
        interface_number,
        alternate_setting);

    if (g_feedback_endpoint_address != 0 && g_feedback_packet_size > 0) {
        const auto feedback_error = submitFeedbackLocked();
        if (!feedback_error.empty()) {
            __android_log_print(
                ANDROID_LOG_WARN,
                kTag,
                "%s",
                feedback_error.c_str());
        } else {
            __android_log_print(
                ANDROID_LOG_INFO,
                kTag,
                "USB feedback endpoint armed endpoint=0x%x maxPacket=%d",
                g_feedback_endpoint_address,
                g_feedback_packet_size);
        }
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
        const int iso_packet_size =
            g_iso_packet_size > 0 ? std::min(g_iso_packet_size, g_max_packet_size) : g_max_packet_size;
        const int max_chunk = std::max(1, iso_packet_size * kMaxIsoPacketsPerUrb);
        while (offset < safe_length && error.empty()) {
            const int chunk = std::min(max_chunk, safe_length - offset);
            error = submitIsoChunkLocked(input + offset, chunk);
            offset += chunk;
        }
    }

    env->ReleaseByteArrayElements(bytes, reinterpret_cast<jbyte*>(input), JNI_ABORT);
    if (error.empty() && g_write_log_count < 5) {
        ++g_write_log_count;
        __android_log_print(
            ANDROID_LOG_DEBUG,
            kTag,
            "writePcm submitted %d bytes to endpoint=0x%x isoPacket=%d",
            safe_length,
            g_endpoint_address,
            g_iso_packet_size);
    }
    return nullableError(env, error);
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_afalphy_sylvakru_UsbExclusiveNative_writeIsoPackets(
    JNIEnv* env,
    jobject,
    jbyteArray bytes,
    jintArray packet_lengths,
    jint packet_count) {
    if (bytes == nullptr || packet_lengths == nullptr || packet_count <= 0) {
        return nullptr;
    }

    const jsize array_length = env->GetArrayLength(bytes);
    const jsize lengths_length = env->GetArrayLength(packet_lengths);
    const int safe_packet_count = std::min<int>(
        std::min<int>(packet_count, lengths_length),
        kMaxIsoPacketsPerUrb);
    if (safe_packet_count <= 0) {
        return nullptr;
    }

    int safe_length = 0;
    jint stack_lengths[kMaxIsoPacketsPerUrb] = {};
    env->GetIntArrayRegion(packet_lengths, 0, safe_packet_count, stack_lengths);
    for (int i = 0; i < safe_packet_count; ++i) {
        if (stack_lengths[i] <= 0) {
            return nullableError(env, "USB exclusive iso packet length is invalid.");
        }
        safe_length += stack_lengths[i];
    }
    if (safe_length > array_length) {
        return nullableError(env, "USB exclusive iso packet data is shorter than packet lengths.");
    }

    auto* input = reinterpret_cast<uint8_t*>(env->GetByteArrayElements(bytes, nullptr));
    if (input == nullptr) {
        return nullableError(env, "Failed to access PCM buffer.");
    }

    std::string error;
    {
        std::lock_guard<std::mutex> lock(g_mutex);
        error = submitIsoPacketsLocked(input, safe_length, stack_lengths, safe_packet_count);
    }

    env->ReleaseByteArrayElements(bytes, reinterpret_cast<jbyte*>(input), JNI_ABORT);
    if (error.empty() && g_write_log_count < 5) {
        ++g_write_log_count;
        __android_log_print(
            ANDROID_LOG_DEBUG,
            kTag,
            "writeIsoPackets submitted %d bytes packets=%d endpoint=0x%x",
            safe_length,
            safe_packet_count,
            g_endpoint_address);
    }
    return nullableError(env, error);
}

extern "C" JNIEXPORT jint JNICALL
Java_com_afalphy_sylvakru_UsbExclusiveNative_feedbackFramesPerPacketQ16(JNIEnv*, jobject) {
    std::lock_guard<std::mutex> lock(g_mutex);
    return g_feedback_frames_per_packet_q16;
}

extern "C" JNIEXPORT void JNICALL
Java_com_afalphy_sylvakru_UsbExclusiveNative_setIsoPacketSize(
    JNIEnv*,
    jobject,
    jint packet_size) {
    std::lock_guard<std::mutex> lock(g_mutex);
    g_iso_packet_size = std::max(0, std::min(static_cast<int>(packet_size), g_max_packet_size));
    __android_log_print(
        ANDROID_LOG_INFO,
        kTag,
        "iso packet size set to %d bytes",
        g_iso_packet_size);
}

extern "C" JNIEXPORT void JNICALL
Java_com_afalphy_sylvakru_UsbExclusiveNative_close(JNIEnv*, jobject) {
    std::lock_guard<std::mutex> lock(g_mutex);
    closeLocked();
}
