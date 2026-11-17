import 'dart:ffi';
import 'dart:io';

enum PlatformKind { android, ios, windows, linux, macOS, other }

/// Desktop and mobile capabilities differ mostly around hotspot control.
abstract final class PlatformEnv {
  static PlatformKind get kind {
    if (Platform.isAndroid) return PlatformKind.android;
    if (Platform.isIOS) return PlatformKind.ios;
    if (Platform.isWindows) return PlatformKind.windows;
    if (Platform.isLinux) return PlatformKind.linux;
    if (Platform.isMacOS) return PlatformKind.macOS;
    return PlatformKind.other;
  }

  static String get label => switch (kind) {
        PlatformKind.android => 'Android',
        PlatformKind.ios => 'iOS',
        PlatformKind.windows => 'Windows',
        PlatformKind.linux => 'Linux',
        PlatformKind.macOS => 'macOS',
        PlatformKind.other => Platform.operatingSystem,
      };

  /// Whether the app itself can spin up a hotspot.
  static bool get canCreateHotspot =>
      kind == PlatformKind.android || kind == PlatformKind.linux;

  /// Whether the OS exposes a system tray the app can sit in.
  ///
  /// Windows, KDE and GNOME use a tray; GNOME needs the AppIndicator
  /// extension. macOS uses the Dock instead, so close-to-tray is not a macOS
  /// pattern and the app does not pretend it is one.
  static bool get supportsTray =>
      kind == PlatformKind.windows || kind == PlatformKind.linux;

  /// Whether the app can join a hotspot non-interactively.
  static bool get canJoinHotspot =>
      kind == PlatformKind.android ||
      kind == PlatformKind.linux ||
      kind == PlatformKind.macOS;

  /// Whether the app runs on a desktop platform, where a wired interface is a
  /// plausible transport the user can pick.
  static bool get isDesktop =>
      kind == PlatformKind.windows ||
      kind == PlatformKind.linux ||
      kind == PlatformKind.macOS;

  /// The architecture word release assets are named with: `x86_64` or
  /// `aarch64`.
  ///
  /// Only Linux ships per-architecture builds, so every other platform
  /// returns null and the updater takes the single asset on offer.
  static String? get assetArch {
    if (kind != PlatformKind.linux) return null;
    return switch (Abi.current()) {
      Abi.linuxX64 => 'x86_64',
      Abi.linuxArm64 => 'aarch64',
      Abi.linuxArm => 'armhf',
      _ => null,
    };
  }
}

/// How a session reaches the other device.
enum ShareLink {
  /// The normal path: a hotspot this app creates where the platform allows
  /// one, otherwise whatever network the device is already on.
  wifi,

  /// A cable between the two devices, or the wired LAN. No hotspot is brought
  /// up, and the wired interface's address is the one advertised.
  ethernet,
}

/// The IPv4 address of the wired interface, or null when there is none.
///
/// Link-local counts: two devices on a cable with no DHCP hand out 169.254.x.x
/// to each other, and that is a perfectly good way to reach the peer.
Future<String?> wiredIpv4() async {
  final wired = <_InterfaceAddress>[];
  for (final entry in await _ipv4Interfaces()) {
    if (await _isWiredInterface(entry.name)) wired.add(entry);
  }
  if (wired.isEmpty) return null;
  for (final prefix in const ['192.168.', '10.', '172.']) {
    for (final entry in wired) {
      if (entry.address.startsWith(prefix)) return entry.address;
    }
  }
  return wired.first.address;
}

/// Best-effort primary IPv4 address of a non-loopback interface.
Future<String?> localIpv4() async {
  final candidates = <String>[];
  for (final entry in await _ipv4Interfaces()) {
    if (entry.address.startsWith('169.254.')) continue;
    candidates.add(entry.address);
  }
  if (candidates.isEmpty) return null;
  // Prefer the private ranges a hotspot actually uses.
  for (final prefix in const ['192.168.', '10.', '172.']) {
    for (final ip in candidates) {
      if (ip.startsWith(prefix)) return ip;
    }
  }
  return candidates.first;
}

typedef _InterfaceAddress = ({String name, String address});

Future<List<_InterfaceAddress>> _ipv4Interfaces() async {
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
      includeLinkLocal: true,
    );
    final result = <_InterfaceAddress>[];
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        result.add((name: interface.name, address: address.address));
      }
    }
    return result;
  } on Object {
    return const [];
  }
}

/// Whether [name] is a wired interface.
///
/// Dart does not expose the link type, so this is platform specific: sysfs on
/// Linux, the hardware port list on macOS, and the adapter name elsewhere.
Future<bool> _isWiredInterface(String name) async {
  if (Platform.isLinux) {
    // Linux publishes a wireless interface as a directory in sysfs.
    return !Directory('/sys/class/net/$name/wireless').existsSync();
  }
  if (Platform.isMacOS) {
    final wifi = await _macosWifiDevice();
    return wifi == null || wifi != name;
  }
  if (Platform.isWindows) {
    final lower = name.toLowerCase();
    return !lower.contains('wi-fi') &&
        !lower.contains('wireless') &&
        !lower.contains('wlan');
  }
  return false;
}

Future<String?> _macosWifiDevice() async {
  try {
    final result = await Process.run(
      'networksetup',
      const ['-listallhardwareports'],
      runInShell: false,
    ).timeout(const Duration(seconds: 5));
    if (result.exitCode != 0) return null;
    final lines = '${result.stdout}'.split('\n');
    for (var i = 0; i < lines.length; i++) {
      if (!lines[i].toLowerCase().contains('wi-fi')) continue;
      if (i + 1 >= lines.length) break;
      final match = RegExp(r'Device:\s*(\S+)').firstMatch(lines[i + 1]);
      if (match != null) return match.group(1);
    }
    return null;
  } on Object {
    return null;
  }
}
