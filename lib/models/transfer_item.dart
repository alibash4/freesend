import 'dart:io';

/// Where a single file is in the transfer lifecycle. The UI uses this to show
/// per-file state without inferring it from byte counts.
enum TransferStatus { pending, active, paused, done, failed }

/// A single file taking part in a transfer, in either direction.
class TransferItem {
  TransferItem({
    required this.id,
    required this.name,
    required this.size,
    this.path,
    this.relativePath,
    this.receivedPath,
    this.transferred = 0,
    this.done = false,
    this.status = TransferStatus.pending,
    this.sha256,
  });

  /// Stable per-session identifier used on the wire. Assigned by the sender
  /// once the file is added to a session.
  String id;
  final String name;
  final int size;

  /// Absolute local path. Set on the sender (source) and on the receiver once
  /// the file has been opened for writing.
  String? path;
  String? receivedPath;

  /// Optional folder hint, so nested picks keep their structure.
  final String? relativePath;

  int transferred;
  bool done;
  TransferStatus status;
  String? sha256;

  double get progress => size <= 0 ? (done ? 1 : 0) : (transferred / size).clamp(0, 1);

  bool get isComplete => size == 0 ? done : transferred >= size;

  static TransferItem? fromFile(File file, {String? relativePath}) {
    try {
      final stat = file.statSync();
      if (stat.type != FileSystemEntityType.file) return null;
      return TransferItem(
        id: '',
        name: file.uri.pathSegments.last,
        size: stat.size,
        path: file.path,
        relativePath: relativePath,
      );
    } on FileSystemException {
      return null;
    }
  }

  Map<String, Object?> toWire() => {
        'id': id,
        'name': name,
        'size': size,
        if (relativePath != null) 'dir': relativePath,
        if (sha256 != null) 'sha256': sha256,
      };

  static TransferItem fromWire(Map<String, Object?> json) {
    return TransferItem(
      id: (json['id'] ?? '') as String,
      name: (json['name'] ?? 'file') as String,
      size: (json['size'] as num?)?.toInt() ?? 0,
      relativePath: json['dir'] as String?,
      sha256: json['sha256'] as String?,
    );
  }
}
