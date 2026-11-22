import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:free_send/core/platform_env.dart';
import 'package:free_send/services/update/package_format.dart';
import 'package:free_send/services/update/update_info.dart';

/// Thrown when a release exists but this platform has no matching asset.
class UpdateNotAvailableException implements Exception {
  const UpdateNotAvailableException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Reads GitHub Releases and pulls the asset for this install.
///
/// Asset names carry a platform word (`android`, `linux`, `windows`,
/// `macos`), a format marker (`(32-bit)`, `(64-bit)`, `(universal)`,
/// `(AppImage)`, `(deb)`, `(rpm)`, `(bundle)`, `(exe)`, `(dmg)`) and, where a
/// platform ships more than one architecture, the architecture word (`x86_64`,
/// `aarch64`).
class UpdateService {
  UpdateService({
    http.Client? client,
    this.repo = 'alibash4/freesend',
    PlatformKind? platform,
    PackageFormat? packageFormat,
  })  : _client = client ?? http.Client(),
        _platform = platform ?? PlatformEnv.kind,
        _packageFormat = packageFormat;

  final http.Client _client;

  /// `owner/name` of the GitHub repository that hosts releases.
  final String repo;

  /// Platform whose assets to look for; injectable so tests can exercise the
  /// Android bitness rules from any host.
  final PlatformKind _platform;

  /// Package this copy was installed from. Null means detect at call time.
  final PackageFormat? _packageFormat;

  PackageFormat get _format => _packageFormat ?? detectPackageFormat();

  static const _apiBase = 'https://api.github.com/repos';

  /// GitHub rejects API calls without a User-Agent.
  static const _headers = {
    'Accept': 'application/vnd.github+json',
    'User-Agent': 'FreeSend-updater',
  };

  /// Timeout for the metadata call. Downloads use their own, longer budget.
  static const _metadataTimeout = Duration(seconds: 15);

  /// Asset suffixes this platform can install.
  static const _assetSuffixes = {
    PlatformKind.android: 'android',
    PlatformKind.linux: 'linux',
    PlatformKind.windows: 'windows',
    PlatformKind.macOS: 'macos',
  };

  String get _platformSuffix => _assetSuffixes[_platform] ?? 'other';

  /// Returns the newest release that has an asset for this platform, or null
  /// when there are no releases at all.
  ///
  /// When [arch] is given, an asset built for that architecture is preferred,
  /// so an arm64 machine does not download the x86_64 build and a 64-bit
  /// Android device does not download the universal APK.
  Future<UpdateInfo?> fetchLatest({String? arch}) async {
    final uri = Uri.parse('$_apiBase/$repo/releases');
    final response =
        await _client.get(uri, headers: _headers).timeout(_metadataTimeout);

    if (response.statusCode != 200) {
      throw HttpException(
        'Release lookup failed (${response.statusCode}).',
        uri: uri,
      );
    }

    final decoded = jsonDecode(response.body);
    if (decoded is! List) return null;

    for (final entry in decoded) {
      if (entry is! Map<String, Object?>) continue;
      final info = _parseRelease(entry, arch);
      if (info != null) return info;
    }
    return null;
  }

  /// Returns the newest release that is newer than [currentVersion], or null
  /// when the app is already up to date.
  Future<UpdateInfo?> checkForUpdate(
    String currentVersion, {
    String? arch,
  }) async {
    final latest = await fetchLatest(arch: arch);
    if (latest == null) return null;
    if (!latest.isNewerThan(currentVersion)) return null;
    return latest;
  }

  UpdateInfo? _parseRelease(Map<String, Object?> release, String? arch) {
    final tag = release['tag_name'];
    if (tag is! String || tag.isEmpty) return null;

    final assets = release['assets'];
    if (assets is! List || assets.isEmpty) return null;

    final candidates = <Map<String, Object?>>[];
    for (final asset in assets) {
      if (asset is! Map<String, Object?>) continue;
      final name = asset['name'];
      final url = asset['browser_download_url'];
      if (name is! String || url is! String) continue;
      if (!_matchesPlatform(name)) continue;
      candidates.add(asset);
    }
    if (candidates.isEmpty) return null;

    final scoped = _platform == PlatformKind.linux
        ? _forArch(candidates, arch)
        : candidates;
    if (scoped.isEmpty) return null;

    final match = _platform == PlatformKind.android
        ? _pickForAbi(scoped, arch)
        : _pickForFormat(scoped);
    final url = match['browser_download_url']! as String;
    final size = match['size'];
    final releasedAt = release['published_at'] ?? release['created_at'];
    final assetName = match['name']! as String;

    return UpdateInfo(
      version: tag.startsWith('v') ? tag.substring(1) : tag,
      changelog: (release['body'] as String?)?.trim() ?? '',
      publishedAt: releasedAt is String ? DateTime.tryParse(releasedAt) : null,
      downloadUrl: url,
      fileName:
          assetName.contains('.') ? assetName : _fileNameFor(assetName, url),
      sizeBytes: size is num ? size.toInt() : 0,
    );
  }

