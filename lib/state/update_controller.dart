import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'package:free_send/core/app_constants.dart';
import 'package:free_send/l10n/app_localizations.dart';

import 'package:free_send/services/update/update_info.dart';
import 'package:free_send/services/update/update_installer.dart';
import 'package:free_send/services/update/update_service.dart';

enum UpdatePhase {
  /// Nothing happening.
  idle,

  /// Asking GitLab what the latest release is.
  checking,

  /// A newer release is available and waiting for the user's decision.
  available,

  /// Pulling the asset down.
  downloading,

  /// Download complete; ready to hand to the OS installer.
  readyToInstall,

  /// The OS installer is showing.
  installing,

  /// The app is current.
  upToDate,

  /// Something failed; [UpdateController.message] explains it.
  failed,
}

/// Owns the whole update flow: check, download, install.
///
/// The UI observes [phase] and renders the sheet; nothing else in the app
/// touches releases.
class UpdateController extends ChangeNotifier {
  UpdateController({
    UpdateService? service,
    UpdateInstaller? installer,
    String? initialVersion,
  })  : _service = service ?? UpdateService(),
        _installer = installer ?? UpdateInstaller(),
        _currentVersion = initialVersion ?? '';

  final UpdateService _service;
  final UpdateInstaller _installer;

  UpdatePhase phase = UpdatePhase.idle;
  UpdateInfo? update;
  String? message;

  /// Localization key for [message]: 'upToDate' or 'failed'.
  String messageKey = '';

  /// 0–1 while [UpdatePhase.downloading].
  double progress = 0;

  File? downloadedFile;

  String _currentVersion = '';
  String get currentVersion => _currentVersion;

  bool _autoCheck = false;
  bool get autoCheck => _autoCheck;

  /// Loads the app version once; safe to call repeatedly.
  Future<void> load() async {
    if (_currentVersion.isNotEmpty) return;
    _currentVersion = AppConstants.appVersion;
    notifyListeners();
  }

  void setAutoCheck(bool value) {
    _autoCheck = value;
    notifyListeners();
  }

  /// Silent check used on startup. Only notifies when there is something to
  /// show, so a failure or an up-to-date app stays quiet.
  Future<bool> checkSilently() async {
    await load();
    if (!_autoCheck) return false;
    return _check(notifyWhenCurrent: false);
  }

  /// Manual "Check for updates" from Settings: always reports the outcome.
  Future<void> checkManually() async {
    await load();
    await _check(notifyWhenCurrent: true);
  }

  Future<bool> _check({required bool notifyWhenCurrent}) async {
    phase = UpdatePhase.checking;
    message = null;
    notifyListeners();
    try {
      // Ask the OS which architecture to fetch: Android ships per-ABI builds,
      // Linux per-architecture ones.
      final arch = await _installer.currentArch();
      final latest = await _service.checkForUpdate(_currentVersion, arch: arch);
      update = latest;
      if (latest == null) {
        phase = notifyWhenCurrent ? UpdatePhase.upToDate : UpdatePhase.idle;
        messageKey = notifyWhenCurrent ? 'upToDate' : '';
        message = null;
        notifyListeners();
        return false;
      }
      phase = UpdatePhase.available;
      notifyListeners();
      return true;
    } on Object catch (error) {
      phase = UpdatePhase.failed;
      messageKey = 'failed';
      message = _describe(error);
      notifyListeners();
      return false;
    }
  }

  /// Downloads the pending update to the app's cache directory.
  Future<void> download() async {
    final info = update;
    if (info == null) return;

    phase = UpdatePhase.downloading;
    progress = 0;
    message = null;
    notifyListeners();

    try {
      final dir = Directory.systemTemp.createTempSync('freesend_update');
      final destination = '${dir.path}${Platform.pathSeparator}'
          '${info.fileName.isEmpty ? 'freesend-update.bin' : info.fileName}';
      final file = await _service.download(
        info,
        destination,
        onProgress: (value) {
          progress = value;
          notifyListeners();
        },
      );
      downloadedFile = file;
      phase = UpdatePhase.readyToInstall;
      notifyListeners();
    } on Object catch (error) {
      phase = UpdatePhase.failed;
      messageKey = 'failed';
      message = _describe(error);
      notifyListeners();
    }
  }

  /// Hands the downloaded file to the OS installer and exits the app.
  Future<void> install() async {
    final file = downloadedFile;
    final info = update;
    if (file == null || info == null) return;

    phase = UpdatePhase.installing;
    notifyListeners();
    try {
      await _installer.install(file, version: info.version);
      // The installer is a separate task; leaving the app now keeps the old
      // code from running while it is replaced underneath us.
      await SystemNavigator.pop();
    } on Object catch (error) {
      phase = UpdatePhase.failed;
      messageKey = 'failed';
      message = _describe(error);
      notifyListeners();
    }
  }

  void dismiss() {
    // Keep a finished download so a dismissed sheet can be reopened without
    // pulling the asset again.
    if (phase != UpdatePhase.downloading && phase != UpdatePhase.installing) {
      phase = UpdatePhase.idle;
      message = null;
      messageKey = '';
      notifyListeners();
    }
  }

  void reset() {
    phase = UpdatePhase.idle;
    update = null;
    message = null;
    messageKey = '';
    progress = 0;
    downloadedFile = null;
    notifyListeners();
  }

  /// Localized text for the status line under the update buttons.
  String localizedMessage(AppLocalizations l10n) => switch (messageKey) {
        'upToDate' => l10n.updateUpToDate,
        'failed' => message == null || message!.isEmpty
            ? l10n.updateFailed
            : '${l10n.updateFailed}: $message',
        _ => message ?? '',
      };

  String _describe(Object error) => switch (error) {
        UpdateNotAvailableException(:final message) => message,
        HttpException(:final message) => message,
        _ => 'Update failed: $error',
      };

  @override
  void dispose() {
    _service.dispose();
    super.dispose();
  }
}
