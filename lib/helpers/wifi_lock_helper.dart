import 'package:flutter/services.dart';

/// Mantiene el radio WiFi fuera de modo de ahorro de energía mientras se
/// transmite: sin esto, Android duerme el chip WiFi entre beacons, lo que
/// se ve como micro-cortes periódicos en el video incluso con buena señal.
/// Solo aplica al modo WiFi (en cable el video no viaja por el radio WiFi).
class WifiLockHelper {
  static const _platform = MethodChannel('com.skreenapp.app/wifi_lock');

  static Future<void> acquire() async {
    try {
      await _platform.invokeMethod('acquire');
    } on PlatformException catch (_) {
      // No crítico: si falla, el streaming sigue funcionando, solo puede
      // haber más cortes de los esperados.
    }
  }

  static Future<void> release() async {
    try {
      await _platform.invokeMethod('release');
    } on PlatformException catch (_) {}
  }
}
