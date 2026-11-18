import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:free_send/l10n/app_localizations.dart';
import 'package:free_send/services/app_logger.dart';
import 'package:free_send/core/app_constants.dart';
import 'package:free_send/core/format.dart';
import 'package:free_send/core/platform_env.dart';
import 'package:free_send/models/peer_info.dart';
import 'package:free_send/models/recent_file.dart';
import 'package:free_send/models/transfer_item.dart';
import 'package:free_send/models/transfer_record.dart';
import 'package:free_send/services/discovery_service.dart';
import 'package:free_send/services/hotspot/hotspot_permissions.dart';
import 'package:free_send/services/hotspot/hotspot_service.dart';
import 'package:free_send/core/transfer_flow.dart';
import 'package:free_send/services/pairing_code.dart';
import 'package:free_send/services/transfer/doorbell.dart';
import 'package:free_send/services/transfer/transfer_foreground.dart';
import 'package:free_send/services/transfer/transfer_host.dart';
import 'package:free_send/state/app_state.dart';

enum SendPhase {
  idle,
  preparing,
  waitingForPeer,
  transferring,
  completed,
  failed,
  cancelled,
}

/// Drives the sending side: hotspot up, listener up, beacons out, files pushed.
class SendController extends ChangeNotifier {
  SendController({required this.appState, HotspotService? hotspotService})
      : _hotspotService = hotspotService ?? createHotspotService();

  final AppState appState;
  final HotspotService _hotspotService;

  /// Strings for messages this controller produces; resolved at call time so
  /// a locale change applies to the next message, not just the next rebuild.
  AppLocalizations get _l10n => lookupAppLocalizations(appState.locale);
  final SessionSeeker _seeker = SessionSeeker();
  StreamSubscription<List<SeekCandidate>>? _candidateSub;

  final List<TransferItem> items = [];

  /// Files picked recently, newest first. Kept in sync with [LocalStore].
  late List<RecentFile> recents = _loadRecents();

  SendPhase phase = SendPhase.idle;
  HotspotInfo? hotspot;

  /// The transport the next session will use.
  ShareLink link = ShareLink.wifi;
  String? _sessionAddress;
  String? errorMessage;
  String? peerName;
  String? peerPlatform;
  int port = AppConstants.transferPort;

  int totalBytes = 0;
  int sentBytes = 0;
  double speedBytesPerSecond = 0;
  String? currentFileName;
  int peerCount = 0;
  List<String> connectedPeerNames = const [];
  List<PeerInfo> peers = const [];
  bool paused = false;

  TransferHost? _host;
  final TransferForeground _foreground = TransferForeground();
  Stopwatch? _stopwatch;
  DateTime? _lastSampleAt;
  int _lastSampleBytes = 0;
  int _id = 0;
  TransferRecord? lastRecord;

  bool get canCreateHotspot => _hotspotService.canCreate;

  /// The address a receiver should connect to for the running session.
  String? get sessionAddress => _sessionAddress;

  /// Picks the transport before a session starts. Ethernet skips the hotspot
  /// and advertises the wired interface instead.
  void setLink(ShareLink value) {
    if (link == value) return;
    link = value;
    notifyListeners();
  }

  /// The invitation the other device can scan. It only exists once the
  /// listener is up, and only carries a hotspot when this app created one:
  /// on Windows and macOS the session runs over a network the user picked, so
  /// the code just points at the address.
  bool _disposed = false;

  List<SeekCandidate> _candidates = const [];

  /// Receivers that answered the sender's signal.
  List<SeekCandidate> get candidates => _candidates;

  set candidates(List<SeekCandidate> value) {
    _candidates = value;
    notifyListeners();
  }

  /// The entry the user picked from the send control.
  SendMode mode = SendMode.nearby;

  /// Receivers ticked in group mode.
  final Set<String> selected = {};

  void setMode(SendMode value) {
    if (mode == value) return;
    mode = value;
    selected.clear();
    notifyListeners();
  }

  void toggleSelected(String id) {
    if (!selected.remove(id)) selected.add(id);
    notifyListeners();
  }

  /// Asks every ticked receiver, one independent request each.
  Future<void> knockSelected() async {
    final targets = candidates
        .where((candidate) => selected.contains(candidate.id))
        .toList(growable: false);
    await Future.wait(targets.map(knock));
  }

  /// Per-receiver consent state, keyed by [SeekCandidate.id].
  final Map<String, AuthState> peerStates = {};

