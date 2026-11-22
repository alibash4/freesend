import 'package:flutter/services.dart';

/// One row inside an Android SAF tree, as reported by the native bridge.
class SafEntry {
  const SafEntry({
    required this.name,
    required this.isDir,
    required this.size,
    required this.uri,
    required this.documentId,
    required this.mimeType,
  });

  final String name;
  final bool isDir;
  final int size;
  final String uri;

  /// The provider document id; combined with the tree's authority it
  /// rebuilds a tree URI for [SafFolders.copyTreeToCache].
  final String documentId;
  final String mimeType;

  factory SafEntry.fromMap(Map<Object?, Object?> map) {
    return SafEntry(
      name: map['name'] as String? ?? 'file',
      isDir: map['isDir'] == true,
      size: (map['size'] as num?)?.toInt() ?? 0,
      uri: map['uri'] as String? ?? '',
      documentId: map['documentId'] as String? ?? '',
      mimeType: map['mimeType'] as String? ?? '',
    );
  }
}

/// Browses an Android Storage Access Framework tree the user granted.
///
/// Dart cannot open content:// URIs, so the native bridge lists children
/// and copies picked items into the app cache; the browser only ever sees
/// names, sizes and URIs.
abstract final class SafBrowser {
  static const MethodChannel _channel =
      MethodChannel('com.freesend.free_send/saf');

  /// Keeps the grant alive across reboots. Returns false when the system
  /// refuses (e.g. the picker already persisted it) - browsing still works.
  static Future<bool> persist(String treeUri) async {
    try {
      return await _channel.invokeMethod<bool>('persist', {'uri': treeUri}) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Lists the children of [path] inside the tree rooted at [treeUri].
  /// [path] is a '/'-joined chain of names relative to the root ('').
  static Future<List<SafEntry>> list(String treeUri, String path) async {
    final raw = await _channel.invokeListMethod<Object?>(
      'list',
      {'uri': treeUri, 'path': path},
    );
    return (raw ?? const [])
        .whereType<Map<Object?, Object?>>()
        .map(SafEntry.fromMap)
        .toList(growable: false);
  }

  /// Copies one document into the app cache and returns the cached path.
  static Future<String?> copyFileToCache(String documentUri) async {
    try {
      final result = await _channel.invokeMapMethod<Object?, Object?>(
        'copyFile',
        {'uri': documentUri},
      );
      final path = result?['path'];
      return path is String && path.isNotEmpty ? path : null;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }
}
