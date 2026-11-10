import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

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
  List<TransferRecord> history = const [];

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
    history = store.history;
    _ready = true;
    notifyListeners();
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
