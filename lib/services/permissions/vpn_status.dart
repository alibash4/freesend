import 'dart:io';

import 'package:flutter/services.dart';

/// Whether a VPN owns any network interface right now.
abstract final class VpnStatus {
  static const MethodChannel _channel = MethodChannel('free_send/network');

  /// Never throws: a probe that cannot answer must not block a transfer.
  static Future<bool> get isOn async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    try {
      return await _channel.invokeMethod<bool>('isVpnActive') ?? false;
    } on Object {
      return false;
    }
  }
}
