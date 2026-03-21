package com.example.skreen_app_mobile

import android.util.DisplayMetrics
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val SCREEN_CHANNEL = "com.yourapp/screen_info"
    private val DECODER_CHANNEL = "skreen/decoder"

    private var decoder: MediaCodecDecoder? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Canal existente: información de pantalla
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

        // Canal nuevo: decoder nativo H.264 via MediaCodec
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DECODER_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        try {
                            val textureEntry = flutterEngine.renderer.createSurfaceTexture()
                            decoder = MediaCodecDecoder(textureEntry)
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
