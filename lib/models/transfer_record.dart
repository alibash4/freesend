enum TransferDirection { send, receive }

/// One finished (or failed) transfer, kept in local history.
class TransferRecord {
  TransferRecord({
    required this.id,
    required this.direction,
    required this.peerName,
    required this.fileCount,
    required this.bytes,
    required this.timestamp,
    required this.durationMs,
    required this.succeeded,
    this.peerPlatform,
  });

  final String id;
  final TransferDirection direction;
  final String peerName;
  final String? peerPlatform;
  final int fileCount;
  final int bytes;
  final DateTime timestamp;
  final int durationMs;
  final bool succeeded;

  double get averageBytesPerSecond {
    if (durationMs <= 0) return 0;
    return bytes / (durationMs / 1000);
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'direction': direction.name,
        'peerName': peerName,
        if (peerPlatform != null) 'peerPlatform': peerPlatform,
        'fileCount': fileCount,
        'bytes': bytes,
        'timestamp': timestamp.toIso8601String(),
        'durationMs': durationMs,
        'succeeded': succeeded,
      };

  static TransferRecord? fromJson(Map<String, Object?> json) {
    final directionName = json['direction'] as String?;
    final direction = TransferDirection.values
        .where((value) => value.name == directionName)
        .firstOrNull;
    final timestamp = DateTime.tryParse(json['timestamp'] as String? ?? '');
    if (direction == null || timestamp == null) return null;
    return TransferRecord(
      id: (json['id'] ?? timestamp.microsecondsSinceEpoch.toString()) as String,
      direction: direction,
      peerName: (json['peerName'] ?? 'Unknown device') as String,
      peerPlatform: json['peerPlatform'] as String?,
      fileCount: (json['fileCount'] as num?)?.toInt() ?? 0,
      bytes: (json['bytes'] as num?)?.toInt() ?? 0,
      timestamp: timestamp,
      durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
      succeeded: json['succeeded'] as bool? ?? true,
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
