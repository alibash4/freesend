import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:free_send/core/app_constants.dart';
import 'package:free_send/core/format.dart';
import 'package:free_send/models/transfer_item.dart';
import 'package:free_send/models/transfer_record.dart';
import 'package:free_send/services/discovery_service.dart';
import 'package:free_send/services/hotspot/hotspot_permissions.dart';
import 'package:free_send/services/hotspot/hotspot_service.dart';
import 'package:free_send/services/pairing_code.dart';
import 'package:free_send/services/transfer/transfer_client.dart';
import 'package:free_send/services/transfer/transfer_foreground.dart';
import 'package:free_send/services/transfer/transfer_recovery.dart';
import 'package:free_send/state/app_state.dart';

enum ReceivePhase {
  idle,
  scanning,
  joining,
  reviewing,
  transferring,
  completed,
  failed,
  cancelled,
}

/// Drives the receiving side: find a session on the hotspot, review the offer,
/// then pull the selected files to disk.
class ReceiveController extends ChangeNotifier {
  ReceiveController({required this.appState, HotspotService? hotspotService})
      : _hotspotService = hotspotService ?? createHotspotService();

  final AppState appState;
  final HotspotService _hotspotService;
  final SessionScanner _scanner = SessionScanner();
  final TransferForeground _foreground = TransferForeground();

  ReceivePhase phase = ReceivePhase.idle;
  List<DiscoveredSession> sessions = const [];
  TransferManifest? manifest;
  TransferClient? _client;
  String? _host;
  int? _port;
  StreamSubscription<List<DiscoveredSession>>? _scanSubscription;

  String? errorMessage;
  String? connectingTo;
  String? hotspotNotice;

  final selectedIds = <String>{};
  final List<TransferItem> receivedItems = [];

  int totalBytes = 0;
  int receivedBytes = 0;
  double speedBytesPerSecond = 0;
  String? currentFileName;
  String saveLocation = '';

  TransferRecovery? _recovery;
  final Map<String, RecoveryEntry> _recoveryEntries = {};
  final Map<String, int> resumeOffsets = {};
  final Map<String, String> resumePaths = {};
  bool _savingRecovery = false;
  bool _recoveryDone = false;
  DateTime _lastRecoverySave = DateTime.fromMillisecondsSinceEpoch(0);
  int _lastRecoveryBytes = 0;

  Stopwatch? _stopwatch;
  DateTime? _lastSampleAt;
  int _lastSampleBytes = 0;
  TransferRecord? lastRecord;

  bool get isJoining => phase == ReceivePhase.joining;
  bool get isPaused => receivedItems.any(
        (item) => item.status == TransferStatus.paused && !item.done,
      );
  /// The receiver asked for the stream to stop. Distinct from a sender pause,
  /// which arrives as a frame while the socket is still being read.
  bool pausedByMe = false;
  bool get anyPaused => pausedByMe || isPaused;
  bool get canResume => resumeOffsets.isNotEmpty;
  int get resumedBytes =>
      resumeOffsets.values.fold<int>(0, (sum, value) => sum + value);
  bool get canJoinHotspot => _hotspotService.canJoin;
  bool get isScanning => _scanner.isScanning;

  int get selectedBytes => manifest == null
      ? 0
      : manifest!.items
          .where((item) => selectedIds.contains(item.id))
          .fold<int>(0, (sum, item) => sum + item.size);

  double get overallProgress {
    if (phase == ReceivePhase.completed) return 1;
    if (totalBytes <= 0) return 0;
    return (receivedBytes / totalBytes).clamp(0, 1);
  }

  Future<void> startScanning() async {
    if (_scanner.isScanning) return;
    final ok = await _scanner.start(ownInstanceId: appState.instanceId);
    _scanSubscription ??= _scanner.sessions.listen((list) {
      sessions = list;
      notifyListeners();
    });
    if (!ok) {
      errorMessage =
          'Discovery could not start. You can still connect by IP address.';
    }
    phase = ReceivePhase.scanning;
    notifyListeners();
  }

  Future<void> stopScanning() async {
    await _scanner.stop();
    sessions = const [];
    notifyListeners();
  }

