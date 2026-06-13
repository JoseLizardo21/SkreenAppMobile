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
    @Volatile private var codecConfigured = false

    private val surfaceTexture = textureEntry.surfaceTexture().also {
        it.setDefaultBufferSize(1920, 1080)
    }
    private val surface = Surface(surfaceTexture)

    fun start() {
        running = true
        codecConfigured = false
        outputThread = Thread { runOutputLoop() }.also { it.start() }
        inputThread  = Thread { runInputLoop()  }.also { it.start() }
    }

    private fun createDecoder(): MediaCodec {
        val hw = MediaCodec.createDecoderByType(MediaFormat.MIMETYPE_VIDEO_AVC)
        if (!hw.name.contains("allwinner", ignoreCase = true)) return hw
        hw.release()
        android.util.Log.w("MediaCodecDecoder", "Allwinner HW decoder — usando software")
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
                if (len <= 0 || len > 8_000_000) break
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
            val codec = this.codec ?: run {
                try { Thread.sleep(10) } catch (_: InterruptedException) { return }
                null
            } ?: continue
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
                            android.util.Log.i("MediaCodecDecoder", "Output format: ${w}x${h}")
                            // Actualiza el buffer del surface con la resolución real
                            surfaceTexture.setDefaultBufferSize(w, h)
                            onVideoSizeChanged?.invoke(w, h)
                        }
                    }
                }
            } catch (_: IllegalStateException) {
                onError?.invoke(); break
            } catch (_: InterruptedException) {
                break
            } catch (_: Exception) {}
        }
    }

    private fun feedInputBuffer(data: ByteArray) {
        if (!codecConfigured) {
            val (sps, pps) = extractSPSPPS(data)
            if (sps == null || pps == null) return

            val (width, height) = parseSPSDimensions(sps) ?: Pair(1920, 1080)
            surfaceTexture.setDefaultBufferSize(width, height)

            val format = MediaFormat.createVideoFormat(MediaFormat.MIMETYPE_VIDEO_AVC, width, height)
            format.setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, 8 * 1024 * 1024)
            format.setByteBuffer("csd-0", java.nio.ByteBuffer.wrap(sps))
            format.setByteBuffer("csd-1", java.nio.ByteBuffer.wrap(pps))

            val decoder = createDecoder()
            decoder.configure(format, surface, null, 0)
            decoder.start()
            codec = decoder
            codecConfigured = true
            android.util.Log.i("MediaCodecDecoder", "Decoder configurado con SPS/PPS (${width}x${height})")
            onVideoSizeChanged?.invoke(width, height)
            // Fall through: this frame likely contains the IDR, don't discard it
        }

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

    // Annex-B start codes can be 3 bytes (00 00 01) or 4 bytes (00 00 00 01);
    // encoders commonly mix both within the same access unit.
    private fun startCodeLength(data: ByteArray, i: Int): Int {
        if (i + 3 < data.size && data[i] == 0.toByte() && data[i+1] == 0.toByte() &&
            data[i+2] == 0.toByte() && data[i+3] == 1.toByte()) return 4
        if (i + 2 < data.size && data[i] == 0.toByte() && data[i+1] == 0.toByte() &&
            data[i+2] == 1.toByte()) return 3
        return 0
    }

    private fun extractSPSPPS(data: ByteArray): Pair<ByteArray?, ByteArray?> {
        var sps: ByteArray? = null
        var pps: ByteArray? = null
        var i = 0
        while (i < data.size - 3) {
            val scLen = startCodeLength(data, i)
            if (scLen > 0) {
                val nalStart = i + scLen
                if (nalStart >= data.size) break
                val nalType = data[nalStart].toInt() and 0x1F
                var j = nalStart + 1
                while (j < data.size - 3 && startCodeLength(data, j) == 0) j++
                val nalEnd = if (j < data.size - 3) j else data.size
                when (nalType) {
                    7 -> sps = data.copyOfRange(i, nalEnd)
                    8 -> pps = data.copyOfRange(i, nalEnd)
                }
                i = nalEnd
            } else i++
            if (sps != null && pps != null) break
        }
        return Pair(sps, pps)
    }

    // Minimal bitstream reader for H.264 exp-golomb fields (ue(v)/se(v)).
    private class BitReader(private val data: ByteArray) {
        private var bitPos = 0

        fun readBit(): Int {
            val bytePos = bitPos / 8
            if (bytePos >= data.size) throw IndexOutOfBoundsException("SPS bit reader overrun")
            val bit = 7 - (bitPos % 8)
            bitPos++
            return (data[bytePos].toInt() shr bit) and 1
        }

        fun readBits(n: Int): Int {
            var value = 0
            repeat(n) { value = (value shl 1) or readBit() }
            return value
        }

        fun readUE(): Int {
            var zeros = 0
            while (readBit() == 0) zeros++
            var value = 0
            repeat(zeros) { value = (value shl 1) or readBit() }
            return (1 shl zeros) - 1 + value
        }

        fun readSE(): Int {
            val k = readUE()
            return if (k % 2 == 0) -(k / 2) else (k + 1) / 2
        }
    }

    private fun skipScalingList(br: BitReader, size: Int) {
        var lastScale = 8
        var nextScale = 8
        repeat(size) {
            if (nextScale != 0) {
                val deltaScale = br.readSE()
                nextScale = (lastScale + deltaScale + 256) % 256
            }
            if (nextScale != 0) lastScale = nextScale
        }
    }

    // Parses width/height (post-cropping) out of a raw SPS NAL (start code + header + RBSP).
    private fun parseSPSDimensions(spsNal: ByteArray): Pair<Int, Int>? {
        return try {
            val scLen = startCodeLength(spsNal, 0)
            if (scLen == 0) return null
            val offset = scLen + 1 // skip start code + NAL header byte
            if (offset >= spsNal.size) return null

            // Strip emulation prevention bytes (00 00 03 -> 00 00).
            val rbsp = java.io.ByteArrayOutputStream(spsNal.size - offset)
            var i = offset
            while (i < spsNal.size) {
                if (i + 2 < spsNal.size && spsNal[i] == 0.toByte() && spsNal[i + 1] == 0.toByte() && spsNal[i + 2] == 3.toByte()) {
                    rbsp.write(0); rbsp.write(0)
                    i += 3
                } else {
                    rbsp.write(spsNal[i].toInt())
                    i++
                }
            }

            val br = BitReader(rbsp.toByteArray())
            val profileIdc = br.readBits(8)
            br.readBits(8) // constraint flags + reserved
            br.readBits(8) // level_idc
            br.readUE() // seq_parameter_set_id

            var chromaFormatIdc = 1
            if (profileIdc in intArrayOf(100, 110, 122, 244, 44, 83, 86, 118, 128, 138, 139, 134, 135)) {
                chromaFormatIdc = br.readUE()
                if (chromaFormatIdc == 3) br.readBit() // separate_colour_plane_flag
                br.readUE() // bit_depth_luma_minus8
                br.readUE() // bit_depth_chroma_minus8
                br.readBit() // qpprime_y_zero_transform_bypass_flag
                if (br.readBit() == 1) { // seq_scaling_matrix_present_flag
                    val count = if (chromaFormatIdc != 3) 8 else 12
                    repeat(count) { idx ->
                        if (br.readBit() == 1) skipScalingList(br, if (idx < 6) 16 else 64)
                    }
                }
            }

            br.readUE() // log2_max_frame_num_minus4
            val picOrderCntType = br.readUE()
            if (picOrderCntType == 0) {
                br.readUE() // log2_max_pic_order_cnt_lsb_minus4
            } else if (picOrderCntType == 1) {
                br.readBit() // delta_pic_order_always_zero_flag
                br.readSE() // offset_for_non_ref_pic
                br.readSE() // offset_for_top_to_bottom_field
                repeat(br.readUE()) { br.readSE() } // offset_for_ref_frame[i]
            }
            br.readUE() // max_num_ref_frames
            br.readBit() // gaps_in_frame_num_value_allowed_flag
            val picWidthInMbsMinus1 = br.readUE()
            val picHeightInMapUnitsMinus1 = br.readUE()
            val frameMbsOnlyFlag = br.readBit()
            if (frameMbsOnlyFlag == 0) br.readBit() // mb_adaptive_frame_field_flag
            br.readBit() // direct_8x8_inference_flag

            var cropLeft = 0; var cropRight = 0; var cropTop = 0; var cropBottom = 0
            if (br.readBit() == 1) { // frame_cropping_flag
                cropLeft = br.readUE()
                cropRight = br.readUE()
                cropTop = br.readUE()
                cropBottom = br.readUE()
            }

            val width = (picWidthInMbsMinus1 + 1) * 16
            val height = (2 - frameMbsOnlyFlag) * (picHeightInMapUnitsMinus1 + 1) * 16

            val subWidthC = if (chromaFormatIdc == 1 || chromaFormatIdc == 2) 2 else 1
            val subHeightC = if (chromaFormatIdc == 1) 2 else 1
            val cropUnitX = if (chromaFormatIdc == 0) 1 else subWidthC
            val cropUnitY = if (chromaFormatIdc == 0) (2 - frameMbsOnlyFlag) else subHeightC * (2 - frameMbsOnlyFlag)

            val finalWidth = width - (cropLeft + cropRight) * cropUnitX
            val finalHeight = height - (cropTop + cropBottom) * cropUnitY

            if (finalWidth <= 0 || finalHeight <= 0) null else Pair(finalWidth, finalHeight)
        } catch (_: Exception) {
            null
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
        codecConfigured = false
        inputThread?.interrupt()
        outputThread?.interrupt()
        socket?.close()
        inputThread?.join(500)
        outputThread?.join(500)
        try { codec?.reset() }   catch (_: Exception) {}
        try { codec?.release() } catch (_: Exception) {}
        try { surface.release() } catch (_: Exception) {}
        textureEntry.release()
        codec = null
    }
}