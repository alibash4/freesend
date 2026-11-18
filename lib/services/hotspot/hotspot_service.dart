import 'dart:io';

import 'package:flutter/services.dart';
import 'package:free_send/core/platform_env.dart';

/// Result of bringing a hotspot up or joining one.
class HotspotInfo {
  const HotspotInfo({
    required this.ssid,
    this.password,
    this.ip,
    this.created = false,
    this.note,
  });

  final String ssid;
  final String? password;

  /// Address of the host on the hotspot link, when known.
  final String? ip;

  /// True when this app actually created the hotspot.
  final bool created;

  /// Human-readable guidance when the OS needs the user to act.
  final String? note;

  bool get hasCredentials => password != null && password!.isNotEmpty;
}

class HotspotException implements Exception {
  HotspotException(this.message, {this.manual = false});
  final String message;

  /// True when the user has to perform the step in system settings.
  final bool manual;

  @override
  String toString() => message;
}

abstract class HotspotService {
  /// Whether this app can create a hotspot itself.
  bool get canCreate;

  /// Whether this app can join a hotspot with SSID + password.
  bool get canJoin;

  /// Nearby network names worth offering as the other side's hotspot.
  ///
  /// Only Linux can enumerate; every other platform answers empty and the UI
  /// falls back to the manual code path.
  Future<List<String>> survey();

  Future<HotspotInfo> start({required String deviceName});
  Future<void> stop();

  Future<HotspotInfo> join(String ssid, String? password);
  Future<void> leave();

  Future<void> dispose();
}

HotspotService createHotspotService() {
  if (Platform.isAndroid) return AndroidHotspotService();
  if (Platform.isLinux) return LinuxHotspotService();
  return ManualHotspotService();
}

/// Desktop platforms without scriptable hotspot hosting: the session runs over
/// whatever network the device is already on, and the UI tells the user how to
/// turn on an OS-level hotspot if they want to be the host.
class ManualHotspotService implements HotspotService {
  @override
  bool get canCreate => false;

  @override
  bool get canJoin => Platform.isMacOS;

  @override
  Future<HotspotInfo> start({required String deviceName}) async {
    final ip = await localIpv4();
    return HotspotInfo(
      ssid: deviceName,
      ip: ip,
      created: false,
      note: Platform.isWindows
          ? 'Sharing over your current network. For the fastest link, turn on '
              'Mobile hotspot in Windows Settings, then connect the other '
              'device to it.'
          : 'Sharing over your current network. For the fastest link, turn on '
              'Internet Sharing in System Settings under General, then connect '
              'the other device to it.',
    );
  }

  @override
  Future<List<String>> survey() async => const [];

  @override
  Future<void> stop() async {}

  @override
  Future<HotspotInfo> join(String ssid, String? password) async {
    if (!Platform.isMacOS) {
      throw HotspotException(
        'Join the hotspot "$ssid" from your system Wi-Fi menu, then come back here.',
        manual: true,
      );
    }
    final iface = await _wifiInterface();
    if (iface == null) {
      throw HotspotException('No Wi-Fi interface found.', manual: true);
    }
    final args = <String>['-setairportnetwork', iface, ssid];
    if (password != null && password.isNotEmpty) args.add(password);
    final result = await _run(['networksetup', ...args]);
    if (result.$1 != 0) {
      throw HotspotException(
        'Could not join "$ssid": ${result.$2}'.trim(),
        manual: true,
      );
    }
    return HotspotInfo(ssid: ssid, ip: await localIpv4());
  }

  @override
  Future<void> leave() async {}

  @override
  Future<void> dispose() async {}

  Future<String?> _wifiInterface() async {
    final result = await _run(['networksetup', '-listallhardwareports']);
    if (result.$1 != 0) return null;
    final lines = result.$2.split('\n');
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].toLowerCase().contains('wi-fi') && i + 1 < lines.length) {
        final match = RegExp(r'Device:\s*(\S+)').firstMatch(lines[i + 1]);
        if (match != null) return match.group(1);
      }
    }
    return null;
  }
}

