package com.afalphy.sylvakru

import android.content.Context
import android.hardware.usb.UsbConstants
import android.hardware.usb.UsbDevice
import android.hardware.usb.UsbDeviceConnection
import android.hardware.usb.UsbEndpoint
import android.hardware.usb.UsbInterface
import android.hardware.usb.UsbManager
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.os.Build
import android.os.SystemClock
import android.util.Log
import java.io.File
import java.nio.ByteBuffer
import java.util.Locale
import java.util.concurrent.atomic.AtomicBoolean

object UsbExclusiveNative {
    init {
        System.loadLibrary("sylvakru_usb_exclusive")
    }

    external fun open(
        fd: Int,
        interfaceNumber: Int,
        alternateSetting: Int,
        endpointAddress: Int,
        maxPacketSize: Int,
    ): String?

    external fun writePcm(bytes: ByteArray, length: Int): String?

    external fun close()
}

class UsbExclusiveAudioEngine(
    private val context: Context,
    private val emitState: (Map<String, Any?>) -> Unit,
) {
    private var worker: Thread? = null
    private var connection: UsbDeviceConnection? = null
    private val paused = AtomicBoolean(false)
    private val stopped = AtomicBoolean(false)

    @Volatile private var currentState = inactiveState()

    fun capabilities(usbManager: UsbManager, device: UsbDevice?): Map<String, Any?> {
        if (device == null) {
            return capability(
                available = false,
                permissionGranted = false,
                device = null,
                target = null,
                message = "No USB Audio Class output endpoint was found.",
            )
        }

        val target = findOutputTarget(device)
        return capability(
            available = target != null,
            permissionGranted = usbManager.hasPermission(device),
            device = device,
            target = target,
            message = if (target != null) {
                "USB exclusive endpoint is available."
            } else {
                "USB Audio device was found, but no isochronous OUT endpoint was exposed."
            },
        )
    }

    fun start(
        usbManager: UsbManager,
        device: UsbDevice?,
        arguments: Map<String, Any?>,
    ): Map<String, Any?> {
        stop()

        if (device == null) {
            return updateState(inactiveState("No USB Audio Class device was found."))
        }
        if (!usbManager.hasPermission(device)) {
            return updateState(inactiveState("USB permission is required before exclusive playback."))
        }

        val filePath = arguments["filePath"] as? String
        if (filePath.isNullOrBlank()) {
            return updateState(inactiveState("Exclusive playback requires a local audio file path."))
        }

        val file = File(filePath)
        if (!file.exists()) {
            return updateState(inactiveState("Exclusive playback file does not exist: $filePath"))
        }
        if (!isSupportedFile(filePath)) {
            return updateState(inactiveState("Exclusive playback currently supports FLAC and WAV only."))
        }

        val target = findOutputTarget(device)
            ?: return updateState(inactiveState("No isochronous USB Audio OUT endpoint was found."))
        val openedConnection = usbManager.openDevice(device)
            ?: return updateState(inactiveState("Failed to open USB device for exclusive playback."))

        val openError = UsbExclusiveNative.open(
            openedConnection.fileDescriptor,
            target.usbInterface.id,
            target.alternateSetting,
            target.endpoint.address,
            target.endpoint.maxPacketSize,
        )
        if (openError != null) {
            openedConnection.close()
            return updateState(inactiveState(openError))
        }

        connection = openedConnection
        paused.set(arguments["startPaused"] == true)
        stopped.set(false)

        val initialState = mapOf(
            "active" to true,
            "playing" to !paused.get(),
            "positionMs" to 0,
            "durationMs" to null,
            "sampleRate" to arguments["sampleRate"],
            "bitDepth" to arguments["bitDepth"],
            "format" to file.extension.lowercase(Locale.ROOT),
            "message" to "USB exclusive playback prepared.",
        )
        updateState(initialState)

        worker = Thread({
            decodeAndWrite(file, target)
        }, "SylvakruUsbExclusive")
        worker?.start()
        return currentState
    }

    fun pause(): Map<String, Any?> {
        paused.set(true)
        return updateState(currentState + mapOf("playing" to false, "message" to "Paused."))
    }

    fun resume(): Map<String, Any?> {
        if (currentState["active"] != true) {
            return updateState(inactiveState("No exclusive playback is active."))
        }
        paused.set(false)
        return updateState(currentState + mapOf("playing" to true, "message" to "Playing."))
    }

    fun seek(positionMs: Long): Map<String, Any?> {
        return updateState(
            currentState + mapOf(
                "message" to "USB exclusive seek is not supported in this MVP.",
                "positionMs" to positionMs,
            ),
        )
    }

    fun stop(): Map<String, Any?> {
        stopped.set(true)
        paused.set(false)
        val thread = worker
        worker = null
        if (thread != null && thread != Thread.currentThread()) {
            thread.join(500)
        }
        UsbExclusiveNative.close()
        connection?.close()
        connection = null
        return updateState(inactiveState("USB exclusive playback stopped."))
    }

    fun release(): Map<String, Any?> = stop()

    private fun decodeAndWrite(file: File, target: OutputTarget) {
        val extractor = MediaExtractor()
        var codec: MediaCodec? = null
        var sawInputEos = false
        var outputDone = false
        val info = MediaCodec.BufferInfo()
        val startMs = SystemClock.elapsedRealtime()
        var lastPositionEmitMs = 0L

        try {
            extractor.setDataSource(file.absolutePath)
            val trackIndex = findAudioTrack(extractor)
            if (trackIndex < 0) {
                emitError("No audio track was found in ${file.name}.")
                return
            }

            extractor.selectTrack(trackIndex)
            val format = extractor.getTrackFormat(trackIndex)
            val mime = format.getString(MediaFormat.KEY_MIME)
            if (mime.isNullOrBlank()) {
                emitError("Audio MIME type is missing.")
                return
            }

            codec = MediaCodec.createDecoderByType(mime)
            codec.configure(format, null, null, 0)
            codec.start()

            val durationMs = if (format.containsKey(MediaFormat.KEY_DURATION)) {
                format.getLong(MediaFormat.KEY_DURATION) / 1000
            } else {
                null
            }
            val sampleRate = if (format.containsKey(MediaFormat.KEY_SAMPLE_RATE)) {
                format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
            } else {
                null
            }
            val channels = if (format.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) {
                format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
            } else {
                null
            }

            updateState(
                currentState + mapOf(
                    "active" to true,
                    "playing" to !paused.get(),
                    "durationMs" to durationMs,
                    "sampleRate" to sampleRate,
                    "bitDepth" to 16,
                    "message" to "USB exclusive decoding ${file.name} to ${target.endpointLabel}, channels=$channels.",
                ),
            )

            while (!stopped.get() && !outputDone) {
                while (paused.get() && !stopped.get()) {
                    Thread.sleep(25)
                }
                if (stopped.get()) break

                if (!sawInputEos) {
                    val inputIndex = codec.dequeueInputBuffer(10_000)
                    if (inputIndex >= 0) {
                        val inputBuffer = codec.getInputBuffer(inputIndex)
                        val sampleSize = if (inputBuffer != null) {
                            extractor.readSampleData(inputBuffer, 0)
                        } else {
                            -1
                        }
                        if (sampleSize < 0) {
                            codec.queueInputBuffer(
                                inputIndex,
                                0,
                                0,
                                0,
                                MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                            )
                            sawInputEos = true
                        } else {
                            codec.queueInputBuffer(
                                inputIndex,
                                0,
                                sampleSize,
                                extractor.sampleTime,
                                0,
                            )
                            extractor.advance()
                        }
                    }
                }

                val outputIndex = codec.dequeueOutputBuffer(info, 10_000)
                if (outputIndex >= 0) {
                    val outputBuffer = codec.getOutputBuffer(outputIndex)
                    if (outputBuffer != null && info.size > 0) {
                        writeOutputBuffer(outputBuffer, info)
                    }
                    if ((info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                        outputDone = true
                    }
                    codec.releaseOutputBuffer(outputIndex, false)

                    val positionMs = if (info.presentationTimeUs > 0) {
                        info.presentationTimeUs / 1000
                    } else {
                        SystemClock.elapsedRealtime() - startMs
                    }
                    if (positionMs - lastPositionEmitMs >= 250) {
                        lastPositionEmitMs = positionMs
                        updateState(
                            currentState + mapOf(
                                "active" to true,
                                "playing" to !paused.get(),
                                "positionMs" to positionMs,
                            ),
                        )
                    }
                } else if (outputIndex == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED) {
                    val outputFormat = codec.outputFormat
                    val outputSampleRate = if (outputFormat.containsKey(MediaFormat.KEY_SAMPLE_RATE)) {
                        outputFormat.getInteger(MediaFormat.KEY_SAMPLE_RATE)
                    } else {
                        null
                    }
                    val pcmEncoding = if (
                        Build.VERSION.SDK_INT >= Build.VERSION_CODES.N &&
                        outputFormat.containsKey(MediaFormat.KEY_PCM_ENCODING)
                    ) {
                        outputFormat.getInteger(MediaFormat.KEY_PCM_ENCODING)
                    } else {
                        null
                    }
                    updateState(
                        currentState + mapOf(
                            "sampleRate" to outputSampleRate,
                            "bitDepth" to bitDepthFromPcmEncoding(pcmEncoding),
                        ),
                    )
                }
            }

            if (!stopped.get()) {
                updateState(inactiveState("USB exclusive playback completed."))
            }
        } catch (error: Throwable) {
            Log.w("UsbExclusiveAudioEngine", "Exclusive playback failed.", error)
            emitError(error.message ?: "USB exclusive playback failed.")
        } finally {
            try {
                codec?.stop()
            } catch (_: Throwable) {
            }
            codec?.release()
            extractor.release()
            UsbExclusiveNative.close()
            connection?.close()
            connection = null
        }
    }

    private fun writeOutputBuffer(outputBuffer: ByteBuffer, info: MediaCodec.BufferInfo) {
        val data = ByteArray(info.size)
        outputBuffer.position(info.offset)
        outputBuffer.limit(info.offset + info.size)
        outputBuffer.get(data)
        val error = UsbExclusiveNative.writePcm(data, data.size)
        if (error != null) {
            throw IllegalStateException(error)
        }
    }

    private fun findAudioTrack(extractor: MediaExtractor): Int {
        for (index in 0 until extractor.trackCount) {
            val format = extractor.getTrackFormat(index)
            val mime = format.getString(MediaFormat.KEY_MIME)
            if (mime?.startsWith("audio/") == true) {
                return index
            }
        }
        return -1
    }

    private fun findOutputTarget(device: UsbDevice): OutputTarget? {
        for (index in 0 until device.interfaceCount) {
            val usbInterface = device.getInterface(index)
            if (usbInterface.interfaceClass != UsbConstants.USB_CLASS_AUDIO) {
                continue
            }
            for (endpointIndex in 0 until usbInterface.endpointCount) {
                val endpoint = usbInterface.getEndpoint(endpointIndex)
                if (
                    endpoint.direction == UsbConstants.USB_DIR_OUT &&
                    endpoint.type == UsbConstants.USB_ENDPOINT_XFER_ISOC
                ) {
                    return OutputTarget(usbInterface, endpoint)
                }
            }
        }
        return null
    }

    private fun isSupportedFile(filePath: String): Boolean {
        val lower = filePath.lowercase(Locale.ROOT)
        return lower.endsWith(".flac") || lower.endsWith(".wav") || lower.endsWith(".wave")
    }

    private fun capability(
        available: Boolean,
        permissionGranted: Boolean,
        device: UsbDevice?,
        target: OutputTarget?,
        message: String,
    ): Map<String, Any?> {
        return mapOf(
            "available" to available,
            "permissionGranted" to permissionGranted,
            "deviceName" to device?.productName,
            "deviceId" to device?.deviceId,
            "interfaceNumber" to target?.usbInterface?.id,
            "alternateSetting" to target?.alternateSetting,
            "endpointAddress" to target?.endpoint?.address,
            "maxPacketSize" to target?.endpoint?.maxPacketSize,
            "sampleRates" to listOf(44100, 48000, 88200, 96000, 176400, 192000),
            "bitDepths" to listOf(16, 24, 32),
            "channelCounts" to listOf(2),
            "message" to message,
        )
    }

    private fun emitError(message: String) {
        updateState(inactiveState(message))
    }

    private fun updateState(state: Map<String, Any?>): Map<String, Any?> {
        currentState = state
        emitState(state)
        return state
    }

    private fun inactiveState(message: String? = null): Map<String, Any?> {
        return mapOf(
            "active" to false,
            "playing" to false,
            "positionMs" to 0,
            "durationMs" to null,
            "sampleRate" to null,
            "bitDepth" to null,
            "format" to null,
            "message" to message,
        )
    }

    private fun bitDepthFromPcmEncoding(pcmEncoding: Int?): Int {
        return when (pcmEncoding) {
            3 -> 8
            4 -> 32
            0x80000000.toInt() -> 24
            else -> 16
        }
    }

    private data class OutputTarget(
        val usbInterface: UsbInterface,
        val endpoint: UsbEndpoint,
    ) {
        val alternateSetting: Int
            get() = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                usbInterface.alternateSetting
            } else {
                0
            }

        val endpointLabel: String
            get() = "interface=${usbInterface.id}, alt=$alternateSetting, endpoint=0x${
                endpoint.address.toString(16)
            }"
    }
}