  /// Keeps the assets built for [arch].
  ///
  /// Assets published before the architectures were split carry no marker and
  /// are x86_64 builds, so they still match an x86_64 machine. An arm64
  /// machine never falls back to them: the packages would not run.
  List<Map<String, Object?>> _forArch(
    List<Map<String, Object?>> candidates,
    String? arch,
  ) {
    if (arch == null) return candidates;
    const markers = ['x86_64', 'aarch64', 'armhf'];
    return candidates.where((candidate) {
      final name = candidate['name']! as String;
      final marked = markers.any(name.contains);
      return marked ? name.contains(arch) : arch == 'x86_64';
    }).toList();
  }

  /// Picks the asset for this device: an ABI-specific build when one matches,
  /// otherwise the universal build, which is the asset with no bitness marker.
  Map<String, Object?> _pickForAbi(
    List<Map<String, Object?>> candidates,
    String? abi,
  ) {
    if (candidates.length == 1) return candidates.first;

    final marker = _abiMarker(abi);
    if (marker != null) {
      for (final candidate in candidates) {
        if ((candidate['name']! as String).contains(marker)) return candidate;
      }
    }
    for (final candidate in candidates) {
      final name = candidate['name']! as String;
      if (!name.contains('32-bit') && !name.contains('64-bit')) {
        return candidate;
      }
    }
    return candidates.first;
  }

  /// x86_64 has no split build, so it falls back to the universal APK.
  String? _abiMarker(String? abi) {
    if (abi == null) return null;
    final lower = abi.toLowerCase();
    if (lower.contains('arm64')) return '64-bit';
    if (lower.contains('armeabi') || lower.contains('v7a')) return '32-bit';
    return null;
  }

  /// Prefers the package this install can apply, then the fallbacks in
  /// [formatMarkers].
  Map<String, Object?> _pickForFormat(List<Map<String, Object?>> candidates) {
    if (candidates.length == 1) return candidates.first;
    for (final marker in formatMarkers(_format)) {
      for (final candidate in candidates) {
        final name = (candidate['name']! as String).toLowerCase();
        if (name.contains(marker)) return candidate;
      }
    }
    return candidates.first;
  }

  bool _matchesPlatform(String name) {
    final lower = name.toLowerCase();
    return lower.contains(_platformSuffix);
  }

  /// Falls back to the file name in the download URL when the asset name
  /// carries no extension. GitHub percent-encodes the path, so decode it.
  String _fileNameFor(String name, String url) {
    final path = Uri.tryParse(url)?.pathSegments.lastOrNull;
    if (path != null && path.isNotEmpty && path.contains('.')) {
      try {
        return Uri.decodeComponent(path);
      } on FormatException {
        return path;
      }
    }
    return name;
  }

  /// Downloads [info] to [destination], reporting progress from 0 to 1.
  ///
  /// The file is written to a `.part` path first and renamed on completion, so
  /// an interrupted download never leaves a half-file that looks installed.
  Future<File> download(
    UpdateInfo info,
    String destination, {
    void Function(double progress)? onProgress,
  }) async {
    final part = File('$destination.part');
    final sink = part.openWrite();
    try {
      final request = http.Request('GET', Uri.parse(info.downloadUrl))
        ..followRedirects = true;
      final response =
          await _client.send(request).timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw HttpException(
          'Download failed (${response.statusCode}).',
          uri: Uri.parse(info.downloadUrl),
        );
      }

      final total = response.contentLength ?? info.sizeBytes;
      var received = 0;
      final completer = Completer<void>();

      response.stream.listen(
        (chunk) {
          received += chunk.length;
          sink.add(chunk);
          if (total > 0) onProgress?.call((received / total).clamp(0, 1));
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete();
        },
        onError: (Object error) {
          if (!completer.isCompleted) completer.completeError(error);
        },
        cancelOnError: true,
      );

      await completer.future;
      await sink.flush();
      await sink.close();

      final target = File(destination);
      if (await target.exists()) await target.delete();
      await part.rename(destination);
      onProgress?.call(1);
      return target;
    } catch (_) {
      await sink.close().catchError((_) => sink);
      if (await part.exists()) {
        await part.delete().catchError((_) => part);
      }
      rethrow;
    }
  }

  void dispose() => _client.close();
}

extension _LastOrNull on List<String> {
  String? get lastOrNull => isEmpty ? null : last;
}
