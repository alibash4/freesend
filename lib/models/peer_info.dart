import 'package:free_send/models/transfer_item.dart';

/// One receiver in a group session, as the sender sees it.
///
/// The sender streams the same selection to every peer, but each peer can pick
/// a different subset. Progress is therefore tracked per peer, not globally.
class PeerInfo {
  const PeerInfo({
    required this.id,
    required this.name,
    this.platform,
    this.selectedIds = const [],
    this.transferred = 0,
    this.totalBytes = 0,
    this.completedFiles = 0,
    this.currentFile,
    this.status = TransferStatus.pending,
  });

  final String id;
  final String name;
  final String? platform;
  final List<String> selectedIds;
  final int transferred;
  final int totalBytes;
  final int completedFiles;
  final String? currentFile;
  final TransferStatus status;

  double get progress {
    if (status == TransferStatus.done) return 1;
    if (totalBytes <= 0) return 0;
    return (transferred / totalBytes).clamp(0, 1);
  }

  PeerInfo copyWith({
    List<String>? selectedIds,
    int? transferred,
    int? totalBytes,
    int? completedFiles,
    String? currentFile,
    bool clearCurrentFile = false,
    TransferStatus? status,
  }) {
    return PeerInfo(
      id: id,
      name: name,
      platform: platform,
      selectedIds: selectedIds ?? this.selectedIds,
      transferred: transferred ?? this.transferred,
      totalBytes: totalBytes ?? this.totalBytes,
      completedFiles: completedFiles ?? this.completedFiles,
      currentFile: clearCurrentFile ? null : (currentFile ?? this.currentFile),
      status: status ?? this.status,
    );
  }
}