  bool get isHunting => _seeker.isSeeking;

  AuthState? stateOf(SeekCandidate candidate) => peerStates[candidate.id];

  PairingCode? get pairingCode {
    final address = sessionAddress;
    if (address == null || port <= 0) return null;
    if (phase != SendPhase.waitingForPeer && phase != SendPhase.transferring) {
      return null;
    }
    final info = hotspot;
    final code = PairingCode(
      ssid: info != null && info.created ? info.ssid : null,
      password: info != null && info.created ? info.password : null,
      host: address,
      port: port,
      senderName: appState.deviceName,
      senderPlatform: PlatformEnv.label,
    );
    return code.isUsable ? code : null;
  }

  bool get isBusy =>
      phase == SendPhase.preparing ||
      phase == SendPhase.waitingForPeer ||
      phase == SendPhase.transferring;
  bool get hasPeer => _host?.hasPeer ?? false;
  bool get canPause => phase == SendPhase.transferring && !paused;
  bool get canResume => phase == SendPhase.transferring && paused;

  int get remainingBytes => (totalBytes - sentBytes).clamp(0, totalBytes);

  double get overallProgress {
    if (phase == SendPhase.completed) return 1;
    if (totalBytes <= 0) return 0;
    return (sentBytes / totalBytes).clamp(0, 1);
  }

  /// Picks up files chosen by the user. Duplicates of the same path are skipped.
  void addFiles(List<File> files, {String? relativePath}) {
    final existing = {for (final item in items) item.path};
    for (final file in files) {
      if (existing.contains(file.path)) continue;
      final item = TransferItem.fromFile(file, relativePath: relativePath);
      if (item == null) continue;
      item.id = 'f${_id++}';
      items.add(item);
      existing.add(file.path);
    }
    _recalculateTotal();
    _remember(files);
    notifyListeners();
  }

