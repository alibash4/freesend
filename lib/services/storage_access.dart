import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

/// Whether the app can browse the whole shared storage on Android.
///
/// Android 11+ requires the special "All files access" grant
/// ([Permission.manageExternalStorage]); Android 10 and below use the
/// classic runtime storage permission. Other platforms always report
/// granted - they have no scoped-storage restriction.
abstract final class StorageAccess {
  static int? _sdkInt;

  static Future<int> _sdk() async {
    final cached = _sdkInt;
    if (cached != null) return cached;
    if (!Platform.isAndroid) return 30;
    final info = await DeviceInfoPlugin().androidInfo;
    return _sdkInt = info.version.sdkInt;
  }

  static Future<bool> isGranted() async {
    if (!Platform.isAndroid) return true;
    if (await _sdk() >= 30) {
      return (await Permission.manageExternalStorage.status).isGranted;
    }
    return (await Permission.storage.status).isGranted;
  }

  /// Opens the system screen where the user grants access. Returns
  /// immediately - callers re-check [isGranted] on resume.
  static Future<void> request() async {
    if (!Platform.isAndroid) return;
    if (await _sdk() >= 30) {
      await Permission.manageExternalStorage.request();
    } else {
      await Permission.storage.request();
    }
  }
}
