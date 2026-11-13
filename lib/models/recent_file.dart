import 'dart:io';

/// A file the user picked recently, kept so a repeat transfer does not need the
/// system picker again. Paths are absolute; the UI drops entries whose file has
/// since disappeared.
class RecentFile {
  const RecentFile({
    required this.path,
    required this.name,
    required this.size,
    required this.addedAt,
  });

  final String path;
  final String name;
  final int size;
  final DateTime addedAt;

  Map<String, Object?> toJson() => {
        'path': path,
        'name': name,
        'size': size,
        'at': addedAt.millisecondsSinceEpoch,
      };

  static RecentFile? fromJson(Map<String, Object?> json) {
    final path = json['path'];
    final name = json['name'];
    final size = json['size'];
    final at = json['at'];
    if (path is! String || name is! String || size is! num || at is! num) {
      return null;
    }
    return RecentFile(
      path: path,
      name: name,
      size: size.toInt(),
      addedAt: DateTime.fromMillisecondsSinceEpoch(at.toInt()),
    );
  }

  static RecentFile? fromFile(File file) {
    try {
      final stat = file.statSync();
      if (stat.type != FileSystemEntityType.file) return null;
      return RecentFile(
        path: file.path,
        name: file.uri.pathSegments.last,
        size: stat.size,
        addedAt: DateTime.now(),
      );
    } on FileSystemException {
      return null;
    }
  }
}