package com.example.skreen_app_mobile

import android.util.DisplayMetrics
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val SCREEN_CHANNEL = "com.yourapp/screen_info"
    private val DECODER_CHANNEL = "skreen/decoder"
    private val VIDEO_SIZE_CHANNEL = "skreen/video_size"
    private val DECODER_EVENT_CHANNEL = "skreen/decoder_events"

    private var decoder: MediaCodecDecoder? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SCREEN_CHANNEL)
            .setMethodCallHandler { call, result ->
                if (call.method == "getScreenResolution") {
                    try {
                        val metrics = DisplayMetrics()
                        @Suppress("DEPRECATION")
                        (getSystemService(WINDOW_SERVICE) as WindowManager)
                            .defaultDisplay.getRealMetrics(metrics)
                        result.success(
                            hashMapOf("width" to metrics.widthPixels, "height" to metrics.heightPixels)
                        )
                    } catch (e: Exception) {
                        result.error("ERROR", "Failed to get screen resolution: ${e.message}", null)
                    }
                } else {
                    result.notImplemented()
                }
            }

        var videoSizeEventSink: EventChannel.EventSink? = null
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, VIDEO_SIZE_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                    videoSizeEventSink = sink
                    decoder?.onVideoSizeChanged = { w, h -> sink.success(mapOf("width" to w, "height" to h)) }
                }
                override fun onCancel(arguments: Any?) { videoSizeEventSink = null }
            })

        var decoderEventSink: EventChannel.EventSink? = null
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, DECODER_EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                    decoderEventSink = sink
                }
                override fun onCancel(arguments: Any?) { decoderEventSink = null }
            })

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DECODER_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        try {
                            decoder?.stop()
                            decoder = null
                            val textureEntry = flutterEngine.renderer.createSurfaceTexture()
                            decoder = MediaCodecDecoder(textureEntry).also { dec ->
                                videoSizeEventSink?.let { sink ->
                                    dec.onVideoSizeChanged = { w, h -> sink.success(mapOf("width" to w, "height" to h)) }
                                }
                                dec.onError = {
                                    runOnUiThread {
                                        decoder?.stop()
                                        decoder = null
                                        decoderEventSink?.success("error")
                                    }
                                }
                            }
                            decoder!!.start()
                            result.success(textureEntry.id())
                        } catch (e: Exception) {
                            result.error("DECODER_ERROR", e.message, null)
                        }
                    }
                    "stop" -> {
                        decoder?.stop()
                        decoder = null
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
