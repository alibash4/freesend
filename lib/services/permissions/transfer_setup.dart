import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:free_send/services/permissions/network_probe.dart';

/// What a checklist row is about.
enum SetupKind {
  /// Runtime permission for device discovery and the hotspot.
  nearby,

  /// Runtime notification permission, Android 13+ only.
  notifications,

  /// The Wi-Fi radio: the hotspot and the shared network both need it.
  wifi,

  /// A VPN must be off: it hides the local link from the other device.
  vpn,

  /// Android location services: required to run the hotspot on Android 10+.
  location,
}

/// One requirement a transfer depends on, in checklist order.
class SetupStep {
  const SetupStep({
    required this.index,
    required this.kind,
    required this.granted,
    this.mustGrant = true,
    this.needsSettings = false,
  });

  /// Position in the checklist, 1-based and contiguous.
  final int index;
  final SetupKind kind;

  /// Whether the requirement is currently met.
  final bool granted;

  /// Whether a transfer is blocked until this is met.
  final bool mustGrant;

  /// The OS will not show the prompt again; the user has to use Settings.
  /// Only meaningful for permission kinds.
  final bool needsSettings;

  /// Whether the app can act on this step itself (a system permission
  /// dialog). System states like VPN or the Wi-Fi radio cannot.
  bool get isActionable =>
      kind == SetupKind.nearby || kind == SetupKind.notifications;
}

/// Everything a send or a receive depends on, checked before a transfer
/// starts. Runtime permissions are asked here, in context, instead of at
/// app start; device settings that only the user can flip are shown as
/// status rows that re-check when they come back.
///
/// Desktop builds have nothing to ask for.
abstract final class TransferSetup {
  static bool get applies => Platform.isAndroid;

  /// Replaces the live checks. Tests set this; production leaves it null.
  @visibleForTesting
  static Future<List<SetupStep>> Function()? debugLoad;

  static int? _sdkInt;

  static Future<int?> get _sdkIntOrNull async =>
      _sdkInt ??= (await DeviceInfoPlugin().androidInfo).version.sdkInt;

  static Future<List<SetupStep>> load() async {
    final override = debugLoad;
    if (override != null) return override();
    if (!applies) return const [];
    final steps = <SetupStep>[];
    void add(
      SetupKind kind,
      bool granted, {
      bool needsSettings = false,
    }) =>
        steps.add(
          SetupStep(
            index: steps.length + 1,
            kind: kind,
            granted: granted,
            needsSettings: needsSettings,
          ),
        );

    // Nearby devices: location on older releases, nearby Wi-Fi on 33+.
    // Either grant is enough.
    final location = await Permission.locationWhenInUse.status;
    final nearby = await Permission.nearbyWifiDevices.status;
    add(
      SetupKind.nearby,
      _ok(location) || _ok(nearby),
      needsSettings: _blocked(location) && _blocked(nearby),
    );

    // POST_NOTIFICATIONS only exists on Android 13+; below that the OS
    // auto-grants it, so the step is skipped entirely.
    final sdk = await _sdkIntOrNull;
    if (sdk == null || sdk >= 33) {
      final notifications = await Permission.notification.status;
      add(
        SetupKind.notifications,
        _ok(notifications),
        needsSettings: _blocked(notifications),
      );
    }

    add(SetupKind.wifi, await NetworkProbe.wifiIsOn);
    add(SetupKind.vpn, !(await NetworkProbe.vpnIsOn));
    add(SetupKind.location, await NetworkProbe.locationIsOn);
    return steps;
  }

  static Future<bool> get isReady async {
    final steps = await load();
    return steps.every((step) => step.granted || !step.mustGrant);
  }

  /// Requests the system permission behind [step]. System-state steps have
  /// no in-app action and return immediately.
  static Future<void> enable(SetupStep step) async {
    switch (step.kind) {
      case SetupKind.nearby:
        final results = await [
          Permission.locationWhenInUse,
          Permission.nearbyWifiDevices,
        ].request();
        if (results.values.any(_blocked)) await openAppSettings();
        return;
      case SetupKind.notifications:
        final status = await Permission.notification.request();
        if (_blocked(status)) await openAppSettings();
        return;
      case SetupKind.wifi:
        await NetworkProbe.openSystemSettings('wifi');
        return;
      case SetupKind.vpn:
        await NetworkProbe.openSystemSettings('vpn');
        return;
      case SetupKind.location:
        await NetworkProbe.openSystemSettings('location');
        return;
    }
  }

  static bool _ok(PermissionStatus status) =>
      status.isGranted || status.isLimited;

  static bool _blocked(PermissionStatus status) =>
      status.isPermanentlyDenied || status.isRestricted;
}
