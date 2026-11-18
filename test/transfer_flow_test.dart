import 'package:flutter_test/flutter_test.dart';

import 'package:free_send/core/platform_env.dart';
import 'package:free_send/core/transfer_flow.dart';

void main() {
  group('hotspotOwnerFor', () {
    test('phone to phone: the receiver hosts so it can show the QR', () {
      expect(
        hotspotOwnerFor(
          sender: PlatformKind.android,
          receiver: PlatformKind.android,
        ),
        HotspotOwner.receiver,
      );
    });

    test('a phone hosts in a mixed pair, whichever role it has', () {
      for (final desktop in [
        PlatformKind.windows,
        PlatformKind.linux,
        PlatformKind.macOS,
      ]) {
        expect(
          hotspotOwnerFor(sender: PlatformKind.android, receiver: desktop),
          HotspotOwner.sender,
          reason: 'phone is the sender against $desktop',
        );
        expect(
          hotspotOwnerFor(sender: desktop, receiver: PlatformKind.android),
          HotspotOwner.receiver,
          reason: 'phone is the receiver against $desktop',
        );
      }
    });

    test('desktop-only pairs have no host', () {
      const desktops = [
        PlatformKind.windows,
        PlatformKind.linux,
        PlatformKind.macOS,
      ];
      for (final sender in desktops) {
        for (final receiver in desktops) {
          expect(
            hotspotOwnerFor(sender: sender, receiver: receiver),
            HotspotOwner.none,
            reason: '$sender -> $receiver must use an existing network',
          );
        }
      }
    });
  });

  group('send entries', () {
    test('phones get all three entries', () {
      expect(sendEntriesFor(PlatformKind.android), [
        SendEntry.nearby,
        SendEntry.scanCode,
        SendEntry.group,
      ]);
    });

    test('every desktop hides the scan entry, including macOS', () {
      for (final desktop in [
        PlatformKind.windows,
        PlatformKind.linux,
        PlatformKind.macOS,
      ]) {
        expect(
          sendEntriesFor(desktop),
          [SendEntry.nearby, SendEntry.group],
          reason: '$desktop shows two entries',
        );
      }
    });

    test('the scanner capability is not the same as the entry', () {
      // macOS can scan but the desktop shell never offers the entry.
      expect(cameraScannerAvailable(PlatformKind.macOS), isTrue);
      expect(showScanEntry(PlatformKind.macOS), isFalse);
      expect(cameraScannerAvailable(PlatformKind.windows), isFalse);
      expect(showScanEntry(PlatformKind.android), isTrue);
    });
  });

  test('endpoint kinds follow the platform list', () {
    expect(endpointKindOf(PlatformKind.android), EndpointKind.phone);
    expect(endpointKindOf(PlatformKind.ios), EndpointKind.phone);
    expect(endpointKindOf(PlatformKind.windows), EndpointKind.desktop);
    expect(endpointKindOf(PlatformKind.linux), EndpointKind.desktop);
    expect(endpointKindOf(PlatformKind.macOS), EndpointKind.desktop);
  });
}