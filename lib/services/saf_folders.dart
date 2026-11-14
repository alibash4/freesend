import 'dart:io';

import 'package:flutter/services.dart';

/// Copies an Android Storage Access Framework folder into the app cache so the
/// rest of the app can read it with ordinary Dart file APIs.
abstract final class SafFolders {
  static const MethodChannel _channel =
      MethodChannel('com.freesend.free_send/saf');

  static Future<String?> copyTreeToCache(String uri) async {
    if (!Platform.isAndroid) return null;
    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'copyTree',
        {'uri': uri},
      );
      final path = result?['path'];
      return path is String && path.isNotEmpty ? path : null;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}