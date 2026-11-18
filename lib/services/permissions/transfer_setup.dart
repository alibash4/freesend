import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:free_send/services/permissions/app_permissions.dart';
import 'package:free_send/services/permissions/network_probe.dart';

/// One grant FreeSend needs before a transfer can start, in the order the
/// user has to turn them on.
class SetupStep {
  const SetupStep({
    required this.index,
    required this.granted,
    required this.needsSettings,
    this.mustGrant = true,
  });

  /// 1 for nearby devices, 2 for notifications, 3 for the camera.
  final int index;
  final bool granted;

  /// The system will not show the prompt again. The user has to use Settings.
  final bool needsSettings;

  /// Whether a transfer is blocked until this grant is on.
  ///
  /// The camera is not: a pairing code can be pasted by hand, so a device
  /// without one is still able to send and receive.
  final bool mustGrant;
}

/// The Android grants a send or a receive depends on, checked and requested
/// one at a time. Nearby devices and notifications block a transfer, the
/// camera does not. Desktop builds have nothing to ask for.
abstract final class TransferSetup {
  static bool get applies => Platform.isAndroid;

  /// Replaces the live permission read. Tests set this; production leaves it null.
  @visibleForTesting
  static Future<List<SetupStep>> Function()? debugLoad;

  static Future<List<SetupStep>> load() async {
    final override = debugLoad;
    if (override != null) return override();
    if (!applies) return const [];
    final nearby = await _nearby();
    // POST_NOTIFICATIONS only exists on Android 13+; below that the OS
    // auto-grants notifications and permission_handler reports nothing
    // requestable, so the step is skipped entirely.
    final sdk = await AppPermissions.androidSdkInt;
    final notifications = sdk != null && sdk < 33
        ? null
        : await Permission.notification.status;
    final camera = await Permission.camera.status;
    // A VPN routes around the local link, so both sides become invisible.
    final vpnOn = await NetworkProbe.vpnIsOn;
    // Android 10+ will not run the hotspot at all with this off.
    final locationOn = await NetworkProbe.locationIsOn;
    return [
      SetupStep(
        index: 1,
        granted: nearby.granted,
        needsSettings: nearby.needsSettings,
      ),
      if (notifications != null)
        SetupStep(
          index: 2,
          granted: _ok(notifications),
          needsSettings: _blocked(notifications),
        ),
      SetupStep(
        index: 3,
        granted: _ok(camera),
        needsSettings: _blocked(camera),
        mustGrant: false,
      ),
      SetupStep(
        index: 4,
        granted: !vpnOn,
        needsSettings: true,
      ),
      SetupStep(
        index: 5,
        granted: locationOn,
        needsSettings: true,
      ),
    ];
  }

  static Future<bool> get isReady async {
    final steps = await load();
    return steps.every((step) => step.granted || !step.mustGrant);
  }

  /// Requests only [index]. Earlier steps must already be granted; the caller
  /// enforces that so the system dialogs arrive in order.
  static Future<void> enable(int index) async {
    switch (index) {
      case 1:
        final results = await [
          Permission.locationWhenInUse,
          Permission.nearbyWifiDevices,
        ].request();
        if (results.values.any(_blocked)) await openAppSettings();
        return;
      case 2:
        final status = await Permission.notification.request();
        if (_blocked(status)) await openAppSettings();
        return;
      case 3:
        final status = await Permission.camera.request();
        if (_blocked(status)) await openAppSettings();
        return;
      case 4:
      case 5:
        // Both belong to the system, not to FreeSend: a VPN lives in another
        // app and location services live in quick settings. Returning lets the
        // screen re-check them when the user comes back.
        return;
    }
  }

  static bool _ok(PermissionStatus status) =>
      status.isGranted || status.isLimited;

  static bool _blocked(PermissionStatus status) =>
      status.isPermanentlyDenied || status.isRestricted;

  /// Location on Android 12 and earlier, nearby Wi-Fi devices from 13. Either
  /// grant is enough; the other reports as unavailable on the wrong API level.
  static Future<({bool granted, bool needsSettings})> _nearby() async {
    final location = await Permission.locationWhenInUse.status;
    final nearby = await Permission.nearbyWifiDevices.status;
    return (
      granted: _ok(location) || _ok(nearby),
      needsSettings: _blocked(location) && _blocked(nearby),
    );
  }
}