  /// Joins the host's hotspot (Android/Linux/macOS) and then looks for it.
  Future<void> joinHotspot(String ssid, String password) async {
    if (ssid.trim().isEmpty) return;
    phase = ReceivePhase.joining;
    errorMessage = null;
    hotspotNotice = null;
    notifyListeners();
    try {
      // The user may reach this screen without having sent anything first, so
      // the permission cannot be assumed to be granted yet.
      await ensureHotspotPermissions();
      final info = await _hotspotService.join(ssid.trim(), password);
      hotspotNotice = info.note ??
          'Connected to "${info.ssid}". Looking for the sharing device…';
      await startScanning();
      phase = ReceivePhase.scanning;
    } on HotspotException catch (error) {
      errorMessage = error.message;
      phase = ReceivePhase.failed;
    } on Object catch (error) {
      errorMessage = 'Could not join the hotspot: $error';
      phase = ReceivePhase.failed;
    }
    notifyListeners();
  }

  /// Applies a scanned or pasted pairing code: join the hotspot it names, then
  /// connect straight to the sender's address instead of waiting for a beacon.
  Future<void> pairWith(PairingCode code) async {
    if (phase == ReceivePhase.transferring || !code.isUsable) return;
    phase = ReceivePhase.joining;
    errorMessage = null;
    hotspotNotice = null;
    connectingTo = code.label;
    notifyListeners();

    try {
      if (code.hasHotspot && canJoinHotspot) {
        await ensureHotspotPermissions();
        final info = await _hotspotService.join(code.ssid!, code.password);
        hotspotNotice = info.note ?? 'Joined "${code.ssid}".';
      } else if (code.hasHotspot) {
        // Windows cannot join a hotspot on the user's behalf, so it falls back
        // to the system Wi-Fi menu and then finds the session by discovery.
        hotspotNotice =
            'Join "${code.ssid}" from your Wi-Fi menu. The session appears here '
            'as soon as you are connected.';
      }

      final host = code.host;
      if (host == null || (code.hasHotspot && !canJoinHotspot)) {
        await startScanning();
        phase = ReceivePhase.scanning;
        notifyListeners();
        return;
      }
      await connectToAddress(host, code.port, label: code.label);
    } on HotspotException catch (error) {
      errorMessage = error.message;
      phase = ReceivePhase.failed;
      notifyListeners();
    }
  }

  TransferClient _newClient() => TransferClient(
        deviceName: appState.deviceName,
        instanceId: appState.instanceId,
        events: ClientEvents(
          onProgress: _onProgress,
          onStatus: _onStatus,
          onFinished: _onFinished,
          onError: _onError,
        ),
      );

  Future<void> connectToSession(DiscoveredSession session) async {
    await connectToAddress(session.ip, session.port, label: session.deviceName);
  }

  Future<void> connectToAddress(
    String ip,
    int port, {
    String? label,
  }) async {
    if (phase == ReceivePhase.transferring) return;
    phase = ReceivePhase.joining;
    connectingTo = label ?? '$ip:$port';
    errorMessage = null;
    notifyListeners();

    final client = _newClient();
    _client = client;
    try {
      final manifest = await client.connect(ip, port);
      await _scanner.stop();
      _host = ip;
      _port = port;
      this.manifest = manifest;
      receivedItems
        ..clear()
        ..addAll(manifest.items);
      selectedIds
        ..clear()
        ..addAll(manifest.items.map((item) => item.id));
      totalBytes = manifest.totalBytes;
      saveLocation = await appState.store.ensureDownloadDir();
      await _loadRecovery();
      phase = ReceivePhase.reviewing;
    } on SocketException {
      errorMessage =
          'Could not reach $ip:$port. Make sure both devices are on the same '
          'hotspot.';
      phase = ReceivePhase.failed;
      await client.dispose();
      _client = null;
    } on Object catch (error) {
      errorMessage = _describe(error);
      phase = ReceivePhase.failed;
      await client.dispose();
      _client = null;
    }
    notifyListeners();
  }

  void toggleSelection(String id) {
    if (selectedIds.contains(id)) {
      selectedIds.remove(id);
    } else {
      selectedIds.add(id);
    }
    notifyListeners();
  }

  void selectAll({required bool value}) {
    final items = manifest?.items ?? const <TransferItem>[];
    selectedIds.clear();
    if (value) {
      selectedIds.addAll(items.map((item) => item.id));
    }
    notifyListeners();
  }

