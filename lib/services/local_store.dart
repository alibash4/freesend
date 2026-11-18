import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:free_send/core/app_constants.dart';
import 'package:free_send/core/platform_env.dart';
import 'package:free_send/models/recent_file.dart';
import 'package:free_send/models/trusted_device.dart';
import 'package:free_send/models/transfer_record.dart';

/// Thin persistence layer over SharedPreferences: settings plus transfer
/// history. No database needed for a few dozen records.
class LocalStore {
  static const _kDeviceName = 'device_name';
  static const _kThemeMode = 'theme_mode';
  static const _kLocale = 'locale';
  static const _kDownloadDir = 'download_dir';
  static const _kHistory = 'history';
  static const _kRecentFiles = 'recent_files';
  static const _kIdentitySeed = 'identity_seed';
  static const _kIdentityKey = 'identity_key';
  static const _kTrustedDevices = 'trusted_devices';
  static const _kAutoUpdate = 'auto_update';
  static const _kMinimizeToTray = 'minimize_to_tray';
  static const _kPermissionsPrompted = 'permissions_prompted';
  static const _kHaptics = 'haptics';
  static const _kHapticIntensity = 'haptic_intensity';

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  String get deviceName {
    final stored = _prefs.getString(_kDeviceName)?.trim();
    if (stored != null && stored.isNotEmpty) return stored;
    final hostname = Platform.localHostname.trim();
    if (hostname.isNotEmpty && hostname != 'localhost') {
      return hostname.length > 24 ? hostname.substring(0, 24) : hostname;
    }
    return '${PlatformEnv.label} device';
  }

  Future<void> setDeviceName(String value) async {
    await _prefs.setString(_kDeviceName, value.trim());
  }

  String? get themeModeName => _prefs.getString(_kThemeMode);

  Future<void> setThemeMode(String value) async {
    await _prefs.setString(_kThemeMode, value);
  }

  String get localeName => _prefs.getString(_kLocale) ?? '';

  Future<void> setLocale(String value) async {
    await _prefs.setString(_kLocale, value);
  }

  String? get storedDownloadDir => _prefs.getString(_kDownloadDir);

  Future<void> setDownloadDir(String path) async {
    await _prefs.setString(_kDownloadDir, path);
  }

  /// Whether the app asks GitLab for a newer release on every launch.
  bool get autoUpdate => _prefs.getBool(_kAutoUpdate) ?? false;

  Future<void> setAutoUpdate(bool value) async {
    await _prefs.setBool(_kAutoUpdate, value);
  }

  /// Whether closing the window keeps the app running in the tray.
  bool get minimizeToTray => _prefs.getBool(_kMinimizeToTray) ?? false;

  Future<void> setMinimizeToTray(bool value) async {
    await _prefs.setBool(_kMinimizeToTray, value);
  }

  /// Whether taps produce a light haptic tick on devices that support it.
  bool get haptics => _prefs.getBool(_kHaptics) ?? true;

  Future<void> setHaptics(bool value) async {
    await _prefs.setBool(_kHaptics, value);
  }

  /// Motor intensity for haptic ticks, 0.0 (light) to 1.0 (heavy).
  double get hapticIntensity =>
      _prefs.getDouble(_kHapticIntensity) ?? 0.5;

  Future<void> setHapticIntensity(double value) async {
    await _prefs.setDouble(_kHapticIntensity, value);
  }

  /// Whether the mobile permission gate has been shown at least once.
  bool get permissionsPrompted => _prefs.getBool(_kPermissionsPrompted) ?? false;

  Future<void> setPermissionsPrompted(bool value) async {
    await _prefs.setBool(_kPermissionsPrompted, value);
  }

  /// Where received files land. Android keeps them inside app-owned storage so
  /// no extra storage permission is needed; desktops use Downloads.
  Future<String> ensureDownloadDir() async {
    final stored = storedDownloadDir;
    if (stored != null && stored.isNotEmpty) {
      final dir = Directory(stored);
      if (!await dir.exists()) {
        try {
          await dir.create(recursive: true);
        } on FileSystemException {
          // Fall through to a fresh default below.
        }
      }
      if (await dir.exists()) return dir.path;
    }
    final defaultDir = await _defaultDownloadDir();
    try {
      await defaultDir.create(recursive: true);
    } on FileSystemException {
      // The OS may veto the exact path; the caller surfaces write errors.
    }
    await setDownloadDir(defaultDir.path);
    return defaultDir.path;
  }