Future<(int, String)> _run(List<String> command, {Duration? timeout}) async {
  try {
    final result = await Process.run(
      command.first,
      command.sublist(1),
      runInShell: false,
    ).timeout(timeout ?? const Duration(seconds: 25));
    final output = '${result.stdout}${result.stderr}'.trim();
    return (result.exitCode, output);
  } on Object catch (error) {
    return (1, '$error');
  }
}

/// NetworkManager based hotspot for Linux. Uses the first Wi-Fi interface.
class LinuxHotspotService implements HotspotService {
  String? _connectionName;
  String? _iface;

  @override
  bool get canCreate => true;

  @override
  bool get canJoin => true;

  @override
  Future<HotspotInfo> start({required String deviceName}) async {
    final iface = _iface ??= await _firstWifiInterface();
    if (iface == null) {
      throw HotspotException(
        'No Wi-Fi adapter found. Connect to the other device\'s hotspot instead.',
      );
    }
    final ssid = _makeSsid(deviceName);
    final password = _makePassword();
    _connectionName = ssid;
    final result = await _run([
      'nmcli',
      'device',
      'wifi',
      'hotspot',
      'ifname',
      iface,
      'ssid',
      ssid,
      'password',
      password,
    ], timeout: const Duration(seconds: 40));
    if (result.$1 != 0) {
      throw HotspotException('Could not start the hotspot: ${result.$2}');
    }
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    final ip = await _addressFor(iface);
    return HotspotInfo(
      ssid: ssid,
      password: password,
      ip: ip ?? await localIpv4(),
      created: true,
    );
  }

  @override
  Future<void> stop() async {
    final name = _connectionName;
    if (name == null) return;
    await _run(['nmcli', 'connection', 'down', name]);
    await _run(['nmcli', 'connection', 'delete', name]);
    _connectionName = null;
  }

  @override
  Future<HotspotInfo> join(String ssid, String? password) async {
    final args = ['nmcli', 'device', 'wifi', 'connect', ssid];
    if (password != null && password.isNotEmpty) {
      args.addAll(['password', password]);
    }
    final result = await _run(args, timeout: const Duration(seconds: 35));
    if (result.$1 != 0) {
      throw HotspotException('Could not join "$ssid": ${result.$2}');
    }
    await Future<void>.delayed(const Duration(milliseconds: 900));
    return HotspotInfo(ssid: ssid, ip: await localIpv4());
  }

  @override
  Future<List<String>> survey() async {
    // Phone hotspots carry the vendor prefix, so those are what we offer; a
    // FreeSend-named network is ours from a Linux host.
    const markers = ['AndroidShare', 'FreeSend-', 'AndroidAP', 'Direct-'];
    final result = await _run([
      'nmcli',
      '-t',
      '-f',
      'SSID',
      'device',
      'wifi',
      'list',
    ], timeout: const Duration(seconds: 12));
    if (result.$1 != 0) return const [];
    final matches = <String>[];
    for (final line in result.$2.split('\n')) {
      final ssid = line.trim();
      if (ssid.isEmpty || matches.contains(ssid)) continue;
      if (markers.any(ssid.contains)) matches.add(ssid);
    }
    return matches;
  }

  @override
  Future<void> leave() async {
    final iface = _iface ?? await _firstWifiInterface();
    if (iface == null) return;
    await _run(['nmcli', 'device', 'disconnect', iface]);
  }

  @override
  Future<void> dispose() async {
    await stop();
  }

  Future<String?> _firstWifiInterface() async {
    final result = await _run(['nmcli', '-t', '-f', 'DEVICE,TYPE', 'device']);
    if (result.$1 != 0) return null;
    for (final line in result.$2.split('\n')) {
      final parts = line.split(':');
      if (parts.length >= 2 && parts[1].trim() == 'wifi') {
        return parts.first.trim();
      }
    }
    return null;
  }