  Future<void> beginReceive() async {
    final client = _client;
    final manifest = this.manifest;
    if (client == null || manifest == null || selectedIds.isEmpty) return;
    pausedByMe = false;
    totalBytes = selectedBytes;

    // Only offsets that still have a matching file on disk can be resumed.
    final resume = <String, int>{};
    for (final id in selectedIds) {
      final offset = resumeOffsets[id];
      final path = resumePaths[id];
      if (offset == null || path == null || offset <= 0) continue;
      final file = File(path);
      try {
        if (await file.exists() && await file.length() >= offset) {
          resume[id] = offset;
        }
      } on Object {
        // Treat an unreadable partial as absent.
      }
    }
    final resumePathMap = <String, String>{
      for (final id in resume.keys) id: resumePaths[id]!,
    };
    final baseBytes = resume.values.fold<int>(0, (sum, value) => sum + value);

    for (final item in receivedItems) {
      if (!selectedIds.contains(item.id)) continue;
      item.done = false;
      item.status = TransferStatus.pending;
      final offset = resume[item.id];
      if (offset != null) {
        item.transferred = offset;
        item.receivedPath = resumePathMap[item.id];
      } else {
        item.transferred = 0;
      }
    }
    receivedBytes = baseBytes;
    speedBytesPerSecond = 0;
    _stopwatch = Stopwatch()..start();
    _lastSampleAt = null;
    _lastSampleBytes = receivedBytes;
    _lastRecoverySave = DateTime.fromMillisecondsSinceEpoch(0);
    _lastRecoveryBytes = receivedBytes;
    _recoveryDone = false;
    _recovery ??= TransferRecovery(saveLocation);
    phase = ReceivePhase.transferring;
    await _foreground.start(
      title: 'Receiving files',
      text: '${selectedIds.length} file${selectedIds.length == 1 ? '' : 's'} · ${formatBytes(totalBytes)}',
    );
    notifyListeners();

    try {
      await client.receive(
        ids: selectedIds.toList(growable: false),
        downloadRoot: saveLocation,
        resumePaths: resumePathMap,
        resumeOffsets: resume,
        baseBytes: baseBytes,
      );
    } on Object catch (_) {
      // The client already reported a specific message via events.
      if (phase != ReceivePhase.completed) {
        phase = ReceivePhase.failed;
        errorMessage ??= 'The transfer did not finish.';
      }
      notifyListeners();
    } finally {
      await _saveRecovery();
      await client.dispose();
      _client = null;
    }
  }

  Future<void> _loadRecovery() async {
    resumeOffsets.clear();
    resumePaths.clear();
    _recoveryEntries.clear();
    _recovery = TransferRecovery(saveLocation);
    final entries = await _recovery!.load();
    _recoveryEntries.addAll(entries);
    for (final item in receivedItems) {
      final entry = entries[item.id];
      if (entry == null || entry.size != item.size) continue;
      final file = File(entry.path);
      try {
        if (!await file.exists()) continue;
        final length = await file.length();
        if (length <= 0 || length >= item.size) continue;
        resumeOffsets[item.id] = length;
        resumePaths[item.id] = file.path;
        item.transferred = length;
        item.receivedPath = file.path;
        item.status = TransferStatus.pending;
      } on Object {
        // A stale sidecar entry is ignored rather than trusted.
      }
    }
    notifyListeners();
  }

  Future<void> _saveRecovery() async {
    final recovery = _recovery;
    if (recovery == null || _recoveryDone || _savingRecovery) return;
    _savingRecovery = true;
    try {
      await recovery.save(_recoveryEntries.values);
    } finally {
      _savingRecovery = false;
    }
  }

  void _trackRecovery(TransferItem item) {
    final path = item.receivedPath;
    if (path == null || item.transferred <= 0) return;
    _recoveryEntries[item.id] = RecoveryEntry(
      id: item.id,
      name: item.name,
      size: item.size,
      path: path,
      offset: item.transferred,
      relativePath: item.relativePath,
    );
  }

  Future<void> _finishRecovery() async {
    while (_savingRecovery) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    await _recovery?.clear();
  }

  void _maybeSaveRecovery() {
    final now = DateTime.now();
    final elapsed = now.difference(_lastRecoverySave).inMilliseconds;
    final moved = (receivedBytes - _lastRecoveryBytes).abs();
    if (elapsed < 1000 && moved < 1024 * 1024) return;
    _lastRecoverySave = now;
    _lastRecoveryBytes = receivedBytes;
    unawaited(_saveRecovery());
  }

