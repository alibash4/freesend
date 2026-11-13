/// Wire-level and app-wide constants for Free Send.
abstract final class AppConstants {
  static const appName = 'Free Send';
  static const appVersion = '1.7.3';
  static const appTagline = 'Direct transfer. No cloud.';

  /// Bumped whenever the frame layout or handshake changes. Version 2 adds
  /// folder metadata, per-file checksums, sender-side pause/resume, and
  /// X25519/AES-GCM encryption.
  static const protocolVersion = 3;

  /// UDP port used for session beacons on the local link.
  static const discoveryPort = 47810;

  /// TCP port the sending device listens on.
  static const transferPort = 47811;

  /// How often a host advertises its session on the hotspot network.
  static const beaconInterval = Duration(seconds: 2);

  /// A session without a peer is dropped after this long.
  static const idleTimeout = Duration(minutes: 30);

  /// Payload size per data frame. 512 KiB keeps syscall overhead low without
  /// holding huge buffers in memory on either side.
  static const chunkSize = 512 * 1024;

  /// Minimum interval between UI progress notifications.
  static const progressInterval = Duration(milliseconds: 90);

  static const maxHistoryEntries = 60;
  static const maxRecentFiles = 24;
}
