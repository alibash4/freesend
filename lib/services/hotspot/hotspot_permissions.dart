import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

import 'package:free_send/services/app_logger.dart';
import 'package:free_send/services/hotspot/hotspot_service.dart';

/// Android needs a runtime grant before the app may create or join a hotspot:
/// `ACCESS_FINE_LOCATION` up to Android 12, `NEARBY_WIFI_DEVICES` from Android
/// 13. The older platform reports the newer permission as unavailable, so they
/// are asked one at a time - asking for both in one batch makes some devices
/// deny the whole request, including the permission the user had already
/// granted.
///
/// A grant alone is not enough on Android 10+: the bridge also refuses when
/// location services are switched off, which the caller reports separately.
Future<void> ensureHotspotPermissions() async {
  if (!Platform.isAndroid) return;
  var status = await _request(Permission.locationWhenInUse);
  if (!_granted(status)) {
    // Android 13 and newer use this instead of location.
    status = await _request(Permission.nearbyWifiDevices);
  }
  if (!_granted(status)) {
    AppLog.warn('hotspot', 'no hotspot permission after asking ('
        'location=${await Permission.locationWhenInUse.status}, '
        'nearby=${await Permission.nearbyWifiDevices.status})');
    throw HotspotException(
      'Android requires the location (or nearby devices) permission to use a '
      'hotspot. Enable it in system settings and try again.',
      manual: true,
    );
  }
}

Future<PermissionStatus> _request(Permission permission) async {
  try {
    final status = await permission.request();
    AppLog.info('hotspot', '$permission -> ${status.name}');
    return status;
  } on Object catch (error) {
    // An undeclared permission on this API level throws instead of resolving.
    AppLog.warn('hotspot', '$permission could not be requested: $error');
    return PermissionStatus.denied;
  }
}

bool _granted(PermissionStatus status) =>
    status.isGranted || status.isLimited;