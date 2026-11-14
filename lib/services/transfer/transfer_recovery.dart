import 'dart:convert';
import 'dart:io';

/// One partially received file, enough to reopen it at the right offset after
/// the app or the connection is gone.
class RecoveryEntry {
  RecoveryEntry({
    required this.id,
    required this.name,
    required this.size,
    required this.path,
    required this.offset,
    this.relativePath,
  });

  final String id;
  final String name;
  final int size;
  final String path;
  final int offset;
  final String? relativePath;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'size': size,
        'path': path,
        'offset': offset,
        if (relativePath != null) 'dir': relativePath,
      };

  static RecoveryEntry? fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final path = json['path'];
    final offset = json['offset'];
    final size = json['size'];
    if (id is! String || path is! String || offset is! num || size is! num) {
      return null;
    }
    return RecoveryEntry(
      id: id,
      name: (json['name'] as String?) ?? 'file',
      size: size.toInt(),
      path: path,
      offset: offset.toInt(),
      relativePath: json['dir'] as String?,
    );
  }
}

/// Small JSON sidecar next to the received files. It is deliberately not a
/// database: a handful of entries, rewritten at most once a second.
class TransferRecovery {
  TransferRecovery(this.root);

  final String root;

  File get file =>
      File('$root${Platform.pathSeparator}.freesend-recovery.json');

  Future<Map<String, RecoveryEntry>> load() async {
    try {
      if (!await file.exists()) return const {};
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, Object?>) return const {};
      final items = decoded['items'];
      if (items is! List<Object?>) return const {};
      final entries = <String, RecoveryEntry>{};
      for (final raw in items) {
        if (raw is! Map<String, Object?>) continue;
        final entry = RecoveryEntry.fromJson(raw);
        if (entry != null && entry.offset > 0 && entry.offset < entry.size) {
          entries[entry.id] = entry;
        }
      }
      return entries;
    } on Object {
      // A corrupt sidecar must never block a fresh transfer.
      return const {};
    }
  }

  Future<void> save(Iterable<RecoveryEntry> entries) async {
    final live = entries
        .where((entry) => entry.offset > 0 && entry.offset < entry.size)
        .toList(growable: false);
    try {
      final root = Directory(this.root);
      if (!await root.exists()) await root.create(recursive: true);
      await file.writeAsString(
        jsonEncode({'items': [for (final entry in live) entry.toJson()]}),
        flush: true,
      );
    } on Object {
      // Recovery is best effort; losing it only means a restart from zero.
    }
  }

  Future<void> clear() async {
    try {
      if (await file.exists()) await file.delete();
    } on Object {
      // Ignore.
    }
  }
}