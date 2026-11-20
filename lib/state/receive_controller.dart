import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:free_send/l10n/app_localizations.dart';
import 'package:free_send/services/app_logger.dart';
import 'package:free_send/core/app_constants.dart';
import 'package:free_send/core/format.dart';
import 'package:free_send/core/platform_env.dart';
import 'package:free_send/core/transfer_flow.dart';
import 'package:free_send/models/transfer_item.dart';
import 'package:free_send/models/transfer_record.dart';
import 'package:free_send/services/discovery_service.dart';
import 'package:free_send/services/hotspot/hotspot_permissions.dart';
import 'package:free_send/services/hotspot/hotspot_service.dart';
import 'package:free_send/services/pairing_code.dart';
import 'package:free_send/services/transfer/doorbell.dart';
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

  /// Strings for messages this controller produces; resolved at call time so
  /// a locale change applies to the next message, not just the next rebuild.
  AppLocalizations get _l10n => lookupAppLocalizations(appState.locale);
  final SessionScanner _scanner = SessionScanner();
  final TransferForeground _foreground = TransferForeground();

  ReceivePhase phase = ReceivePhase.idle;
  List<DiscoveredSession> sessions = const [];
  TransferManifest? manifest;
  TransferClient? _client;
  String? _host;
  int? _port;
  StreamSubscription<List<DiscoveredSession>>? _scanSubscription;

  // Receiving-side presence: the doorbell answers senders, and the responder
  // tells seekers this device is waiting.
  final ConsentDoorbell _doorbell = ConsentDoorbell();
  final PresenceResponder _responder = PresenceResponder();
  final StreamController<Knock> _knocks = StreamController<Knock>.broadcast();

  /// What the waiting screen should show.
  ReceiverPresence presence = ReceiverPresence.idle;

  /// Set on desktops when a VPN is attached; advisory only, the gate that
  /// blocks on Android does not apply here.
  bool vpnWarning = false;

  /// The knock currently awaiting an answer, if any.
  Knock? activeKnock;

  /// Payload of the QR this device shows, when it hosts the link.
  String? waitingQrPayload;

  Stream<Knock> get knocks => _knocks.stream;
  int? get doorbellPort => _doorbell.port;
  bool get isWaiting => _doorbell.isListening || _responder.isListening;

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
  bool encrypted = false;
  String? securityCode;
  bool get anyPaused => pausedByMe || isPaused;
  bool get canResume => resumeOffsets.isNotEmpty;
  int get resumedBytes =>
      resumeOffsets.values.fold<int>(0, (sum, value) => sum + value);
  bool get canJoinHotspot => _hotspotService.canJoin;
  bool get isScanning => _scanner.isScanning;

  /// The transport the receiver listens on.
  ShareLink link = ShareLink.wifi;

  /// Switches the transport and re-scans, so the listener follows the link the
  /// user picked.
  Future<void> setLink(ShareLink value) async {
    if (link == value) return;
    link = value;
    if (_scanner.isScanning) {
      await _scanner.stop();
      await startScanning();
    } else {
      notifyListeners();
    }
  }

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
    String? bindAddress;
    if (link == ShareLink.ethernet) {
      bindAddress = await wiredIpv4();
      if (bindAddress == null) {
        errorMessage = _l10n.noWiredNetworkReceive;
        phase = ReceivePhase.failed;
        notifyListeners();
        return;
      }
    }
    final ok = await _scanner.start(
      ownInstanceId: appState.instanceId,
      bindAddress: bindAddress,
    );
    _scanSubscription ??= _scanner.sessions.listen((list) {
      sessions = list;
      notifyListeners();
    });
    if (!ok) {
      errorMessage = _l10n.discoveryFailedBody;
    }
    phase = ReceivePhase.scanning;
    notifyListeners();
  }

  Future<void> stopScanning() async {
    await _scanner.stop();
    sessions = const [];
    notifyListeners();
  }

  /// Brings up the receiving side: doorbell, presence answers, and - when this
  /// device should host - the hotspot whose credentials become the QR.
  ///
  /// [host] is decided by the caller from the pairing rules; it is false until
  /// the hotspot phase supplies the link.
  Future<void> startWaiting({bool host = false}) async {
    if (isWaiting) return;
    errorMessage = null;
    await _doorbell.start();
    _doorbell.onKnock = _onKnock;
    waitingQrPayload = host ? await _buildHostedQr() : null;
    presence = waitingQrPayload != null
        ? ReceiverPresence.qr
        : PlatformEnv.isDesktop
            ? ReceiverPresence.joinPrompt
            : ReceiverPresence.noCamera;
    await _responder.start(
      ownInstanceId: appState.instanceId,
      deviceName: appState.deviceName,
      platform: PlatformEnv.label,
      consentPort: _doorbell.port ?? 0,
    );
    AppLog.info(
        'receive',
        'waiting (presence: ${presence.name}, '
            'doorbell :${_doorbell.port})');
    notifyListeners();
  }

  /// The QR payload for a device that hosts the link itself.
  Future<String?> _buildHostedQr() async {
    if (!_hotspotService.canCreate) return null;
    try {
      await ensureHotspotPermissions();
      final info = await _hotspotService.start(deviceName: appState.deviceName);
      AppLog.info('hotspot', 'started "${info.ssid}" (${info.ip})');
      hotspotNotice = info.note;
      final address = info.ip ?? await localIpv4();
      if (address == null) return null;
      return PairingCode(
        ssid: info.ssid,
        password: info.password,
        host: address,
        port: _doorbell.port ?? AppConstants.transferPort,
        senderName: appState.deviceName,
        senderPlatform: PlatformEnv.label,
      ).encode();
    } on HotspotException catch (error) {
      AppLog.error('hotspot', 'could not start hotspot: ${error.message}');
      errorMessage = error.message;
      return null;
    }
  }

  /// Devices already pinned during an earlier encrypted session are trusted
  /// from then on, so they do not get asked again. Everyone else gets the
  /// modal exactly once.
  bool isRemembered(String instanceId) => appState.store.trustedDevices
      .any((device) => device.instanceId == instanceId);

  Future<void> _onKnock(Knock knock) async {
    AppLog.info('consent', 'knock from ${knock.senderName}');
    if (isRemembered(knock.senderInstanceId)) {
      AppLog.info(
        'consent',
        '${knock.senderName} is a remembered device - accepting directly',
      );
      await answerKnock(true);
      return;
    }
    activeKnock = knock;
    notifyListeners();
    if (!_knocks.isClosed) _knocks.add(knock);
  }

  /// Answers the pending knock. Accepting dials back the sender's file server
  /// and continues into the normal review flow.
  Future<void> answerKnock(bool accepted) async {
    final knock = activeKnock;
    if (knock == null) return;
    activeKnock = null;
    await _doorbell.decide(knock.requestId, accepted);
    notifyListeners();
    if (!accepted) {
      AppLog.info('consent', 'declined ${knock.senderName}');
      return;
    }
    AppLog.info(
        'host', 'connecting back to ${knock.senderHost}:${knock.senderPort}');
    await connectToAddress(
      knock.senderHost,
      knock.senderPort,
      label: knock.senderName,
    );
  }

  /// Whether the desktop is showing its own code for local-Wi-Fi mode.
  bool showLocalWifiQr = false;
  String? localWifiQrPayload;

  /// Switches from hotspot mode to local-Wi-Fi mode: the desktop shows an
  /// address code the phone can scan instead of joining a hotspot.
  Future<void> toggleLocalWifiQr() async {
    if (showLocalWifiQr) {
      showLocalWifiQr = false;
      localWifiQrPayload = null;
      notifyListeners();
      return;
    }
    final address = await localIpv4();
    final port = _doorbell.port;
    localWifiQrPayload = address == null || port == null
        ? null
        : PairingCode(
            host: address,
            port: port,
            senderName: appState.deviceName,
            senderPlatform: PlatformEnv.label,
          ).encode();
    showLocalWifiQr = true;
    notifyListeners();
  }

  /// Stops the doorbell and presence answers, releasing the link.
  Future<void> stopWaiting() async {
    activeKnock = null;
    await _doorbell.stop();
    await _responder.stop();
    presence = ReceiverPresence.idle;
    notifyListeners();
  }

  /// Joins the host's hotspot (Android/Linux/macOS) and then looks for it.
  /// Hotspot names this device can see that may belong to the other side.
  List<String> hotspotCandidates = const [];

  bool surveyingHotspots = false;

  /// Looks for the phone's link on this network list.
  ///
  /// Only Linux can enumerate Wi-Fi; everywhere else this answers empty and the
  /// user falls back to the pairing code.
  Future<void> surveyHotspots() async {
    if (surveyingHotspots) return;
    surveyingHotspots = true;
    notifyListeners();
    try {
      final found = await _hotspotService.survey();
      AppLog.info('hotspot', 'survey found ${found.length}: $found');
      hotspotCandidates = found;
    } on Object catch (error) {
      AppLog.warn('hotspot', 'survey failed: $error');
      hotspotCandidates = const [];
    } finally {
      surveyingHotspots = false;
      notifyListeners();
    }
  }

  /// Joins the chosen hotspot and then hunts on that link.
  Future<void> joinSurveyed(String ssid, String password) =>
      joinHotspot(ssid, password);

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
      hotspotNotice = info.note ?? _l10n.connectedLooking(info.ssid);
      await startScanning();
      phase = ReceivePhase.scanning;
    } on HotspotException catch (error) {
      errorMessage = error.message;
      phase = ReceivePhase.failed;
    } on Object catch (error) {
      errorMessage = _l10n.couldNotJoinHotspot('$error');
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
        hotspotNotice = info.note ?? _l10n.joinedHotspotNote(code.ssid ?? '');
      } else if (code.hasHotspot) {
        // Windows cannot join a hotspot on the user's behalf, so it falls back
        // to the system Wi-Fi menu and then finds the session by discovery.
        hotspotNotice = _l10n.joinHotspotManuallyNote(code.ssid ?? '');
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
        store: appState.store,
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
    AppLog.info(
        'receive',
        'dialing back to $ip:$port'
            '${label != null ? ' ("$label")' : ''}');
    try {
      final manifest = await client.connect(ip, port);
      await _scanner.stop();
      _host = ip;
      _port = port;
      this.manifest = manifest;
      encrypted = manifest.encrypted;
      securityCode = manifest.securityCode;
      AppLog.info(
          'receive',
          'manifest accepted: '
              '${manifest.items.length} files from $ip:$port');
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
    } on SocketException catch (error) {
      AppLog.error('receive', 'dial $ip:$port refused: ${error.message}');
      errorMessage = _l10n.couldNotReachAddress('$ip:$port');
      phase = ReceivePhase.failed;
      await client.dispose();
      _client = null;
    } on Object catch (error) {
      AppLog.error('receive', 'dial $ip:$port failed: $error');
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
    AppLog.info(
        'receive',
        'transfer started: ${selectedIds.length} files '
            '-> $saveLocation (${formatBytes(totalBytes)})');
    await _foreground.start(
      title: _l10n.receivingFilesTitle,
      text:
          '${_l10n.fileCount(selectedIds.length)} · ${formatBytes(totalBytes)}',
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
        errorMessage ??= _l10n.transferDidNotFinish;
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
      AppLog.info('receive', 'retrying ${retryIds.length} failed files');
      await _foreground.start(
        title: _l10n.retryingTransferTitle,
        text: _l10n.retryFailedFiles(retryIds.length),
      );
      notifyListeners();
      await client.receive(
        ids: retryIds.toList(growable: false),
        downloadRoot: saveLocation,
        retryPaths: retryPaths,
        baseBytes: doneBytes,
      );
    } on SocketException {
      errorMessage = _l10n.couldNotReachAddress('$host:$port');
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
      title: _l10n.receivingProgressTitle(
        formatBytes(receivedBytes),
        formatBytes(totalBytes),
      ),
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
    speedBytesPerSecond = speedBytesPerSecond == 0
        ? instant
        : speedBytesPerSecond * 0.7 + instant * 0.3;
    _lastSampleAt = now;
    _lastSampleBytes = receivedBytes;
  }

  void _onFinished(int fileCount, int bytes, Duration elapsed) {
    AppLog.info(
        'receive',
        'transfer finished: $fileCount files, '
            '${formatBytes(bytes)} in $elapsed');
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
    AppLog.debug(
        'receive',
        '"${item.name}" -> ${item.status.name} '
            '(${formatBytes(item.transferred)}/${formatBytes(item.size)})');
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
    AppLog.info('receive', 'pause tapped by user');
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
    AppLog.info('receive', 'resume tapped by user');
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
    AppLog.error('receive', 'transfer failed: $message');
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
      peerName: manifest?.hostName ?? _l10n.nearbyDevice,
      peerPlatform: manifest?.hostPlatform,
      fileCount: files,
      bytes: bytes,
      timestamp: DateTime.now(),
      durationMs: duration.inMilliseconds,
      succeeded: ok,
      fileNames: manifest?.items
              .where((item) => item.done || item.transferred > 0)
              .map((item) => item.name)
              .take(4)
              .toList(growable: false) ??
          const [],
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
      AppLog.info(
          'receive',
          'cancelled by user '
              '(${formatBytes(receivedBytes)} received so far)');
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
    encrypted = false;
    securityCode = null;
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
    unawaited(_doorbell.stop());
    unawaited(_responder.stop());
    unawaited(_knocks.close());
    unawaited(_foreground.stop());
    unawaited(_saveRecovery());
    unawaited(_client?.dispose());
    super.dispose();
  }
}
