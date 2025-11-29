package com.example.skreen_app_mobile

import android.util.DisplayMetrics
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.yourapp/screen_info"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getScreenResolution") {
                try {
                    val metrics = DisplayMetrics()
                    val windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
                    
                    // getRealMetrics incluye las barras del sistema
                    windowManager.defaultDisplay.getRealMetrics(metrics)
                    
                    val screenInfo = hashMapOf(
                        "width" to metrics.widthPixels,
                        "height" to metrics.heightPixels
                    )
                    result.success(screenInfo)
                } catch (e: Exception) {
                    result.error("ERROR", "Failed to get screen resolution: ${e.message}", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }
}