import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

/// The runtime permissions Free Send needs on its mobile builds.
///
/// Desktop builds do not have a runtime permission prompt for local sockets,
/// the tray, or the file picker, so [isMobile] is the gate the UI uses.
abstract final class AppPermissions {
  static bool get isMobile => Platform.isAndroid || Platform.isIOS;

  static List<Permission> get required {
    if (Platform.isAndroid) {
      return const [
        Permission.locationWhenInUse,
        Permission.nearbyWifiDevices,
        Permission.camera,
        Permission.notification,
      ];
    }
    if (Platform.isIOS) {
      return const [Permission.camera];
    }
    return const [];
  }

  static Future<Map<Permission, PermissionStatus>> request() {
    return required.request();
  }

  static Future<bool> allGranted() async {
    final statuses = await Future.wait(
      required.map((permission) => permission.status),
    );
    return statuses.every(
      (status) => status.isGranted || status.isLimited,
    );
  }

  static Future<bool> openSettings() => openAppSettings();

  /// iOS does not expose a local-network permission API. The system prompt is
  /// raised the first time the app opens a local socket, so the startup screen
  /// explains it instead of pretending to request it.
  static String get localNetworkNote => Platform.isIOS
      ? 'iOS will ask for local network access the first time you open Receive '
          'or start a transfer. Allow it so Free Send can find the other device.'
      : '';
}