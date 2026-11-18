import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:free_send/services/permissions/network_probe.dart';

/// One device setting a transfer depends on, in checklist order.
class SetupStep {
  const SetupStep({
    required this.index,
    required this.granted,
    this.mustGrant = true,
  });

  /// Position in the checklist, 1-based and contiguous.
  final int index;

  /// Whether the requirement is currently met.
  final bool granted;

  /// Whether a transfer is blocked until this is on.
  final bool mustGrant;
}

/// The device settings a send or a receive depends on, checked before a
/// transfer starts. These are system states, not app permissions - runtime
/// permissions are handled once by the first-launch gate, while VPN,
/// location services, and the Wi-Fi radio can change at any time.
///
/// None of them can be toggled from inside the app, so the gate is a
/// checklist: it re-checks when the user comes back from system settings.
/// Desktop builds have nothing to ask for.
abstract final class TransferSetup {
  static bool get applies => Platform.isAndroid;

  /// Replaces the live probe. Tests set this; production leaves it null.
  @visibleForTesting
  static Future<List<SetupStep>> Function()? debugLoad;

  static Future<List<SetupStep>> load() async {
    final override = debugLoad;
    if (override != null) return override();
    if (!applies) return const [];
    final wifiOn = await NetworkProbe.wifiIsOn;
    final vpnOn = await NetworkProbe.vpnIsOn;
    // Android 10+ will not run the hotspot at all with this off.
    final locationOn = await NetworkProbe.locationIsOn;
    return [
      SetupStep(index: 1, granted: wifiOn),
      // A VPN routes around the local link, so both sides become invisible.
      SetupStep(index: 2, granted: !vpnOn),
      SetupStep(index: 3, granted: locationOn),
    ];
  }

  static Future<bool> get isReady async {
    final steps = await load();
    return steps.every((step) => step.granted || !step.mustGrant);
  }
}
