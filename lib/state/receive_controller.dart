import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:free_send/core/app_constants.dart';
import 'package:free_send/models/transfer_item.dart';
import 'package:free_send/models/transfer_record.dart';
import 'package:free_send/services/discovery_service.dart';
import 'package:free_send/services/hotspot/hotspot_permissions.dart';
import 'package:free_send/services/hotspot/hotspot_service.dart';
import 'package:free_send/services/pairing_code.dart';
import 'package:free_send/services/transfer/transfer_client.dart';
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

  ReceivePhase phase = ReceivePhase.idle;
  List<DiscoveredSession> sessions = const [];
  TransferManifest? manifest;
  TransferClient? _client;
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

    final client = TransferClient(
      deviceName: appState.deviceName,
      instanceId: appState.instanceId,
      events: ClientEvents(
        onProgress: _onProgress,
        onStatus: _onStatus,
        onFinished: _onFinished,
        onError: _onError,
      ),
    );
    _client = client;
    try {
      final manifest = await client.connect(ip, port);
      await _scanner.stop();
      this.manifest = manifest;
      receivedItems
        ..clear()
        ..addAll(manifest.items);
      selectedIds
        ..clear()
        ..addAll(manifest.items.map((item) => item.id));
      totalBytes = manifest.totalBytes;
      saveLocation = await appState.store.ensureDownloadDir();
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
    receivedBytes = 0;
    for (final item in receivedItems) {
      item.status = TransferStatus.pending;
    }
    speedBytesPerSecond = 0;
    _stopwatch = Stopwatch()..start();
    _lastSampleAt = null;
    _lastSampleBytes = 0;
    phase = ReceivePhase.transferring;
    notifyListeners();

    try {
      await client.receive(
        ids: selectedIds.toList(growable: false),
        downloadRoot: saveLocation,
      );
    } on Object catch (_) {
      // The client already reported a specific message via events.
      if (phase != ReceivePhase.completed) {
        phase = ReceivePhase.failed;
        errorMessage ??= 'The transfer did not finish.';
      }
      notifyListeners();
    } finally {
      await client.dispose();
      _client = null;
    }
  }

  void _onProgress(TransferItem item, int bytes) {
    currentFileName = item.name;
    item.status = TransferStatus.active;
    receivedBytes = bytes;
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
    unawaited(_record(fileCount, bytes, elapsed, true));
    notifyListeners();
  }

  void _onStatus(TransferItem item) {
    if (item.status == TransferStatus.paused) currentFileName = item.name;
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
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_scanSubscription?.cancel());
    unawaited(_scanner.stop());
    unawaited(_client?.dispose());
    super.dispose();
  }
}
