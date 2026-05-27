package com.example.skreen_app_mobile

import android.media.MediaCodec
import android.media.MediaFormat
import android.view.Surface
import io.flutter.view.TextureRegistry
import java.io.InputStream
import java.net.Socket

class MediaCodecDecoder(private val textureEntry: TextureRegistry.SurfaceTextureEntry) {

    var onVideoSizeChanged: ((Int, Int) -> Unit)? = null
    var onError: (() -> Unit)? = null

    private var codec: MediaCodec? = null
    private var socket: Socket? = null
    private var inputThread: Thread? = null
    private var outputThread: Thread? = null
    @Volatile private var running = false
    private val surface = Surface(textureEntry.surfaceTexture().also {
        it.setDefaultBufferSize(1920, 1080)
    })

    fun start() {
        val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, 1920, 1080)
        format.setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 4 * 1024 * 1024)

        val decoder = createDecoder()
        codec = decoder
        decoder.configure(format, surface, null, 0)
        decoder.start()

        running = true
        outputThread = Thread { runOutputLoop() }.also { it.start() }
        inputThread = Thread { runInputLoop() }.also { it.start() }
    }

    // El decoder Allwinner (c2.allwinner.avc.decoder) crashea en 1920x1080 con
    // "previous call to queue exceeded timeout". Usar software como fallback.
    private fun createDecoder(): MediaCodec {
        val hw = MediaCodec.createDecoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
        if (!hw.name.contains("allwinner", ignoreCase = true)) return hw
        hw.release()
        android.util.Log.w("MediaCodecDecoder", "Allwinner HW decoder detectado — usando software")
        for (name in listOf("c2.android.avc.decoder", "OMX.google.h264.decoder")) {
            try { return MediaCodec.createByCodecName(name) } catch (_: Exception) {}
        }
        return MediaCodec.createDecoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
    }

    private fun runInputLoop() {
        try {
            val sock = Socket("127.0.0.1", 9002)
            socket = sock
            val input = sock.getInputStream()
            val lenBuf = ByteArray(4)

            while (running && !Thread.currentThread().isInterrupted) {
                if (!readFully(input, lenBuf, 4)) break
                val len = ((lenBuf[0].toInt() and 0xFF) shl 24) or
                          ((lenBuf[1].toInt() and 0xFF) shl 16) or
                          ((lenBuf[2].toInt() and 0xFF) shl 8)  or
                           (lenBuf[3].toInt() and 0xFF)

                if (len <= 0 || len > 4_000_000) break

                val data = ByteArray(len)
                if (!readFully(input, data, len)) break

                feedInputBuffer(data)
            }
        } catch (_: Exception) {
        } finally {
            socket?.close()
        }
    }

    private fun runOutputLoop() {
        val info = MediaCodec.BufferInfo()
        while (running && !Thread.currentThread().isInterrupted) {
            val codec = this.codec ?: break
            try {
                val outputIdx = codec.dequeueOutputBuffer(info, 5_000)
                when {
                    outputIdx >= 0 -> codec.releaseOutputBuffer(outputIdx, true)
                    outputIdx == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                        val newFormat = codec.outputFormat
                        if (newFormat.containsKey(MediaFormat.KEY_WIDTH) &&
                            newFormat.containsKey(MediaFormat.KEY_HEIGHT)) {
                            val w = newFormat.getInteger(MediaFormat.KEY_WIDTH)
                            val h = newFormat.getInteger(MediaFormat.KEY_HEIGHT)
                            android.util.Log.i("MediaCodecDecoder", "Output format changed: ${w}x${h}")
                            onVideoSizeChanged?.invoke(w, h)
                        }
                    }
                }
            } catch (_: IllegalStateException) {
                // El codec entró en estado de error (hardware crash); notificar al app.
                onError?.invoke()
                break
            } catch (_: Exception) {}
        }
    }

    private fun feedInputBuffer(data: ByteArray) {
        val codec = this.codec ?: return
        var inputIdx = -1
        val deadline = System.nanoTime() + 20_000_000L
        while (inputIdx < 0 && System.nanoTime() < deadline && running) {
            inputIdx = codec.dequeueInputBuffer(10_000)
        }
        if (inputIdx >= 0) {
            val buf = codec.getInputBuffer(inputIdx)!!
            buf.clear()
            buf.put(data)
            codec.queueInputBuffer(inputIdx, 0, data.size, System.nanoTime() / 1000, 0)
        }
    }

    private fun readFully(input: InputStream, buf: ByteArray, len: Int): Boolean {
        var off = 0
        while (off < len) {
            val n = input.read(buf, off, len - off)
            if (n <= 0) return false
            off += n
        }
        return true
    }

    fun stop() {
        running = false
        inputThread?.interrupt()
        outputThread?.interrupt()
        socket?.close()
        inputThread?.join(500)
        outputThread?.join(500)
        try { codec?.reset() } catch (_: Exception) {}
        try { codec?.release() } catch (_: Exception) {}
        try { surface.release() } catch (_: Exception) {}
        textureEntry.release()
        codec = null
    }
}