  /// Adds every file below [directory], keeping the selected folder name in
  /// each item's relative path so the receiver recreates the same shape.
  Future<void> addDirectory(Directory directory) async {
    if (!await directory.exists()) return;
    final base = directory.parent.path;
    final prefix = base.endsWith(Platform.pathSeparator)
        ? base
        : '$base${Platform.pathSeparator}';
    final files = <File>[];
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File) files.add(entity);
    }
    final existing = {for (final item in items) item.path};
    final added = <TransferItem>[];
    for (final file in files) {
      if (existing.contains(file.path)) continue;
      final relative = file.path.startsWith(prefix)
          ? file.path.substring(prefix.length)
          : file.uri.pathSegments.last;
      final item = TransferItem.fromFile(
        file,
        relativePath: relative.replaceAll(Platform.pathSeparator, '/'),
      );
      if (item == null) continue;
      item.id = 'f${_id++}';
      added.add(item);
      existing.add(file.path);
    }
    if (added.isEmpty) return;
    items.addAll(added);
    _recalculateTotal();
    _remember(files);
    notifyListeners();
  }

  List<RecentFile> _loadRecents() {
    try {
      return appState.store.recentFiles;
    } on Object {
      return const [];
    }
  }

  void _remember(Iterable<File> files) {
    final readable = files.where((file) => file.existsSync()).toList();
    if (readable.isEmpty) return;
    unawaited(
      appState.store.addRecentFiles(readable).then((_) {
        recents = appState.store.recentFiles;
        notifyListeners();
      }),
    );
  }

  void removeItem(TransferItem item) {
    items.remove(item);
    _recalculateTotal();
    notifyListeners();
  }

  void clearFiles() {
    items.clear();
    _recalculateTotal();
    notifyListeners();
  }

  void _recalculateTotal() {
    totalBytes = items.fold<int>(0, (sum, item) => sum + item.size);
  }

  Future<void> startSession() async {
    if (items.isEmpty || isBusy) return;
    phase = SendPhase.preparing;
    errorMessage = null;
    peerName = null;
    peerPlatform = null;
    peerCount = 0;
    connectedPeerNames = const [];
    peers = const [];
    paused = false;
    sentBytes = 0;
    speedBytesPerSecond = 0;
    for (final item in items) {
      item.transferred = 0;
      item.done = false;
      item.status = TransferStatus.pending;
    }
    notifyListeners();

    try {
      late final String? bindAddress;
      if (link == ShareLink.ethernet) {
        // A cable needs no hotspot: the wired address is the one to advertise.
        final wired = await wiredIpv4();
        if (wired == null) {
          _fail(_l10n.noWiredNetworkSend);
          return;
        }
        bindAddress = wired;
      } else if (PlatformEnv.kind == PlatformKind.android) {
        // A phone hosts its own link: the other device - usually a desktop
        // with no camera - joins it instead of scanning anything. The name and
        // password are shown on the hunting screen for that side to use.
        await ensureHotspotPermissions();
        try {
          hotspot = await _hotspotService.start(
            deviceName: appState.deviceName,
          );
          AppLog.info('hotspot', 'sender hosting "${hotspot!.ssid}"');
          if (hotspot!.note != null) {
            debugPrint('FreeSend: ${hotspot!.note}');
          }
        } on HotspotException catch (error) {
          // Hosting is the fast path, not the only one: stay on the shared
          // network so the radar keeps working.
          AppLog.warn('hotspot', 'could not host, staying on Wi-Fi: '
              '${error.message}');
          errorMessage = error.message;
        }
        bindAddress = hotspot?.ip ?? await localIpv4();
        if (bindAddress == null) {
          _fail(_l10n.noLocalAddressSend);
          return;
        }
      } else {
        // Desktops share an existing network (R5) and never host for a phone.
        bindAddress = await localIpv4();
        if (bindAddress == null) {
          _fail(_l10n.noLocalAddressSend);
          return;
        }
      }
      _sessionAddress = bindAddress;
      final host = TransferHost(
        items: items,
        deviceName: appState.deviceName,
        instanceId: appState.instanceId,
        identityStore: appState.store,
        events: HostEvents(
          onPeersChanged: _onPeersChanged,
          onPeerFinished: _onPeerFinished,
          onPeerError: _onPeerError,
          onProgress: _onProgress,
          onFinished: _onFinished,
          onError: _onHostError,
        ),
      );
      port = await host.start();
      _host = host;
      await _foreground.start(
        title: _l10n.readyToShare,
        text:
            '${_l10n.fileCount(items.length)} · ${_l10n.waitingForReceiverNote}',
      );

      await _seeker.start(
        ownInstanceId: appState.instanceId,
        deviceName: appState.deviceName,
        platform: PlatformEnv.label,
      );
      AppLog.info(
        'send',
        'session up on ${_sessionAddress ?? 'unknown'}:$port with '
            '${items.length} files (${formatBytes(totalBytes)})',
      );
      _candidateSub ??= _seeker.candidates.listen((list) {
        candidates = list;
        notifyListeners();
      });

      phase = SendPhase.waitingForPeer;
      notifyListeners();
    } on HotspotException catch (error) {
      _fail(error.message);
    } on SocketException catch (error) {
      _fail(_l10n.listenerFailed(error.message));
    } on Object catch (error) {
      _fail(_l10n.couldNotStartSharing(error));
    }
  }

  void _onPeersChanged(List<PeerInfo> value) {
    peers = value;
    peerCount = value.length;
    connectedPeerNames = value.map((peer) => peer.name).toList(growable: false);
    if (value.isEmpty) {
      peerName = null;
      peerPlatform = null;
    } else {
      peerName ??= value.first.name;
      peerPlatform ??= value.first.platform;
    }
    notifyListeners();
  }

  void _onPeerFinished(
    String peerId,
    int fileCount,
    int bytes,
    Duration elapsed,
  ) {
    peers = [
      for (final peer in peers)
        if (peer.id == peerId)
          peer.copyWith(
            selectedIds: peer.selectedIds,
            transferred: bytes,
            completedFiles: fileCount,
            clearCurrentFile: true,
            status: TransferStatus.done,
          )
        else
          peer,
    ];
    notifyListeners();
  }

  void _onPeerError(String peerId, String message) {
    peers = [
      for (final peer in peers)
        if (peer.id == peerId)
          peer.copyWith(clearCurrentFile: true, status: TransferStatus.failed)
        else
          peer,
    ];
    if (peers.isNotEmpty &&
        peers.every((peer) => peer.status == TransferStatus.failed)) {
      errorMessage = message;
    }
    notifyListeners();
  }

  /// Pauses the outgoing stream without dropping the session. The receiver
  /// keeps the bytes already written and waits for the resume frame.
  Future<void> pauseTransfer() async {
    if (phase != SendPhase.transferring || paused) return;
    paused = true;
    notifyListeners();
    await _host?.pauseTransfer();
  }

  Future<void> resumeTransfer() async {
    if (!paused) return;
    paused = false;
    notifyListeners();
    await _host?.resumeTransfer();
  }

  void _onProgress(TransferItem item, int _) {
    currentFileName = item.name;
    item.status = TransferStatus.active;
    sentBytes = items.fold<int>(0, (sum, entry) => sum + entry.transferred);
    unawaited(_foreground.update(
      title: _l10n.sendingProgressTitle(
        formatBytes(sentBytes),
        formatBytes(totalBytes),
      ),
      text: currentFileName,
    ));
    _sampleSpeed();
    if (phase != SendPhase.transferring) {
      phase = SendPhase.transferring;
      _stopwatch = Stopwatch()..start();
    }
    notifyListeners();
  }

  void _sampleSpeed() {
    final now = DateTime.now();
    final last = _lastSampleAt;
    if (last == null) {
      _lastSampleAt = now;
      _lastSampleBytes = sentBytes;
      return;
    }
    final elapsed = now.difference(last).inMilliseconds;
    if (elapsed < AppConstants.progressInterval.inMilliseconds) return;
    final delta = sentBytes - _lastSampleBytes;
    final instant = delta / (elapsed / 1000);
    // Exponential smoothing keeps the number readable while it fluctuates.
    speedBytesPerSecond = speedBytesPerSecond == 0
        ? instant
        : speedBytesPerSecond * 0.7 + instant * 0.3;
    _lastSampleAt = now;
    _lastSampleBytes = sentBytes;
  }

  void _onFinished(int fileCount, int bytes, Duration elapsed) {
    // The host reports completion once per receiver. In a group session the
    // first receiver finishing must not end the UI while others are still
    // streaming; the transfer ends when every receiver is done or failed.
    final allSettled = peers.every(
      (peer) =>
          peer.status == TransferStatus.done ||
          peer.status == TransferStatus.failed,
    );
    if (!allSettled) {
      notifyListeners();
      return;
    }
    _stopwatch?.stop();
    sentBytes = bytes;
    totalBytes = totalBytes == 0 ? bytes : totalBytes;
    paused = false;
    for (final item in items) {
      if (item.transferred >= item.size) {
        item.done = true;
        item.status = TransferStatus.done;
      }
    }
    phase = SendPhase.completed;
    unawaited(_foreground.stop());
    _finishSession(files: fileCount, bytes: bytes, duration: elapsed, ok: true);
    notifyListeners();
  }

  void _onHostError(String message) {
    if (phase == SendPhase.completed || phase == SendPhase.cancelled) return;
    _fail(message);
  }

  void _fail(String message) {
    errorMessage = message;
    phase = SendPhase.failed;
    unawaited(_foreground.stop());
    unawaited(_teardown());
    notifyListeners();
  }

  Future<void> cancelSession() async {
    if (phase == SendPhase.idle) return;
    final bytes = sentBytes;
    final files = items.where((item) => item.transferred > 0).length;
    phase = SendPhase.cancelled;
    paused = false;
    unawaited(_foreground.stop());
    notifyListeners();
    await _teardown();
    if (bytes > 0) {
      await _finishSession(
        files: files,
        bytes: bytes,
        duration: _stopwatch?.elapsed ?? Duration.zero,
        ok: false,
      );
    }
    notifyListeners();
  }

  Future<void> _finishSession({
    required int files,
    required int bytes,
    required Duration duration,
    required bool ok,
  }) async {
    final record = TransferRecord(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      direction: TransferDirection.send,
      peerName: peerName ?? _l10n.nearbyDevice,
      peerPlatform: peerPlatform,
      fileCount: files,
      bytes: bytes,
      timestamp: DateTime.now(),
      durationMs: duration.inMilliseconds,
      succeeded: ok,
      fileNames: items
          .where((item) => item.done || item.transferred > 0)
          .map((item) => item.name)
          .take(4)
          .toList(growable: false),
    );
    lastRecord = record;
    await appState.recordTransfer(record);
  }

  /// Asks a receiver to accept. The receiver dials back our file server once
  /// it agrees, so the transfer itself needs no further work here.
  Future<void> knock(SeekCandidate candidate) async {
    await _knock(
      id: candidate.id,
      ip: candidate.ip,
      consentPort: candidate.consentPort,
    );
  }

  /// Follows a scanned receiver code: joins the receiver's hotspot when the
  /// code carries one, moves this session onto that link, then asks.
  Future<void> knockScanned(PairingCode code) async {
    final host = code.host;
    if (host == null) return;
    if (code.hasHotspot) {
      final joined = await _joinReceiverHotspot(code);
      if (!joined) return;
    }
    await knockAddress(host, code.port);
  }

  Future<bool> _joinReceiverHotspot(PairingCode code) async {
    if (!_hotspotService.canJoin) {
      errorMessage = _l10n.cannotJoinHotspot;
      notifyListeners();
      return false;
    }
    try {
      await ensureHotspotPermissions();
      final info = await _hotspotService.join(code.ssid!, code.password);
      AppLog.info('hotspot', 'joined "${info.ssid}" (${info.ip})');
      await _rebindSession();
      return true;
    } on HotspotException catch (error) {
      AppLog.error(
          'hotspot',
          'could not join "${code.ssid}": '
              '${error.message}');
      errorMessage = error.message;
      notifyListeners();
      return false;
    }
  }

  /// Moves the file server and the seeker onto the current interface after the
  /// Wi-Fi changed, so the receiver can dial back on a reachable address.
  Future<void> _rebindSession() async {
    final address = await localIpv4();
    if (address == null || address == _sessionAddress) return;
    await _seeker.stop();
    await _host?.dispose();
    _host = null;
    final host = TransferHost(
      items: items,
      deviceName: appState.deviceName,
      instanceId: appState.instanceId,
      identityStore: appState.store,
      events: HostEvents(
        onPeersChanged: _onPeersChanged,
        onPeerFinished: _onPeerFinished,
        onPeerError: _onPeerError,
        onProgress: _onProgress,
        onFinished: _onFinished,
        onError: _onHostError,
      ),
    );
    port = await host.start();
    _host = host;
    _sessionAddress = address;
    await _seeker.start(
      ownInstanceId: appState.instanceId,
      deviceName: appState.deviceName,
      platform: PlatformEnv.label,
    );
    AppLog.info('send', 're-bound the session on $address:$port');
  }

  /// Knocks a scanned address, whose QR carries the receiver's doorbell port.
  Future<void> knockAddress(String host, int doorbellPort) async {
    await _knock(
        id: 'scanned@$host:$doorbellPort', ip: host, consentPort: doorbellPort);
  }

  Future<void> _knock({
    required String id,
    required String ip,
    required int consentPort,
  }) async {
    if (phase != SendPhase.waitingForPeer) return;
    final address = _sessionAddress;
    if (address == null || port <= 0) return;
    peerStates[id] = AuthState.pending;
    notifyListeners();
    AppLog.info('send', 'asking $ip:$consentPort');
    final outcome = await KnockClient.send(
      host: ip,
      port: consentPort,
      senderInstanceId: appState.instanceId,
      senderName: appState.deviceName,
      platform: PlatformEnv.label,
      fileCount: items.length,
      totalBytes: totalBytes,
      fileServerHost: address,
      fileServerPort: port,
    );
    peerStates[id] = switch (outcome) {
      KnockOutcome.accepted => AuthState.accepted,
      KnockOutcome.declined => AuthState.declined,
      KnockOutcome.timedOut => AuthState.offline,
    };
    notifyListeners();
  }

  Future<void> _teardown() async {
    await _foreground.stop();
    await _candidateSub?.cancel();
    _candidateSub = null;
    await _seeker.stop();
    candidates = const [];
    peerStates.clear();
    selected.clear();
    await _host?.dispose();
    _host = null;
    await _hotspotService.stop();
  }

  /// Leaves the session view but keeps picked files, ready for another round.
  Future<void> reset() async {
    await _teardown();
    hotspot = null;
    _sessionAddress = null;
    peerName = null;
    peerPlatform = null;
    peerCount = 0;
    connectedPeerNames = const [];
    peers = const [];
    paused = false;
    errorMessage = null;
    sentBytes = 0;
    speedBytesPerSecond = 0;
    currentFileName = null;
    _lastSampleAt = null;
    _lastSampleBytes = 0;
    for (final item in items) {
      item.transferred = 0;
      item.done = false;
      item.status = TransferStatus.pending;
    }
    phase = SendPhase.idle;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_teardown());
    super.dispose();
  }

  /// Teardown can finish after [dispose] returns, and the host notifies as it
  /// closes; a late notification must not assert.
  @override
  void notifyListeners() {
    if (_disposed) return;
    super.notifyListeners();
  }
}
