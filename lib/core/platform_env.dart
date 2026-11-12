import 'dart:ffi';
import 'dart:io';

enum PlatformKind { android, windows, linux, macOS, other }

/// Desktop and mobile capabilities differ mostly around hotspot control.
abstract final class PlatformEnv {
  static PlatformKind get kind {
    if (Platform.isAndroid) return PlatformKind.android;
    if (Platform.isWindows) return PlatformKind.windows;
    if (Platform.isLinux) return PlatformKind.linux;
    if (Platform.isMacOS) return PlatformKind.macOS;
    return PlatformKind.other;
  }

  static String get label => switch (kind) {
        PlatformKind.android => 'Android',
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
  /// GNOME needs the AppIndicator extension, but the tray itself is the normal
  /// desktop mechanism on Windows, KDE and GNOME alike.
  static bool get supportsTray =>
      kind == PlatformKind.windows ||
      kind == PlatformKind.linux ||
      kind == PlatformKind.macOS;

  /// Whether the app can join a hotspot non-interactively.
  static bool get canJoinHotspot =>
      kind == PlatformKind.android ||
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

/// Best-effort primary IPv4 address of a non-loopback interface.
Future<String?> localIpv4() async {
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
      includeLinkLocal: false,
    );
    final candidates = <String>[];
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        final ip = address.address;
        if (ip.startsWith('169.254.')) continue;
        candidates.add(ip);
      }
    }
    if (candidates.isEmpty) return null;
    // Prefer the private ranges a hotspot actually uses.
    for (final prefix in const ['192.168.', '10.', '172.']) {
      for (final ip in candidates) {
        if (ip.startsWith(prefix)) return ip;
      }
    }
    return candidates.first;
  } on Object {
    return null;
  }
}
