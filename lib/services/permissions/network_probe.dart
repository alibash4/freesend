import 'dart:io';

import 'package:flutter/services.dart';

/// Native facts about the device's connectivity that a transfer depends on.
///
/// Every probe is best-effort: if the channel cannot answer, the caller treats
/// the feature as fine rather than blocking a transfer.
abstract final class NetworkProbe {
  static const MethodChannel _channel = MethodChannel('free_send/network');

  /// A VPN routes around the local link, hiding both devices from each other.
  ///
  /// Android asks the operating system; desktops are inspected locally because
  /// the app has no platform channel there.
  static Future<bool> get vpnIsOn async {
    if (Platform.isAndroid || Platform.isIOS) return _read('isVpnActive');
    try {
      if (Platform.isLinux || Platform.isMacOS) {
        return await _tunnelInterfaceOn();
      }
      if (Platform.isWindows) return await _windowsVpnOn();
    } on Object {
      // Detection must never block or break a transfer.
    }
    return false;
  }

  /// Android 10+ refuses to run a local-only hotspot with location off.
  static Future<bool> get locationIsOn => _read('isLocationEnabled');

  /// The Wi-Fi radio itself: the hotspot a phone creates and the shared
  /// network a desktop joins both need it on.
  static Future<bool> get wifiIsOn => _read('isWifiEnabled');

  /// Opens the system settings page that owns [target] (`wifi`, `vpn` or
  /// `location`) so the user can flip the switch a checklist row waits on.
  /// Android only; a no-op elsewhere.
  static Future<void> openSystemSettings(String target) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod<void>('openSettings', {'target': target});
    } on Object {
      // Settings must never break the checklist.
    }
  }

  static Future<bool> _read(String method) async {
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    try {
      return await _channel.invokeMethod<bool>(method) ?? false;
    } on Object {
      return false;
    }
  }

  /// `tun`/`tap`/`wg`/`ppp` interfaces mean a tunnel client is attached.
  /// Not perfect - some clients use their own names - but cheap, and it catches
  /// WireGuard, OpenVPN and the usual macOS tunnels.
  static Future<bool> _tunnelInterfaceOn() async {
    final interfaces = await NetworkInterface.list();
    final tunnel = RegExp(r'^(tun|tap|wg|ppp|ipsec|utun)');
    return interfaces.any(
      (interface) => tunnel.hasMatch(interface.name.toLowerCase()),
    );
  }

  static Future<bool> _windowsVpnOn() async {
    final result = await Process.run(
      'powershell',
      [
        '-NoProfile',
        '-Command',
        r'Get-NetAdapter | Where-Object { '
            r'$_.InterfaceDescription -match '
            r'"TAP|TUN|WireGuard|OpenVPN|Cisco|AnyConnect|Fortinet|PPP" } | '
            r'Select-Object -First 1 -ExpandProperty Name',
      ],
    ).timeout(const Duration(seconds: 8));
    return (result.stdout as String).trim().isNotEmpty;
  }
}
