import 'package:flutter/services.dart';

/// Keeps the WiFi radio out of power-save mode while streaming: without
/// this, Android sleeps the WiFi chip between beacons, which shows up as
/// periodic micro-stutters in the video even with good signal.
/// Only applies to WiFi mode (over cable the video doesn't use the WiFi radio).
class WifiLockHelper {
  static const _platform = MethodChannel('com.skreenapp.app/wifi_lock');

  static Future<void> acquire() async {
    try {
      await _platform.invokeMethod('acquire');
    } on PlatformException catch (_) {
      // Not critical: if it fails, streaming still works, there may just
      // be more stutters than expected.
    }
  }

  static Future<void> release() async {
    try {
      await _platform.invokeMethod('release');
    } on PlatformException catch (_) {}
  }
}
