import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

import 'package:free_send/services/hotspot/hotspot_service.dart';

/// Android needs a runtime grant before the app may create or join a hotspot:
/// `ACCESS_FINE_LOCATION` up to Android 12, `NEARBY_WIFI_DEVICES` from Android
/// 13. The older platform reports the newer permission as unavailable, so a
/// grant of *either* one is enough — asking for both keeps both API levels
/// working without a device_info dependency.
Future<void> ensureHotspotPermissions() async {
  if (!Platform.isAndroid) return;
  final results = await [
    Permission.locationWhenInUse,
    Permission.nearbyWifiDevices,
  ].request();
  final granted = results.values.any(
    (status) => status.isGranted || status.isLimited,
  );
  if (!granted) {
    throw HotspotException(
      'Android requires the location (or nearby devices) permission to use a '
      'hotspot. Enable it in system settings and try again.',
      manual: true,
    );
  }
}
