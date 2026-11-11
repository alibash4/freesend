/// A release published on GitLab, reduced to what the updater needs.
class UpdateInfo {
  const UpdateInfo({
    required this.version,
    required this.changelog,
    required this.publishedAt,
    required this.downloadUrl,
    required this.fileName,
    required this.sizeBytes,
  });

  /// Version without a leading `v`, e.g. `1.2.0`.
  final String version;

  /// Release notes shown in the update sheet.
  final String changelog;

  final DateTime? publishedAt;
  final String downloadUrl;
  final String fileName;
  final int sizeBytes;

  /// True when this release is newer than [currentVersion].
  bool isNewerThan(String currentVersion) =>
      _compare(version, _normalize(currentVersion)) > 0;

  /// Releases are tagged `v1.2.0`; the app version is `1.2.0`.
  static String _normalize(String version) {
    final trimmed = version.trim();
    return trimmed.startsWith('v') ? trimmed.substring(1) : trimmed;
  }

  /// Compares dotted numeric versions segment by segment. Non-numeric
  /// segments sort below numeric ones so `1.0.0-rc1` stays below `1.0.0`.
  static int _compare(String a, String b) {
    final left = a.split('.');
    final right = b.split('.');
    final count = left.length > right.length ? left.length : right.length;
    for (var i = 0; i < count; i++) {
      final l = i < left.length ? left[i] : '0';
      final r = i < right.length ? right[i] : '0';
      final ln = int.tryParse(l);
      final rn = int.tryParse(r);
      if (ln != null && rn != null) {
        if (ln != rn) return ln.compareTo(rn);
      } else {
        final compared = l.compareTo(r);
        if (compared != 0) return compared;
      }
    }
    return 0;
  }
}
