import 'dart:io';

/// How this copy of the app was installed, which decides which release asset
/// the updater downloads.
enum PackageFormat {
  /// Android APK. Bitness is chosen separately from the device ABI.
  android,

  /// Single-file Linux AppImage. Detected from the `APPIMAGE` environment.
  appImage,

  /// Debian package installed under `/opt/freesend`.
  deb,

  /// RPM package installed under `/opt/freesend`.
  rpm,

  /// Unpacked Linux bundle (`free_send` plus `lib/` and `data/`).
  bundle,

  /// Windows build: a zip of the release folder, which contains the exe.
  windows,

  /// macOS app bundle, shipped inside a disk image.
  macOS,
}

/// Reads the format written next to the binary by the packaging scripts.
///
/// The file is named `package-kind` and contains one of `deb`, `rpm`,
/// `bundle`, `appimage`, `dmg`. AppImage launches also set `APPIMAGE`, which
/// wins so a bundle packed inside an AppImage is not treated as a raw install.
PackageFormat detectPackageFormat({
  Map<String, String>? environment,
  String? executablePath,
  String? markerText,
}) {
  final env = environment ?? Platform.environment;
  if (env['APPIMAGE']?.isNotEmpty ?? false) return PackageFormat.appImage;

  if (Platform.isAndroid) return PackageFormat.android;
  if (Platform.isWindows) return PackageFormat.windows;
  if (Platform.isMacOS) return PackageFormat.macOS;

  final marker = (markerText ?? _readMarker(executablePath))?.trim().toLowerCase();
  return switch (marker) {
    'deb' => PackageFormat.deb,
    'rpm' => PackageFormat.rpm,
    'appimage' => PackageFormat.appImage,
    'bundle' => PackageFormat.bundle,
    'dmg' => PackageFormat.macOS,
    _ => Platform.isLinux ? PackageFormat.bundle : PackageFormat.windows,
  };
}

String? _readMarker(String? executablePath) {
  final executable = executablePath ?? Platform.resolvedExecutable;
  final file = File(
    '${File(executable).parent.path}${Platform.pathSeparator}package-kind',
  );
  try {
    if (!file.existsSync()) return null;
    return file.readAsStringSync();
  } on Object {
    return null;
  }
}

/// The format a downloaded file implies from its own name, or null when the
/// name carries no extension this app recognises.
PackageFormat? formatForFile(String path) {
  final name = path.toLowerCase();
  if (name.endsWith('.appimage')) return PackageFormat.appImage;
  if (name.endsWith('.deb')) return PackageFormat.deb;
  if (name.endsWith('.rpm')) return PackageFormat.rpm;
  if (name.endsWith('.tar.gz') || name.endsWith('.tgz')) {
    return PackageFormat.bundle;
  }
  if (name.endsWith('.dmg')) return PackageFormat.macOS;
  if (name.endsWith('.zip') || name.endsWith('.exe')) {
    return PackageFormat.windows;
  }
  return null;
}

/// Substrings the release asset name must contain, in preference order.
///
/// The first list entry is the format this install wants. Later entries are
/// fallbacks so an older release that only published an AppImage still updates.
List<String> formatMarkers(PackageFormat format) => switch (format) {
      PackageFormat.android => const ['android'],
      PackageFormat.appImage => const ['appimage', 'bundle'],
      PackageFormat.deb => const ['(deb)', 'bundle', 'appimage'],
      PackageFormat.rpm => const ['(rpm)', 'bundle', 'appimage'],
      PackageFormat.bundle => const ['(bundle)', 'appimage', '(deb)', '(rpm)'],
      PackageFormat.windows => const ['(exe)', 'windows'],
      PackageFormat.macOS => const ['(dmg)'],
    };
