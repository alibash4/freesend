import 'dart:io';

import 'package:flutter/services.dart';

/// Native facts about the device's connectivity that a transfer depends on.
///
/// Every probe is best-effort: if the channel cannot answer, the caller treats
/// the feature as fine rather than blocking a transfer.
abstract final class NetworkProbe {
  static const MethodChannel _channel = MethodChannel('free_send/network');

  /// A VPN routes around the local link, hiding both devices from each other.
  static Future<bool> get vpnIsOn async => _read('isVpnActive');

  /// Android 10+ refuses to run a local-only hotspot with location off.
  static Future<bool> get locationIsOn => _read('isLocationEnabled');

  /// The Wi-Fi radio itself: the hotspot a phone creates and the shared
  /// network a desktop joins both need it on.
  static Future<bool> get wifiIsOn => _read('isWifiEnabled');

  static Future<bool> _read(String method) async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    try {
      return await _channel.invokeMethod<bool>(method) ?? false;
    } on Object {
      return false;
    }
  }
}
