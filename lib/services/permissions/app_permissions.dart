import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// The runtime permissions FreeSend needs on its mobile builds.
///
/// Desktop builds do not have a runtime permission prompt for local sockets,
/// the tray, or the file picker, so [isMobile] is the gate the UI uses.
abstract final class AppPermissions {
  static bool get isMobile => Platform.isAndroid || Platform.isIOS;

  static int? _sdkInt;

  /// The Android API level, or null off Android. Cached after the first read.
  static Future<int?> get androidSdkInt async {
    if (!Platform.isAndroid) return null;
    return _sdkInt ??= (await DeviceInfoPlugin().androidInfo).version.sdkInt;
  }

  /// Permissions the runtime can actually prompt for on this device.
  ///
  /// permission_handler only maps notification, nearby-Wi-Fi and media
  /// permissions to manifest entries on Android 13 (API 33) and newer; on
  /// older releases they resolve to nothing and come back denied without a
  /// dialog. Below 33 those capabilities are covered differently: location
  /// covers hotspot discovery, the OS auto-grants notifications, and
  /// READ_EXTERNAL_STORAGE (declared for maxSdk 32) covers media.
  static Future<List<Permission>> get required async {
    if (Platform.isAndroid) {
      final sdk = await androidSdkInt ?? 0;
      return [
        Permission.locationWhenInUse,
        Permission.camera,
        if (sdk >= 33) ...[
          Permission.nearbyWifiDevices,
          Permission.notification,
          Permission.photos,
          Permission.videos,
          Permission.audio,
        ],
      ];
    }
    if (Platform.isIOS) {
      return const [Permission.camera];
    }
    return const [];
  }

  static Future<Map<Permission, PermissionStatus>> request() async {
    return (await required).request();
  }

  static Future<bool> allGranted() async {
    final permissions = await required;
    final statuses = await Future.wait(
      permissions.map((permission) => permission.status),
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
          'or start a transfer. Allow it so FreeSend can find the other device.'
      : '';
}