  Future<String?> _addressFor(String iface) async {
    final result = await _run([
      'nmcli',
      '-t',
      '-f',
      'IP4.ADDRESS',
      'device',
      'show',
      iface,
    ]);
    if (result.$1 != 0) return null;
    for (final line in result.$2.split('\n')) {
      final value = line.contains(':') ? line.split(':').last : line;
      final ip = value.split('/').first.trim();
      if (InternetAddress.tryParse(ip) != null) return ip;
    }
    return null;
  }

  String _makeSsid(String deviceName) {
    final base = deviceName.replaceAll(RegExp(r'[^A-Za-z0-9 _-]'), '').trim();
    final name = base.isEmpty ? 'FreeSend' : base;
    final short =
        name.replaceAll(' ', '-').substring(0, name.length > 14 ? 14 : name.length);
    // The suffix keeps two nearby devices with the same name apart, and gives
    // the other side something stable to filter on.
    return 'FreeSend-$short-${_hotspotSuffix(name)}';
  }

  /// Stable 4-hex tag derived from the device name (FNV-1a, lower 16 bits).
  String _hotspotSuffix(String seed) {
    var hash = 0x811c9dc5;
    for (final unit in seed.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return (hash & 0xFFFF).toRadixString(16).padLeft(4, '0').toUpperCase();
  }

  String _makePassword() {
    const alphabet = 'abcdefghijkmnpqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = DateTime.now().microsecondsSinceEpoch;
    final seed = '$random${DateTime.now().hashCode}';
    final buffer = StringBuffer();
    for (var i = 0; i < 12; i++) {
      buffer.write(alphabet[(seed.codeUnitAt(i % seed.length) + i * 7) % alphabet.length]);
    }
    return buffer.toString();
  }
}

/// Android bridge to `LocalOnlyHotspot` (host) and `WifiNetworkSpecifier`
/// (client). See `android/app/src/main/kotlin/.../HotspotBridge.kt`.
class AndroidHotspotService implements HotspotService {
  static const _channel = MethodChannel('com.freesend.free_send/hotspot');

  @override
  bool get canCreate => true;

  @override
  bool get canJoin => true;

  @override
  Future<HotspotInfo> start({required String deviceName}) async {
    try {
      final result = await _channel.invokeMapMethod<String, Object?>('start', {
        'name': deviceName,
      });
      if (result == null) {
        throw HotspotException('The system did not return hotspot details.');
      }
      return HotspotInfo(
        ssid: (result['ssid'] as String?) ?? 'FreeSend',
        password: result['password'] as String?,
        ip: result['ip'] as String?,
        created: true,
        note: result['note'] as String?,
      );
    } on PlatformException catch (error) {
      throw HotspotException(
        error.message ?? 'Could not start the hotspot.',
        manual: true,
      );
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _channel.invokeMethod<void>('stop');
    } on PlatformException {
      // Nothing else to do: the reservation is gone either way.
    }
  }

  @override
  Future<HotspotInfo> join(String ssid, String? password) async {
    try {
      final result = await _channel.invokeMapMethod<String, Object?>('join', {
        'ssid': ssid,
        'password': password,
      });
      return HotspotInfo(
        ssid: ssid,
        ip: result?['ip'] as String?,
        note: result?['note'] as String?,
      );
    } on PlatformException catch (error) {
      throw HotspotException(
        error.message ?? 'Could not join "$ssid".',
        manual: true,
      );
    }
  }

  @override
  Future<void> leave() async {
    try {
      await _channel.invokeMethod<void>('leave');
    } on PlatformException {
      // Ignore.
    }
  }

  @override
  Future<List<String>> survey() async => const [];

  @override
  Future<void> dispose() async {
    await leave();
    await stop();
  }
}
