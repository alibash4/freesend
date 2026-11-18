import 'dart:io';
import 'dart:math';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'package:free_send/models/transfer_record.dart';
import 'package:free_send/services/local_store.dart';

/// Settings, history and the per-launch instance id shared by both transfer
/// directions.
class AppState extends ChangeNotifier {
  AppState(this.store);

  final LocalStore store;

  late String deviceName;
  String downloadDir = '';
  ThemeMode themeMode = ThemeMode.system;
  Locale locale = const Locale('en');
  List<TransferRecord> history = const [];

  /// Whether to look for a newer release on launch.
  bool autoUpdate = false;

  /// Whether closing the window hides it to the tray instead of quitting.
  bool minimizeToTray = false;

  /// Whether the mobile permission gate has already been shown.
  bool permissionsPrompted = false;

  /// Whether taps produce a light haptic tick on devices that support it.
  bool haptics = true;

  /// Motor intensity for haptic ticks, 0.0 (subtle) to 1.0 (heavy).
  double hapticIntensity = 0.5;

  /// Whether the dark theme uses the softened near-black variant. Only
  /// meaningful while the effective theme is dark.
  bool blackTheme = false;

  /// Identifies this app run so the scanner ignores its own beacons.
  final String instanceId = _randomId(12);

  bool _ready = false;
  bool get isReady => _ready;

  Future<void> init() async {
    await store.init();
    deviceName = store.deviceName;
    try {
      downloadDir = await store.ensureDownloadDir();
    } on Object {
      // Some platforms cannot resolve a Downloads folder; fall back to a
      // writable temp location instead of refusing to start.
      downloadDir = Directory.systemTemp.path;
    }
    themeMode = switch (store.themeModeName) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    locale = switch (store.localeName) {
      'en' => const Locale('en'),
      'ar' => const Locale('ar'),
      // Never chosen: follow the device language, English otherwise.
      _ => PlatformDispatcher.instance.locale.languageCode == 'ar'
          ? const Locale('ar')
          : const Locale('en'),
    };
    history = store.history;
    autoUpdate = store.autoUpdate;
    minimizeToTray = store.minimizeToTray;
    permissionsPrompted = store.permissionsPrompted;
    haptics = store.haptics;
    hapticIntensity = store.hapticIntensity;
    blackTheme = store.blackTheme;
    _ready = true;
    notifyListeners();
  }

  Future<void> setAutoUpdate(bool value) async {
    autoUpdate = value;
    notifyListeners();
    await store.setAutoUpdate(value);
  }

  Future<void> setMinimizeToTray(bool value) async {
    minimizeToTray = value;
    notifyListeners();
    await store.setMinimizeToTray(value);
  }

  Future<void> setHaptics(bool value) async {
    haptics = value;
    notifyListeners();
    await store.setHaptics(value);
  }

  Future<void> setHapticIntensity(double value) async {
    hapticIntensity = value;
    notifyListeners();
    await store.setHapticIntensity(value);
  }

  Future<void> setBlackTheme(bool value) async {
    blackTheme = value;
    notifyListeners();
    await store.setBlackTheme(value);
  }

  /// True when the resolved theme is a dark variant, including system mode
  /// on a dark platform. Drives whether the black variant can apply.
  bool get effectiveDark =>
      themeMode == ThemeMode.dark ||
      (themeMode == ThemeMode.system &&
          PlatformDispatcher.instance.platformBrightness == Brightness.dark);

  /// Fires the configured haptic tick when feedback is enabled. Flutter
  /// exposes no motor amplitude and most devices render the softer impacts
  /// identically, so intensity is an honest two-step choice.
  void tick() {
    if (!haptics) return;
    if (hapticIntensity < 0.5) {
      HapticFeedback.lightImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
  }

  Future<void> setPermissionsPrompted(bool value) async {
    permissionsPrompted = value;
    notifyListeners();
    await store.setPermissionsPrompted(value);
  }

  Future<void> setDeviceName(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == deviceName) return;
    deviceName = trimmed;
    notifyListeners();
    await store.setDeviceName(trimmed);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    themeMode = mode;
    notifyListeners();
    await store.setThemeMode(mode.name);
  }

  Future<void> setLocale(Locale value) async {
    locale = value;
    notifyListeners();
    await store.setLocale(value.languageCode);
  }

  Future<void> setDownloadDir(String path) async {
    downloadDir = path;
    notifyListeners();
    await store.setDownloadDir(path);
  }

  Future<void> recordTransfer(TransferRecord record) async {
    history = [record, ...history].take(60).toList();
    notifyListeners();
    await store.addRecord(record);
  }

  Future<void> clearHistory() async {
    history = const [];
    notifyListeners();
    await store.clearHistory();
  }

  static String _randomId(int length) {
    const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return String.fromCharCodes(
      List.generate(
        length,
        (_) => alphabet.codeUnitAt(random.nextInt(alphabet.length)),
      ),
    );
  }
}