  /// Reconnects to the last host and asks only for the files that did not
  /// finish. Partial files are truncated and written again from byte zero.
  Future<void> retryFailed() async {
    final host = _host;
    final port = _port;
    if (host == null || port == null || phase == ReceivePhase.transferring) {
      return;
    }
    final failed = receivedItems
        .where((item) => !item.done && selectedIds.contains(item.id))
        .toList(growable: false);
    if (failed.isEmpty) return;

    final retryIds = {for (final item in failed) item.id};
    final retryPaths = <String, String>{
      for (final item in failed)
        if (item.receivedPath != null) item.id: item.receivedPath!,
    };
    final doneBytes = receivedItems
        .where((item) => item.done && selectedIds.contains(item.id))
        .fold<int>(0, (sum, item) => sum + item.size);

    for (final item in failed) {
      item.transferred = 0;
      item.done = false;
      item.status = TransferStatus.pending;
      resumeOffsets.remove(item.id);
      resumePaths.remove(item.id);
      _recoveryEntries.remove(item.id);
    }
    _recoveryDone = false;
    _recovery ??= TransferRecovery(saveLocation);
    receivedBytes = doneBytes;
    totalBytes = selectedBytes;
    errorMessage = null;
    pausedByMe = false;
    phase = ReceivePhase.joining;
    notifyListeners();

    final client = _newClient();
    _client = client;
    try {
      final manifest = await client.connect(host, port);
      this.manifest = manifest;
      // Keep the objects the UI already knows about; the host may have added
      // files since the first attempt, but a retry must not reset the progress
      // of the ones that already succeeded.
      final byId = {for (final item in receivedItems) item.id: item};
      receivedItems
        ..clear()
        ..addAll(manifest.items.map((item) => byId[item.id] ?? item));
      _stopwatch = Stopwatch()..start();
      _lastSampleAt = null;
      _lastSampleBytes = receivedBytes;
      phase = ReceivePhase.transferring;
      await _foreground.start(
        title: 'Retrying transfer',
        text: '${retryIds.length} file${retryIds.length == 1 ? '' : 's'} failed earlier',
      );
      notifyListeners();
      await client.receive(
        ids: retryIds.toList(growable: false),
        downloadRoot: saveLocation,
        retryPaths: retryPaths,
        baseBytes: doneBytes,
      );
    } on SocketException {
      errorMessage = 'Could not reach $host:$port. Make sure both devices are '
          'on the same hotspot.';
      phase = ReceivePhase.failed;
    } on Object catch (error) {
      if (phase != ReceivePhase.completed) {
        errorMessage ??= _describe(error);
        phase = ReceivePhase.failed;
      }
    }
    await client.dispose();
    _client = null;
    notifyListeners();
  }

  TransferItem? _trackedItem(TransferItem item) {
    for (final candidate in receivedItems) {
      if (candidate.id == item.id) return candidate;
    }
    return null;
  }

  void _mergeItem(TransferItem item) {
    final tracked = _trackedItem(item);
    if (tracked == null) {
      receivedItems.add(item);
      _trackRecovery(item);
      return;
    }
    tracked.transferred = item.transferred;
    tracked.status = item.status;
    tracked.done = item.done;
    tracked.receivedPath ??= item.receivedPath;
    tracked.sha256 ??= item.sha256;
    _trackRecovery(tracked);
  }

  void _onProgress(TransferItem item, int bytes) {
    _mergeItem(item);
    currentFileName = item.name;
    receivedBytes = bytes;
    unawaited(_foreground.update(
      title: 'Receiving ${formatBytes(receivedBytes)} of ${formatBytes(totalBytes)}',
      text: currentFileName,
    ));
    _maybeSaveRecovery();
    _sampleSpeed();
    notifyListeners();
  }

  void _sampleSpeed() {
    final now = DateTime.now();
    final last = _lastSampleAt;
    if (last == null) {
      _lastSampleAt = now;
      _lastSampleBytes = receivedBytes;
      return;
    }
    final elapsed = now.difference(last).inMilliseconds;
    if (elapsed < AppConstants.progressInterval.inMilliseconds) return;
    final instant = (receivedBytes - _lastSampleBytes) / (elapsed / 1000);
    speedBytesPerSecond =
        speedBytesPerSecond == 0 ? instant : speedBytesPerSecond * 0.7 + instant * 0.3;
    _lastSampleAt = now;
    _lastSampleBytes = receivedBytes;
  }

