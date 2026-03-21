package com.example.skreen_app_mobile

import android.media.MediaCodec
import android.media.MediaFormat
import android.view.Surface
import io.flutter.view.TextureRegistry
import java.io.InputStream
import java.net.Socket

class MediaCodecDecoder(private val textureEntry: TextureRegistry.SurfaceTextureEntry) {

    private var codec: MediaCodec? = null
    private var socket: Socket? = null
    private var thread: Thread? = null
    private val surface = Surface(textureEntry.surfaceTexture())

    fun start() {
        val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, 1280, 720)
        format.setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 1024 * 1024)

        val decoder = MediaCodec.createDecoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
        codec = decoder
        decoder.configure(format, surface, null, 0)
        decoder.start()

        thread = Thread { runDecodeLoop() }
        thread?.start()
    }

    private fun runDecodeLoop() {
        try {
            val sock = Socket("127.0.0.1", 9002)
            socket = sock
            val input = sock.getInputStream()
            val lenBuf = ByteArray(4)

            while (!Thread.currentThread().isInterrupted) {
                // Leer prefijo de 4 bytes con el tamaño del frame
                if (!readFully(input, lenBuf, 4)) break
                val len = ((lenBuf[0].toInt() and 0xFF) shl 24) or
                          ((lenBuf[1].toInt() and 0xFF) shl 16) or
                          ((lenBuf[2].toInt() and 0xFF) shl 8)  or
                           (lenBuf[3].toInt() and 0xFF)

                if (len <= 0 || len > 4_000_000) break

                val data = ByteArray(len)
                if (!readFully(input, data, len)) break

                feedToCodec(data)
            }
        } catch (_: Exception) {
            // conexión cerrada o interrumpida
        } finally {
            socket?.close()
        }
    }

    private fun feedToCodec(data: ByteArray) {
        val codec = this.codec ?: return

        val inputIdx = codec.dequeueInputBuffer(10_000)
        if (inputIdx >= 0) {
            val buf = codec.getInputBuffer(inputIdx)!!
            buf.clear()
            buf.put(data)
            codec.queueInputBuffer(inputIdx, 0, data.size, System.nanoTime() / 1000, 0)
        }

        // Renderizar todos los frames disponibles
        val info = MediaCodec.BufferInfo()
        var outputIdx = codec.dequeueOutputBuffer(info, 0)
        while (outputIdx >= 0) {
            codec.releaseOutputBuffer(outputIdx, true) // true = render al Surface
            outputIdx = codec.dequeueOutputBuffer(info, 0)
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
        thread?.interrupt()
        socket?.close()
        codec?.stop()
        codec?.release()
        surface.release()
        textureEntry.release()
        codec = null
    }
}
