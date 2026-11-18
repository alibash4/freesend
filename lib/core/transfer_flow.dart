import 'package:free_send/core/platform_env.dart';

/// How a session reaches the other device.
///
/// HOTSPOT: one device runs a local-only hotspot and the others join it.
/// LOCAL_WIFI: both devices already share a Wi-Fi network or a cable.
enum SessionMode {
  hotspot,
  localWifi,
}

/// Consent state of one receiving device.
///
/// A request stays [pending] until it is answered or the peer disappears;
/// there is deliberately no expiry.
enum AuthState { pending, accepted, declined, offline }

/// Entries offered by the send control.
enum SendEntry { nearby, scanCode, group }

/// What the receiver's waiting screen shows.
enum ReceiverPresence {
  /// Not receiving yet.
  idle,

  /// This device hosts the link and shows a QR for the other side to scan.
  qr,

  /// No camera can be used on either side, so there is nothing to scan.
  noCamera,

  /// A desktop that must join the phone's hotspot before anything works.
  joinPrompt,
}

/// What the sender chose from the send control.
enum SendMode { nearby, scanCode, group }

/// Which side runs the hotspot in a pairing.
enum HotspotOwner { sender, receiver, none }

/// Coarse device class used by the flow rules.
enum EndpointKind { phone, desktop }

/// Phones host whenever one is involved; desktop-only pairs have no host.
///
/// Both phones: the receiver hosts, so it can show the QR the sender scans.
/// Mixed pair: the phone hosts, whichever role it has.
/// Neither phone: nobody hosts, so the session must use an existing network.
HotspotOwner hotspotOwnerFor({
  required PlatformKind sender,
  required PlatformKind receiver,
}) {
  final senderPhone = endpointKindOf(sender) == EndpointKind.phone;
  final receiverPhone = endpointKindOf(receiver) == EndpointKind.phone;
  if (senderPhone && receiverPhone) return HotspotOwner.receiver;
  if (senderPhone) return HotspotOwner.sender;
  if (receiverPhone) return HotspotOwner.receiver;
  return HotspotOwner.none;
}

EndpointKind endpointKindOf(PlatformKind kind) =>
    kind == PlatformKind.android || kind == PlatformKind.ios
        ? EndpointKind.phone
        : EndpointKind.desktop;

/// Whether the platform ships a camera scanner at all.
///
/// This is a capability of the build, not of the UI: macOS can scan, but the
/// desktop shell hides the entry (see [sendEntriesFor]).
bool cameraScannerAvailable(PlatformKind kind) =>
    kind == PlatformKind.android || kind == PlatformKind.macOS;

/// Whether the send control offers "Scan a QR code".
///
/// Hidden on every desktop, including macOS, because the desktop shell never
/// presents a scanner.
bool showScanEntry(PlatformKind kind) =>
    endpointKindOf(kind) == EndpointKind.phone;

/// The send control entries for a platform, in display order.
List<SendEntry> sendEntriesFor(PlatformKind kind) => [
      SendEntry.nearby,
      if (showScanEntry(kind)) SendEntry.scanCode,
      SendEntry.group,
    ];