  void _onFinished(int fileCount, int bytes, Duration elapsed) {
    _stopwatch?.stop();
    for (final item in receivedItems) {
      if (selectedIds.contains(item.id) && item.transferred >= item.size) {
        item.done = true;
        item.status = TransferStatus.done;
      }
    }
    receivedBytes = bytes;
    totalBytes = totalBytes == 0 ? bytes : totalBytes;
    phase = ReceivePhase.completed;
    unawaited(_foreground.stop());
    _recoveryDone = true;
    _recoveryEntries.clear();
    resumeOffsets.clear();
    resumePaths.clear();
    unawaited(_finishRecovery());
    unawaited(_record(fileCount, bytes, elapsed, true));
    notifyListeners();
  }

  void _onStatus(TransferItem item) {
    _mergeItem(item);
    if (item.status == TransferStatus.done) {
      _recoveryEntries.remove(item.id);
      resumeOffsets.remove(item.id);
      resumePaths.remove(item.id);
    }
    if (item.status == TransferStatus.paused) currentFileName = item.name;
    if (item.status == TransferStatus.done ||
        item.status == TransferStatus.paused) {
      unawaited(_saveRecovery());
    }
    notifyListeners();
  }

  /// Pauses the live stream from the receiving side by stopping socket reads.
  Future<void> pause() async {
    if (phase != ReceivePhase.transferring || pausedByMe) return;
    final client = _client;
    if (client == null) return;
    pausedByMe = true;
    speedBytesPerSecond = 0;
    for (final item in receivedItems) {
      if (item.status == TransferStatus.active) {
        item.status = TransferStatus.paused;
      }
    }
    await client.pause();
    notifyListeners();
  }

  Future<void> resume() async {
    if (!pausedByMe) return;
    pausedByMe = false;
    _lastSampleAt = null;
    _lastSampleBytes = receivedBytes;
    for (final item in receivedItems) {
      if (item.status == TransferStatus.paused && !item.done) {
        item.status = TransferStatus.active;
      }
    }
    await _client?.resume();
    notifyListeners();
  }

  void _onError(String message) {
    if (phase == ReceivePhase.completed) return;
    for (final item in receivedItems) {
      if (!item.done) item.status = TransferStatus.failed;
    }
    errorMessage = message;
    phase = ReceivePhase.failed;
    unawaited(_foreground.stop());
    unawaited(_saveRecovery());
    notifyListeners();
  }

  Future<void> _record(
    int files,
    int bytes,
    Duration duration,
    bool ok,
  ) async {
    final record = TransferRecord(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      direction: TransferDirection.receive,
      peerName: manifest?.hostName ?? 'Nearby device',
      peerPlatform: manifest?.hostPlatform,
      fileCount: files,
      bytes: bytes,
      timestamp: DateTime.now(),
      durationMs: duration.inMilliseconds,
      succeeded: ok,
    );
    lastRecord = record;
    await appState.recordTransfer(record);
  }

  String _describe(Object error) {
    final text = error.toString();
    return text.startsWith('Exception: ') ? text.substring(11) : text;
  }

  Future<void> cancel() async {
    if (phase == ReceivePhase.transferring) {
      final bytes = receivedBytes;
      final files = receivedItems.where((item) => item.done).length;
      pausedByMe = false;
      unawaited(_foreground.stop());
      await _saveRecovery();
      await _client?.cancel();
      _client = null;
      phase = ReceivePhase.cancelled;
      notifyListeners();
      if (bytes > 0) {
        await _record(
          files,
          bytes,
          _stopwatch?.elapsed ?? Duration.zero,
          false,
        );
      }
    } else if (phase == ReceivePhase.reviewing) {
      await _client?.dispose();
      _client = null;
      manifest = null;
      receivedItems.clear();
      selectedIds.clear();
      phase = ReceivePhase.scanning;
      await startScanning();
    }
    notifyListeners();
  }

  Future<void> reset() async {
    await _client?.dispose();
    _client = null;
    manifest = null;
    receivedItems.clear();
    selectedIds.clear();
    errorMessage = null;
    currentFileName = null;
    pausedByMe = false;
    receivedBytes = 0;
    totalBytes = 0;
    speedBytesPerSecond = 0;
    hotspotNotice = null;
    for (final item in receivedItems) {
      item.transferred = 0;
      item.done = false;
      item.status = TransferStatus.pending;
    }
    phase = ReceivePhase.idle;
    unawaited(_foreground.stop());
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_scanSubscription?.cancel());
    unawaited(_scanner.stop());
    unawaited(_foreground.stop());
    unawaited(_saveRecovery());
    unawaited(_client?.dispose());
    super.dispose();
  }
}
