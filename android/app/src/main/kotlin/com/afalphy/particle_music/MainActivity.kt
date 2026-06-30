package com.afalphy.sylvakru

import android.annotation.TargetApi
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.media.AudioDeviceCallback
import android.media.AudioAttributes
import android.media.AudioDeviceInfo
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioMixerAttributes
import android.media.AudioTrack
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbInterface
import android.hardware.usb.UsbManager
import com.hchen.superlyricapi.SuperLyricData
import com.hchen.superlyricapi.SuperLyricHelper
import com.hchen.superlyricapi.SuperLyricLine
import com.hchen.superlyricapi.SuperLyricWord
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private val channelName = "com.afalphy.sylvakru/usb_audio"
    private val superLyricChannelName = "com.afalphy.sylvakru/super_lyric"
    private val usbPermissionAction = "com.afalphy.sylvakru.USB_PERMISSION"
    private lateinit var usbAudioChannel: MethodChannel
    private var usbAudioDeviceCallback: AudioDeviceCallback? = null
    private var pendingExclusiveProbeResult: MethodChannel.Result? = null
    private var pendingExclusiveProbeDevice: UsbDevice? = null
    private var usbPermissionReceiver: BroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        usbAudioChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        usbAudioChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getStatus" -> result.success(getStatus())
                "applyPreferredOutput" -> result.success(applyPreferredOutput(call))
                "clearPreferredOutput" -> result.success(clearPreferredOutput(call))
                "probeExclusiveAccess" -> probeExclusiveAccess(result)
                else -> result.notImplemented()
            }
        }
        registerUsbAudioDeviceCallback()
        registerUsbPermissionReceiver()

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, superLyricChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "sendLyric" -> result.success(sendSuperLyric(call))
                    "sendStop" -> result.success(sendSuperLyricStop())
                    else -> result.notImplemented()
                }
            }

        ensureSuperLyricPublisherRegistered()
    }

    override fun onDestroy() {
        unregisterUsbPermissionReceiver()
        unregisterUsbAudioDeviceCallback()
        sendSuperLyricStop()
        super.onDestroy()
    }

    private fun registerUsbPermissionReceiver() {
        if (usbPermissionReceiver != null) {
            return
        }

        val receiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context, intent: Intent) {
                if (intent.action != usbPermissionAction) {
                    return
                }

                val result = pendingExclusiveProbeResult ?: return
                val device = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    intent.getParcelableExtra(UsbManager.EXTRA_DEVICE, UsbDevice::class.java)
                } else {
                    @Suppress("DEPRECATION")
                    intent.getParcelableExtra(UsbManager.EXTRA_DEVICE)
                } ?: pendingExclusiveProbeDevice
                val granted = intent.getBooleanExtra(UsbManager.EXTRA_PERMISSION_GRANTED, false)

                pendingExclusiveProbeResult = null
                pendingExclusiveProbeDevice = null

                if (device == null || !granted) {
                    result.success(
                        exclusiveProbeResult(
                            supported = device != null,
                            permissionGranted = false,
                            device = device,
                            audioInterfaceCount = device?.audioInterfaceCount() ?: 0,
                            claimedInterfaceCount = 0,
                            rawDescriptorLength = 0,
                            message = "USB permission was denied.",
                        ),
                    )
                    return
                }

                result.success(runExclusiveProbe(device))
            }
        }

        val filter = IntentFilter(usbPermissionAction)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(receiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(receiver, filter)
        }
        usbPermissionReceiver = receiver
    }

    private fun unregisterUsbPermissionReceiver() {
        val receiver = usbPermissionReceiver ?: return
        unregisterReceiver(receiver)
        usbPermissionReceiver = null
    }

    private fun registerUsbAudioDeviceCallback() {
        if (usbAudioDeviceCallback != null) {
            return
        }

        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val callback = object : AudioDeviceCallback() {
            override fun onAudioDevicesAdded(addedDevices: Array<out AudioDeviceInfo>) {
                addedDevices
                    .filter { it.isUsbAudioOutput() }
                    .forEach { device -> sendUsbAudioDeviceEvent("added", device.id) }
            }

            override fun onAudioDevicesRemoved(removedDevices: Array<out AudioDeviceInfo>) {
                removedDevices
                    .filter { it.isUsbAudioOutput() }
                    .forEach { device -> sendUsbAudioDeviceEvent("removed", device.id) }
            }
        }

        audioManager.registerAudioDeviceCallback(callback, Handler(Looper.getMainLooper()))
        usbAudioDeviceCallback = callback
    }

    private fun unregisterUsbAudioDeviceCallback() {
        val callback = usbAudioDeviceCallback ?: return
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        audioManager.unregisterAudioDeviceCallback(callback)
        usbAudioDeviceCallback = null
    }

    private fun sendUsbAudioDeviceEvent(type: String, deviceId: Int) {
        runOnUiThread {
            usbAudioChannel.invokeMethod(
                "onUsbAudioDeviceEvent",
                mapOf(
                    "type" to type,
                    "deviceId" to deviceId,
                    "status" to getStatus(),
                ),
            )
        }
    }

    private fun probeExclusiveAccess(result: MethodChannel.Result) {
        val usbManager = getSystemService(Context.USB_SERVICE) as UsbManager
        val device = findUsbAudioDevice(usbManager)
        if (device == null) {
            result.success(
                exclusiveProbeResult(
                    supported = false,
                    permissionGranted = false,
                    device = null,
                    audioInterfaceCount = 0,
                    claimedInterfaceCount = 0,
                    rawDescriptorLength = 0,
                    message = "No USB Audio Class device was found.",
                ),
            )
            return
        }

        if (!usbManager.hasPermission(device)) {
            if (pendingExclusiveProbeResult != null) {
                result.success(
                    exclusiveProbeResult(
                        supported = true,
                        permissionGranted = false,
                        device = device,
                        audioInterfaceCount = device.audioInterfaceCount(),
                        claimedInterfaceCount = 0,
                        rawDescriptorLength = 0,
                        message = "USB permission request is already pending.",
                    ),
                )
                return
            }

            pendingExclusiveProbeResult = result
            pendingExclusiveProbeDevice = device
            val flags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                PendingIntent.FLAG_MUTABLE
            } else {
                0
            }
            val permissionIntent = PendingIntent.getBroadcast(
                this,
                0,
                Intent(usbPermissionAction).setPackage(packageName),
                flags,
            )
            usbManager.requestPermission(device, permissionIntent)
            return
        }

        result.success(runExclusiveProbe(device))
    }

    private fun runExclusiveProbe(device: UsbDevice): Map<String, Any?> {
        val usbManager = getSystemService(Context.USB_SERVICE) as UsbManager
        val audioInterfaces = device.audioInterfaces()
        val connection = usbManager.openDevice(device)
            ?: return exclusiveProbeResult(
                supported = true,
                permissionGranted = true,
                device = device,
                audioInterfaceCount = audioInterfaces.size,
                claimedInterfaceCount = 0,
                rawDescriptorLength = 0,
                message = "Failed to open USB device.",
            )

        return connection.useConnection {
            val claimed = mutableListOf<UsbInterface>()
            var rawDescriptorLength = 0
            try {
                rawDescriptorLength = connection.rawDescriptors?.size ?: 0
                for (usbInterface in audioInterfaces) {
                    if (connection.claimInterface(usbInterface, true)) {
                        claimed.add(usbInterface)
                    }
                }
                exclusiveProbeResult(
                    supported = true,
                    permissionGranted = true,
                    device = device,
                    audioInterfaceCount = audioInterfaces.size,
                    claimedInterfaceCount = claimed.size,
                    rawDescriptorLength = rawDescriptorLength,
                    message = if (claimed.isNotEmpty()) {
                        "USB Audio interface can be claimed."
                    } else {
                        "USB Audio interface was found but could not be claimed."
                    },
                )
            } catch (error: RuntimeException) {
                exclusiveProbeResult(
                    supported = true,
                    permissionGranted = true,
                    device = device,
                    audioInterfaceCount = audioInterfaces.size,
                    claimedInterfaceCount = claimed.size,
                    rawDescriptorLength = rawDescriptorLength,
                    message = "USB exclusive probe failed: ${error.message}",
                )
            } finally {
                claimed.forEach { connection.releaseInterface(it) }
            }
        }
    }

    private inline fun UsbDeviceConnection.useConnection(
        block: () -> Map<String, Any?>,
    ): Map<String, Any?> {
        return try {
            block()
        } finally {
            close()
        }
    }

    private fun findUsbAudioDevice(usbManager: UsbManager): UsbDevice? {
        return usbManager.deviceList.values.firstOrNull { it.audioInterfaceCount() > 0 }
    }

    private fun UsbDevice.audioInterfaces(): List<UsbInterface> {
        val interfaces = mutableListOf<UsbInterface>()
        for (index in 0 until interfaceCount) {
            val usbInterface = getInterface(index)
            if (usbInterface.interfaceClass == UsbConstants.USB_CLASS_AUDIO) {
                interfaces.add(usbInterface)
            }
        }
        return interfaces
    }

    private fun UsbDevice.audioInterfaceCount(): Int {
        return audioInterfaces().size
    }

    private fun exclusiveProbeResult(
        supported: Boolean,
        permissionGranted: Boolean,
        device: UsbDevice?,
        audioInterfaceCount: Int,
        claimedInterfaceCount: Int,
        rawDescriptorLength: Int,
        message: String,
    ): Map<String, Any?> {
        return mapOf(
            "supported" to supported,
            "permissionGranted" to permissionGranted,
            "deviceName" to device?.productName,
            "deviceId" to device?.deviceId,
            "audioInterfaceCount" to audioInterfaceCount,
            "claimedInterfaceCount" to claimedInterfaceCount,
            "rawDescriptorLength" to rawDescriptorLength,
            "message" to message,
        )
    }

    private fun sendSuperLyric(call: MethodCall): Boolean {
        val lyric = call.argument<String>("lyric")?.trim().orEmpty()
        if (lyric.isEmpty()) {
            return sendSuperLyricStop()
        }

        val startTime = call.argument<Number>("startTime")?.toLong() ?: 0L
        val endTime = call.argument<Number>("endTime")?.toLong() ?: startTime
        val words = parseSuperLyricWords(call.argument<List<Any?>>("tokens"))

        return runSuperLyricAction("sendLyric") {
            SuperLyricHelper.sendLyric(
                SuperLyricData().setLyric(
                    if (words.isNotEmpty()) {
                        SuperLyricLine(lyric, words.toTypedArray(), startTime, endTime)
                    } else if (endTime > startTime) {
                        SuperLyricLine(lyric, startTime, endTime)
                    } else {
                        SuperLyricLine(lyric)
                    },
                ),
            )
        }
    }

    private fun parseSuperLyricWords(tokens: List<Any?>?): List<SuperLyricWord> {
        return tokens
            ?.mapNotNull { token ->
                val map = token as? Map<*, *> ?: return@mapNotNull null
                val text = map["text"] as? String ?: return@mapNotNull null
                if (text.isEmpty()) return@mapNotNull null

                val startTime = (map["startTime"] as? Number)?.toLong() ?: return@mapNotNull null
                val endTime = (map["endTime"] as? Number)?.toLong() ?: return@mapNotNull null
                SuperLyricWord(text, startTime, endTime)
            }
            .orEmpty()
    }

    private fun sendSuperLyricStop(): Boolean {
        return runSuperLyricAction("sendStop") {
            SuperLyricHelper.sendStop(SuperLyricData())
        }
    }

    private fun runSuperLyricAction(actionName: String, action: () -> Unit): Boolean {
        if (!ensureSuperLyricPublisherRegistered()) {
            return false
        }

        return try {
            action()
            true
        } catch (error: Throwable) {
            Log.w("MainActivity", "SuperLyric $actionName failed.", error)
            false
        }
    }

    private fun ensureSuperLyricPublisherRegistered(): Boolean {
        return try {
            if (!SuperLyricHelper.isAvailable()) {
                return false
            }

            if (!SuperLyricHelper.isPublisherRegistered()) {
                SuperLyricHelper.registerPublisher()
            }
            true
        } catch (error: Throwable) {
            Log.w("MainActivity", "SuperLyric service is unavailable.", error)
            false
        }
    }

    private fun getStatus(
        preferredApplied: Boolean = false,
        message: String? = null,
    ): Map<String, Any?> {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val devices = getUsbAudioDevices(audioManager)
        val activeDevice = getActiveUsbAudioDevice(audioManager, devices)
        val outputDevice = activeDevice ?: getActiveOutputDevice(audioManager)
        val preferredMixerAttributes = if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE &&
            activeDevice != null
        ) {
            getPreferredMixerAttributes(audioManager, activeDevice)
        } else {
            null
        }

        return mapOf(
            "supported" to devices.isNotEmpty(),
            "androidSdk" to Build.VERSION.SDK_INT,
            "activeDeviceId" to activeDevice?.id,
            "preferredApplied" to preferredApplied,
            "preferredSampleRate" to preferredMixerAttributes?.format?.sampleRate,
            "preferredEncoding" to preferredMixerAttributes?.format?.encoding?.let {
                encodingName(it)
            },
            "preferredBitPerfect" to (
                preferredMixerAttributes?.mixerBehavior ==
                    AudioMixerAttributes.MIXER_BEHAVIOR_BIT_PERFECT
                ),
            "outputDeviceName" to outputDevice?.productName?.toString(),
            "outputSampleRate" to outputSampleRate(outputDevice),
            "outputEncoding" to outputEncoding(outputDevice),
            "message" to (message ?: defaultStatusMessage(devices)),
            "devices" to devices.map { it.toMap(audioManager) },
        )
    }

    private fun applyPreferredOutput(call: MethodCall): Map<String, Any?> {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val devices = getUsbAudioDevices(audioManager)
        val device = findRequestedDevice(audioManager, devices, call.argument<Int>("deviceId"))
            ?: return getStatus(message = "No USB audio output device detected.")

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            return getStatus(
                message = "USB mixer attributes require Android 14 or newer.",
            )
        }

        return applyPreferredOutputApi34(audioManager, device, call)
    }

    private fun clearPreferredOutput(call: MethodCall): Map<String, Any?> {
        val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
        val devices = getUsbAudioDevices(audioManager)
        val device = findRequestedDevice(audioManager, devices, call.argument<Int>("deviceId"))
            ?: return getStatus(message = "No USB audio output device detected.")

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            return getStatus(
                message = "USB mixer attributes require Android 14 or newer.",
            )
        }

        val cleared = clearPreferredOutputApi34(audioManager, device)
        return getStatus(
            preferredApplied = false,
            message = if (cleared) {
                "Cleared preferred USB mixer attributes."
            } else {
                "No preferred USB mixer attributes were cleared."
            },
        )
    }

    @TargetApi(Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
    private fun applyPreferredOutputApi34(
        audioManager: AudioManager,
        device: AudioDeviceInfo,
        call: MethodCall,
    ): Map<String, Any?> {
        val sampleRate = call.argument<Int>("sampleRate")
            ?: chooseSampleRate(audioManager, device)
            ?: 48000
        val encoding = encodingFromName(
            call.argument<String>("encoding") ?: "pcm_24bit_packed",
        )
        val bitPerfect = call.argument<Boolean>("bitPerfect") ?: true

        val format = AudioFormat.Builder()
            .setSampleRate(sampleRate)
            .setEncoding(encoding)
            .setChannelMask(AudioFormat.CHANNEL_OUT_STEREO)
            .build()
        val mixerAttributes = AudioMixerAttributes.Builder(format)
            .setMixerBehavior(
                if (bitPerfect) {
                    AudioMixerAttributes.MIXER_BEHAVIOR_BIT_PERFECT
                } else {
                    AudioMixerAttributes.MIXER_BEHAVIOR_DEFAULT
                },
            )
            .build()

        return try {
            val applied = audioManager.setPreferredMixerAttributes(
                mediaAudioAttributes(),
                device,
                mixerAttributes,
            )
            getStatus(
                preferredApplied = applied,
                message = if (applied) {
                    "Applied preferred USB mixer attributes."
                } else {
                    "Device rejected preferred USB mixer attributes."
                },
            )
        } catch (error: RuntimeException) {
            getStatus(message = "Failed to apply USB mixer attributes: ${error.message}")
        }
    }

    @TargetApi(Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
    private fun clearPreferredOutputApi34(
        audioManager: AudioManager,
        device: AudioDeviceInfo,
    ): Boolean {
        return try {
            audioManager.clearPreferredMixerAttributes(mediaAudioAttributes(), device)
        } catch (_: RuntimeException) {
            false
        }
    }

    private fun getUsbAudioDevices(audioManager: AudioManager): List<AudioDeviceInfo> {
        return audioManager
            .getDevices(AudioManager.GET_DEVICES_OUTPUTS)
            .filter { it.isUsbAudioOutput() }
    }

    private fun getActiveUsbAudioDevice(
        audioManager: AudioManager,
        devices: List<AudioDeviceInfo>,
    ): AudioDeviceInfo? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) {
            return null
        }

        val activeDevices = audioManager.getAudioDevicesForAttributes(mediaAudioAttributes())
        return activeDevices.firstOrNull { active ->
            devices.any { it.id == active.id }
        }
    }

    private fun getActiveOutputDevice(audioManager: AudioManager): AudioDeviceInfo? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            audioManager
                .getAudioDevicesForAttributes(mediaAudioAttributes())
                .firstOrNull()
                ?.let { return it }
        }

        return audioManager
            .getDevices(AudioManager.GET_DEVICES_OUTPUTS)
            .firstOrNull { it.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER }
            ?: audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS).firstOrNull()
    }

    private fun outputSampleRate(device: AudioDeviceInfo?): Int? {
        device?.sampleRates?.filter { it > 0 }?.maxOrNull()?.let { return it }
        return AudioTrack
            .getNativeOutputSampleRate(AudioManager.STREAM_MUSIC)
            .takeIf { it > 0 }
    }

    private fun outputEncoding(device: AudioDeviceInfo?): String? {
        return device
            ?.encodings
            ?.firstOrNull { it == AudioFormat.ENCODING_PCM_16BIT }
            ?.let { encodingName(it) }
            ?: device?.encodings?.firstOrNull()?.let { encodingName(it) }
    }

    private fun findRequestedDevice(
        audioManager: AudioManager,
        devices: List<AudioDeviceInfo>,
        requestedDeviceId: Int?,
    ): AudioDeviceInfo? {
        if (requestedDeviceId != null) {
            return devices.firstOrNull { it.id == requestedDeviceId }
        }
        return getActiveUsbAudioDevice(audioManager, devices) ?: devices.firstOrNull()
    }

    @TargetApi(Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
    private fun chooseSampleRate(
        audioManager: AudioManager,
        device: AudioDeviceInfo,
    ): Int? {
        val mixerSampleRates = getSupportedMixerSampleRates(audioManager, device)
        if (mixerSampleRates.isNotEmpty()) {
            return mixerSampleRates.maxOrNull()
        }
        return device.sampleRates.maxOrNull()
    }

    private fun mediaAudioAttributes(): AudioAttributes {
        return AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_MEDIA)
            .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
            .build()
    }

    private fun defaultStatusMessage(devices: List<AudioDeviceInfo>): String {
        return if (devices.isEmpty()) {
            "No USB audio output device detected."
        } else if (Build.VERSION.SDK_INT < Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            "USB audio device detected. Preferred mixer attributes require Android 14 or newer."
        } else {
            "USB audio device detected."
        }
    }

    private fun AudioDeviceInfo.isUsbAudioOutput(): Boolean {
        return type == AudioDeviceInfo.TYPE_USB_DEVICE ||
            type == AudioDeviceInfo.TYPE_USB_HEADSET ||
            type == AudioDeviceInfo.TYPE_USB_ACCESSORY
    }

    private fun AudioDeviceInfo.toMap(audioManager: AudioManager): Map<String, Any?> {
        return mapOf(
            "id" to id,
            "name" to productName.toString(),
            "type" to audioDeviceTypeName(type),
            "address" to address,
            "sampleRates" to sampleRates.toList(),
            "encodings" to encodings.map { encodingName(it) },
            "channelCounts" to channelCounts.toList(),
            "supportedMixerSampleRates" to if (
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE
            ) {
                getSupportedMixerSampleRates(audioManager, this)
            } else {
                emptyList()
            },
            "supportsBitPerfectMixer" to if (
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE
            ) {
                supportsBitPerfectMixer(audioManager, this)
            } else {
                false
            },
        )
    }

    @TargetApi(Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
    private fun getSupportedMixerSampleRates(
        audioManager: AudioManager,
        device: AudioDeviceInfo,
    ): List<Int> {
        return try {
            audioManager
                .getSupportedMixerAttributes(device)
                .map { it.format.sampleRate }
                .filter { it > 0 }
                .distinct()
                .sorted()
        } catch (_: RuntimeException) {
            emptyList()
        }
    }

    @TargetApi(Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
    private fun supportsBitPerfectMixer(
        audioManager: AudioManager,
        device: AudioDeviceInfo,
    ): Boolean {
        return try {
            audioManager
                .getSupportedMixerAttributes(device)
                .any { it.mixerBehavior == AudioMixerAttributes.MIXER_BEHAVIOR_BIT_PERFECT }
        } catch (_: RuntimeException) {
            false
        }
    }

    @TargetApi(Build.VERSION_CODES.UPSIDE_DOWN_CAKE)
    private fun getPreferredMixerAttributes(
        audioManager: AudioManager,
        device: AudioDeviceInfo,
    ): AudioMixerAttributes? {
        return try {
            audioManager.getPreferredMixerAttributes(mediaAudioAttributes(), device)
        } catch (_: RuntimeException) {
            null
        }
    }

    private fun audioDeviceTypeName(type: Int): String {
        return when (type) {
            AudioDeviceInfo.TYPE_USB_DEVICE -> "usb_device"
            AudioDeviceInfo.TYPE_USB_HEADSET -> "usb_headset"
            AudioDeviceInfo.TYPE_USB_ACCESSORY -> "usb_accessory"
            AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> "builtin_speaker"
            AudioDeviceInfo.TYPE_BLUETOOTH_A2DP -> "bluetooth_a2dp"
            AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> "bluetooth_sco"
            AudioDeviceInfo.TYPE_WIRED_HEADPHONES -> "wired_headphones"
            AudioDeviceInfo.TYPE_WIRED_HEADSET -> "wired_headset"
            else -> "unknown"
        }
    }

    private fun encodingName(encoding: Int): String {
        return when (encoding) {
            AudioFormat.ENCODING_PCM_8BIT -> "pcm_8bit"
            AudioFormat.ENCODING_PCM_16BIT -> "pcm_16bit"
            AudioFormat.ENCODING_PCM_24BIT_PACKED -> "pcm_24bit_packed"
            AudioFormat.ENCODING_PCM_32BIT -> "pcm_32bit"
            AudioFormat.ENCODING_PCM_FLOAT -> "pcm_float"
            else -> "encoding_$encoding"
        }
    }

    private fun encodingFromName(name: String): Int {
        return when (name) {
            "pcm_8bit" -> AudioFormat.ENCODING_PCM_8BIT
            "pcm_16bit" -> AudioFormat.ENCODING_PCM_16BIT
            "pcm_32bit" -> AudioFormat.ENCODING_PCM_32BIT
            "pcm_float" -> AudioFormat.ENCODING_PCM_FLOAT
            else -> AudioFormat.ENCODING_PCM_24BIT_PACKED
        }
    }
}
