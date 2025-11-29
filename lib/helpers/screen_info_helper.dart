import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;

class ScreenInfoHelper {
  static const platform = MethodChannel('com.yourapp/screen_info');

  static Future<Map<String, int>> getRealScreenResolution() async {
    try {
      final Map<dynamic, dynamic> result = await platform.invokeMethod('getScreenResolution');
      return {
        'width': result['width'] as int,
        'height': result['height'] as int,
      };
    } on PlatformException catch (e) {
      print("Error obteniendo resolución: ${e.message}");
      // Fallback a physicalSize
      final ui.FlutterView view = WidgetsBinding.instance.platformDispatcher.views.first;
      final ui.Size physicalSize = view.physicalSize;
      return {
        'width': physicalSize.width.toInt(),
        'height': physicalSize.height.toInt(),
      };
    }
  }
}