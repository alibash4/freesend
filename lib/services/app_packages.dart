import 'dart:io';

import 'package:flutter/services.dart';

class InstalledApp {
  const InstalledApp({
    required this.name,
    required this.path,
    required this.version,
  });

  final String name;
  final String path;
  final String version;
}

/// Lists installable app bundles. Android exposes each installed package's APK
/// through PackageManager; other platforms return nothing and the send screen
/// falls back to the system file picker.
abstract final class InstalledApps {
  static const MethodChannel _channel =
      MethodChannel('com.freesend.free_send/apps');

  static Future<List<InstalledApp>> list() async {
    if (!Platform.isAndroid) return const [];
    try {
      final raw = await _channel.invokeListMethod<Map<Object?, Object?>>('list');
      if (raw == null) return const [];
      final apps = <InstalledApp>[];
      for (final entry in raw) {
        final name = entry['name'];
        final path = entry['path'];
        if (name is! String || path is! String || path.isEmpty) continue;
        apps.add(InstalledApp(
          name: name,
          path: path,
          version: entry['version'] as String? ?? '',
        ));
      }
      apps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return apps;
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }
}