  Future<Directory> _defaultDownloadDir() async {
    if (Platform.isAndroid) {
      final base = await getExternalStorageDirectory() ??
          await getApplicationDocumentsDirectory();
      return Directory('${base.path}${Platform.pathSeparator}FreeSend');
    }
    Directory? downloads;
    try {
      downloads = await getDownloadsDirectory();
    } on Object {
      downloads = null;
    }
    downloads ??= await getApplicationDocumentsDirectory();
    return Directory('${downloads.path}${Platform.pathSeparator}FreeSend');
  }

  List<TransferRecord> get history {
    final raw = _prefs.getStringList(_kHistory) ?? const [];
    final records = <TransferRecord>[];
    for (final entry in raw) {
      try {
        final decoded = jsonDecode(entry);
        if (decoded is Map<String, Object?>) {
          final record = TransferRecord.fromJson(decoded);
          if (record != null) records.add(record);
        }
      } on FormatException {
        // Skip corrupt entries rather than losing the whole history.
      }
    }
    records.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return records;
  }

  Future<void> addRecord(TransferRecord record) async {
    final all = [record, ...history].take(AppConstants.maxHistoryEntries);
    await _prefs.setStringList(
      _kHistory,
      [for (final item in all) jsonEncode(item.toJson())],
    );
  }

  Future<void> clearHistory() async {
    await _prefs.remove(_kHistory);
  }

  /// Recently picked files, newest first. Used by the send screen so a repeat
  /// transfer can start without walking the system picker again.
  List<RecentFile> get recentFiles {
    final raw = _prefs.getStringList(_kRecentFiles) ?? const [];
    final records = <RecentFile>[];
    for (final entry in raw) {
      try {
        final decoded = jsonDecode(entry);
        if (decoded is Map<String, Object?>) {
          final record = RecentFile.fromJson(decoded);
          if (record != null) records.add(record);
        }
      } on FormatException {
        // Skip a corrupt entry.
      }
    }
    records.sort((a, b) => b.addedAt.compareTo(a.addedAt));
    return records;
  }

  String? get deviceIdentitySeed => _prefs.getString(_kIdentitySeed);
  String? get deviceIdentityKey => _prefs.getString(_kIdentityKey);

  Future<void> saveDeviceIdentity({
    required String seed,
    required String publicKey,
  }) async {
    await _prefs.setString(_kIdentitySeed, seed);
    await _prefs.setString(_kIdentityKey, publicKey);
  }

  List<TrustedDevice> get trustedDevices {
    final raw = _prefs.getStringList(_kTrustedDevices) ?? const [];
    final devices = <TrustedDevice>[];
    for (final entry in raw) {
      try {
        final decoded = jsonDecode(entry);
        if (decoded is Map<String, Object?>) {
          final device = TrustedDevice.fromJson(decoded);
          if (device != null) devices.add(device);
        }
      } on FormatException {
        // Skip a corrupt entry.
      }
    }
    devices.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return devices;
  }

  Future<void> trustDevice(TrustedDevice device) async {
    final all = [device, ...trustedDevices];
    final byId = <String, TrustedDevice>{};
    for (final entry in all) byId[entry.instanceId] = entry;
    await _prefs.setStringList(
      _kTrustedDevices,
      [for (final entry in byId.values) jsonEncode(entry.toJson())],
    );
  }

  Future<void> forgetDevice(String instanceId) async {
    final remaining = trustedDevices
        .where((device) => device.instanceId != instanceId)
        .toList(growable: false);
    await _prefs.setStringList(
      _kTrustedDevices,
      [for (final device in remaining) jsonEncode(device.toJson())],
    );
  }

  Future<void> addRecentFiles(Iterable<File> files) async {
    final byPath = {for (final record in recentFiles) record.path: record};
    for (final file in files) {
      final record = RecentFile.fromFile(file);
      if (record != null) byPath[record.path] = record;
    }
    final all = byPath.values.toList()
      ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    await _prefs.setStringList(
      _kRecentFiles,
      [
        for (final record in all.take(AppConstants.maxRecentFiles))
          jsonEncode(record.toJson()),
      ],
    );
  }
}
