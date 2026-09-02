package com.skreenapp.app

import android.net.wifi.WifiManager
import android.os.Build
import android.util.DisplayMetrics
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val SCREEN_CHANNEL = "com.yourapp/screen_info"
    private val WIFI_LOCK_CHANNEL = "com.skreenapp.app/wifi_lock"

    // Sin este lock, el radio WiFi entra en modo de ahorro de energía entre
    // beacons cuando la pantalla no tiene foco de touch, introduciendo cortes
    // periódicos en el streaming aunque la señal sea excelente.
    private var wifiLock: WifiManager.WifiLock? = null

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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WIFI_LOCK_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "acquire" -> {
                        try {
                            acquireWifiLock()
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("ERROR", "Failed to acquire WiFi lock: ${e.message}", null)
                        }
                    }
                    "release" -> {
                        releaseWifiLock()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun acquireWifiLock() {
        if (wifiLock?.isHeld == true) return
        val wifiManager = applicationContext.getSystemService(WIFI_SERVICE) as WifiManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q)
            WifiManager.WIFI_MODE_FULL_LOW_LATENCY
        else
            @Suppress("DEPRECATION") WifiManager.WIFI_MODE_FULL_HIGH_PERF
        wifiLock = wifiManager.createWifiLock(mode, "com.skreenapp.app:streamingWifiLock")
        wifiLock?.setReferenceCounted(false)
        wifiLock?.acquire()
    }

    private fun releaseWifiLock() {
        if (wifiLock?.isHeld == true) wifiLock?.release()
        wifiLock = null
    }

    override fun onDestroy() {
        releaseWifiLock()
        super.onDestroy()
    }
}
