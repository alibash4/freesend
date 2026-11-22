import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:free_send/services/app_logger.dart';
import 'package:free_send/core/app_constants.dart';

/// A host session visible on the local link.
class DiscoveredSession {
  DiscoveredSession({
    required this.instanceId,
    required this.deviceName,
    required this.platform,
    required this.ip,
    required this.port,
    required this.fileCount,
    required this.totalBytes,
    required this.lastSeen,
  });

  final String instanceId;
  final String deviceName;
  final String platform;
  final String ip;
  final int port;
  final int fileCount;
  final int totalBytes;
  DateTime lastSeen;

  String get id => '$instanceId@$ip:$port';
}

/// Advertises an open session over UDP broadcast, twice a second-ish so a
/// receiver that joins the hotspot late still finds it quickly.
class SessionBroadcaster {
  RawDatagramSocket? _socket;
  Timer? _timer;
  Map<String, Object?> _payload = const {};

  bool get isRunning => _timer != null;

  Future<void> start({
    required String instanceId,
    required String deviceName,
    required String platform,
    required int port,
    required int fileCount,
    required int totalBytes,
    String? bindAddress,
  }) async {
    await stop();
    _payload = {
      'app': 'free-send',
      'v': AppConstants.protocolVersion,
      'id': instanceId,
      'name': deviceName,
      'platform': platform,
      'port': port,
      'files': fileCount,
      'bytes': totalBytes,
    };
    try {
      // Binding to the hotspot's own address keeps beacons on the hotspot
      // interface; binding to anyIPv4 would follow the default route (cellular
      // or ethernet) and the peer would never see them.
      final bindTo =
          bindAddress == null ? null : InternetAddress.tryParse(bindAddress);
      final socket = await RawDatagramSocket.bind(
        bindTo ?? InternetAddress.anyIPv4,
        0,
      );
      socket.broadcastEnabled = true;
      _socket = socket;
      AppLog.info(
          'seeker',
          'beacon socket bound, broadcasting session '
              '"$deviceName" ($fileCount files) every '
              '${AppConstants.beaconInterval.inSeconds}s');
    } on SocketException catch (error) {
      // Broadcasting is unavailable (some locked-down desktop stacks); the
      // receiver can still connect by IP, so this is not fatal.
      AppLog.warn('seeker', 'beacon broadcast unavailable: ${error.message}');
      return;
    }
    _send();
    _timer = Timer.periodic(AppConstants.beaconInterval, (_) => _send());
  }

  void _send() {
    final socket = _socket;
    if (socket == null) return;
    try {
      final data = utf8.encode(jsonEncode(_payload));
      socket.send(
          data, InternetAddress('255.255.255.255'), AppConstants.discoveryPort);
      // Some hotspot stacks drop the limited broadcast; also try the usual
      // gateway addresses so at least one copy lands.
      for (final target in const [
        '192.168.43.255',
        '192.168.49.255',
        '10.42.0.255'
      ]) {
        socket.send(data, InternetAddress(target), AppConstants.discoveryPort);
      }
    } on Object {
      // Transient network errors are expected while the hotspot is settling.
    }
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _socket?.close();
    _socket = null;
  }
}

/// Listens for session beacons and keeps a live, de-duplicated list.
class SessionScanner {
  RawDatagramSocket? _socket;
  Timer? _pruneTimer;
  final _sessions = <String, DiscoveredSession>{};
  final _controller = StreamController<List<DiscoveredSession>>.broadcast();

  Stream<List<DiscoveredSession>> get sessions => _controller.stream;
  List<DiscoveredSession> get current => _sessions.values.toList();
  bool get isScanning => _socket != null;

  Future<bool> start({
    required String ownInstanceId,
    String? bindAddress,
  }) async {
    if (_socket != null) return true;
    // Binding to a specific interface keeps the listener on the link the user
    // picked; anyIPv4 hears every interface.
    final address = bindAddress == null
        ? InternetAddress.anyIPv4
        : InternetAddress.tryParse(bindAddress) ?? InternetAddress.anyIPv4;
    try {
      _socket = await RawDatagramSocket.bind(
        address,
        AppConstants.discoveryPort,
        reuseAddress: true,
        reusePort: true,
      );
    } on SocketException catch (first) {
      try {
        // reusePort is not supported everywhere; retry without it.
        AppLog.debug(
            'responder',
            'reusePort unsupported '
                '(${first.message}), retrying without it');
        _socket = await RawDatagramSocket.bind(
          address,
          AppConstants.discoveryPort,
          reuseAddress: true,
        );
      } on SocketException catch (second) {
        AppLog.error(
            'responder',
            'cannot listen for beacons on '
                '${address.address}:${AppConstants.discoveryPort}: $second');
        _socket = null;
        return false;
      }
    }
    AppLog.info(
        'responder',
        'listening for beacons on '
            '${address.address}:${AppConstants.discoveryPort}');
    final socket = _socket!;
    socket.listen(
      (event) {
        // A closed socket must not keep reporting isScanning: null it so
        // callers can restart instead of trusting a dead listener.
        if (event == RawSocketEvent.readClosed) {
          if (identical(_socket, socket)) _socket = null;
          return;
        }
        if (event != RawSocketEvent.read) return;
        final datagram = socket.receive();
        if (datagram == null) return;
        _handle(datagram, ownInstanceId);
      },
      onError: (_) {},
      onDone: () {
        if (identical(_socket, socket)) _socket = null;
      },
    );
    _pruneTimer = Timer.periodic(const Duration(seconds: 3), (_) => _prune());
    return true;
  }

  void _handle(Datagram datagram, String ownInstanceId) {
    try {
      final decoded = jsonDecode(utf8.decode(datagram.data));
      if (decoded is! Map<String, Object?>) return;
      if (decoded['app'] != 'free-send') return;
      final id = decoded['id'] as String?;
      final port = (decoded['port'] as num?)?.toInt();
      if (id == null || port == null || id == ownInstanceId) return;
      final session = DiscoveredSession(
        instanceId: id,
        deviceName: (decoded['name'] as String?) ?? 'Nearby device',
        platform: (decoded['platform'] as String?) ?? 'unknown',
        ip: datagram.address.address,
        port: port,
        fileCount: (decoded['files'] as num?)?.toInt() ?? 0,
        totalBytes: (decoded['bytes'] as num?)?.toInt() ?? 0,
        lastSeen: DateTime.now(),
      );
      if (!_sessions.containsKey(session.id)) {
        AppLog.info(
            'responder',
            'beacon from ${session.deviceName} '
                '(${session.platform}) at ${session.ip}:${session.port} '
                'offering ${session.fileCount} files');
      }
      _sessions[session.id] = session;
      _emit();
    } on Object {
      // Ignore malformed packets from unrelated broadcast traffic.
    }
  }

  void _prune() {
    final cutoff = DateTime.now().subtract(const Duration(seconds: 8));
    final stale = _sessions.entries
        .where((entry) => entry.value.lastSeen.isBefore(cutoff))
        .map((entry) => entry.key)
        .toList();
    if (stale.isEmpty) return;
    for (final key in stale) {
      _sessions.remove(key);
    }
    _emit();
  }

  void _emit() {
    if (_controller.isClosed) return;
    final list = _sessions.values.toList()
      ..sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
    _controller.add(list);
  }

  Future<void> stop() async {
    _pruneTimer?.cancel();
    _pruneTimer = null;
    _socket?.close();
    _socket = null;
    _sessions.clear();
    _emit();
  }
}

/// A receiver that answered a seeker's "I'm looking to send" packet.
class SeekCandidate {
  SeekCandidate({
    required this.instanceId,
    required this.deviceName,
    required this.platform,
    required this.ip,
    required this.consentPort,
    required this.lastSeen,
  });

  final String instanceId;
  final String deviceName;
  final String platform;
  final String ip;

  /// The receiver's doorbell port.
  final int consentPort;
  DateTime lastSeen;

  /// Identity is the instance id: a device that answers on two
  /// interfaces must still appear once.
  String get id => instanceId;
}

/// Sender side of discovery.
///
/// Broadcasts an intent packet on the local link and collects the answers from
/// receivers sitting in Receive. The sender binds an ephemeral port, so a
/// device can be a sender and a receiver at the same time without fighting over
/// the discovery port.
class SessionSeeker {
  RawDatagramSocket? _socket;
  Timer? _timer;
  Timer? _pruneTimer;
  final Map<String, SeekCandidate> _candidates = {};
  final StreamController<List<SeekCandidate>> _controller =
      StreamController<List<SeekCandidate>>.broadcast();

  Stream<List<SeekCandidate>> get candidates => _controller.stream;
  List<SeekCandidate> get current => _candidates.values.toList();
  bool get isSeeking => _socket != null;

  /// How long a candidate stays on the radar without a fresh answer.
  final Duration ttl;

  int _discoveryPort = AppConstants.discoveryPort;

  SessionSeeker({this.ttl = const Duration(seconds: 6)});

  Future<bool> start({
    required String ownInstanceId,
    required String deviceName,
    required String platform,
    int? discoveryPort,
  }) async {
    if (_socket != null) return true;
    _discoveryPort = discoveryPort ?? AppConstants.discoveryPort;
    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
        reuseAddress: true,
        reusePort: true,
      );
    } on SocketException catch (first) {
      AppLog.debug(
          'seeker',
          'reusePort unsupported (${first.message}), '
              'retrying without it');
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    } on Object catch (error) {
      AppLog.error('seeker', 'cannot open seek socket: $error');
      return false;
    }
    final socket = _socket!;
    socket.broadcastEnabled = true;
    socket.listen(
      (event) {
        if (event == RawSocketEvent.readClosed) {
          if (identical(_socket, socket)) _socket = null;
          return;
        }
        if (event != RawSocketEvent.read) return;
        final datagram = socket.receive();
        if (datagram == null) return;
        _handle(datagram, ownInstanceId);
      },
      onError: (_) {},
      onDone: () {
        if (identical(_socket, socket)) _socket = null;
      },
    );
    _payload = {
      'app': 'free-send',
      'v': AppConstants.protocolVersion,
      'kind': 'seek',
      'id': ownInstanceId,
      'name': deviceName,
      'pf': platform,
    };
    AppLog.info('seeker', 'seeking as "$deviceName" on port $_discoveryPort');
    _send();
    _timer = Timer.periodic(AppConstants.beaconInterval, (_) => _send());
    _pruneTimer = Timer.periodic(const Duration(seconds: 2), (_) => _prune());
    return true;
  }

  Map<String, Object?> _payload = const {};

  void _send() {
    final socket = _socket;
    if (socket == null) return;
    final data = utf8.encode(jsonEncode(_payload));
    // Loopback is included so the mechanism works when both roles run on one
    // machine; on real hardware it only reaches the device itself, which
    // ignores its own packets. Each target is independent: an unreachable
    // broadcast address must not stop the others.
    for (final target in const [
      '255.255.255.255',
      '192.168.43.255',
      '192.168.49.255',
      '10.42.0.255',
      '127.0.0.1',
    ]) {
      try {
        socket.send(data, InternetAddress(target), _discoveryPort);
      } on Object {
        // Transient network errors are expected while a hotspot settles.
      }
    }
  }

  void _handle(Datagram datagram, String ownInstanceId) {
    try {
      final decoded = jsonDecode(utf8.decode(datagram.data));
      if (decoded is! Map<String, Object?>) return;
      if (decoded['app'] != 'free-send') return;
      if (decoded['kind'] != 'presence') return;
      final id = decoded['id'] as String?;
      final port = (decoded['port'] as num?)?.toInt();
      if (id == null || port == null || id == ownInstanceId) return;
      final candidate = SeekCandidate(
        instanceId: id,
        deviceName: (decoded['name'] as String?) ?? 'Nearby device',
        platform: (decoded['pf'] as String?) ?? 'unknown',
        ip: datagram.address.address,
        consentPort: port,
        lastSeen: DateTime.now(),
      );
      final existing = _candidates[candidate.id];
      // Refresh the whole entry: a receiver that rejoined a network answers
      // from a new address, and its doorbell listens on every interface, so
      // the freshest source is always the right knock target.
      _candidates[candidate.id] = candidate;
      if (existing == null) {
        AppLog.info(
          'seeker',
          'found ${candidate.deviceName} (${candidate.platform}) at '
              '${candidate.ip}:${candidate.consentPort}',
        );
      }
      _emit();
    } on Object {
      // Ignore malformed packets from unrelated broadcast traffic.
    }
  }

  void _prune() {
    final cutoff = DateTime.now().subtract(ttl);
    final stale = _candidates.entries
        .where((entry) => entry.value.lastSeen.isBefore(cutoff))
        .map((entry) => entry.key)
        .toList();
    if (stale.isEmpty) return;
    for (final key in stale) {
      final lost = _candidates.remove(key);
      if (lost != null) {
        AppLog.debug('seeker', 'dropped ${lost.deviceName} (no answer)');
      }
    }
    _emit();
  }

  void _emit() {
    if (_controller.isClosed) return;
    final list = _candidates.values.toList()
      ..sort((a, b) => b.lastSeen.compareTo(a.lastSeen));
    _controller.add(list);
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
    _pruneTimer?.cancel();
    _pruneTimer = null;
    _socket?.close();
    _socket = null;
    _candidates.clear();
    _emit();
    AppLog.info('seeker', 'stopped');
  }
}

/// Receiver side of discovery: answers a seeker once it is sitting in Receive.
class PresenceResponder {
  RawDatagramSocket? _socket;
  final Map<String, DateTime> _lastReply = {};

  bool get isListening => _socket != null;

  Future<bool> start({
    required String ownInstanceId,
    required String deviceName,
    required String platform,
    required int consentPort,
    int? discoveryPort,
  }) async {
    if (_socket != null) return true;
    final port = discoveryPort ?? AppConstants.discoveryPort;
    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        port,
        reuseAddress: true,
        reusePort: true,
      );
    } on SocketException catch (first) {
      try {
        AppLog.debug(
            'responder',
            'reusePort unsupported '
                '(${first.message}), retrying without it');
        _socket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          port,
          reuseAddress: true,
        );
      } on SocketException catch (second) {
        AppLog.error(
            'responder',
            'cannot bind presence port '
                '$port: $second');
        _socket = null;
        return false;
      }
    }
    AppLog.info('responder', 'presence replies on :$port');
    _payload = {
      'app': 'free-send',
      'v': AppConstants.protocolVersion,
      'kind': 'presence',
      'id': ownInstanceId,
      'name': deviceName,
      'pf': platform,
      'port': consentPort,
    };
    final responderSocket = _socket!;
    responderSocket.listen(
      (event) {
        if (event == RawSocketEvent.readClosed) {
          if (identical(_socket, responderSocket)) _socket = null;
          return;
        }
        if (event != RawSocketEvent.read) return;
        final datagram = responderSocket.receive();
        if (datagram == null) return;
        _handle(datagram, ownInstanceId);
      },
      onError: (_) {},
      onDone: () {
        if (identical(_socket, responderSocket)) _socket = null;
      },
    );
    AppLog.info(
        'responder',
        'answering seekers as "$deviceName" '
            '(doorbell :$consentPort)');
    return true;
  }

  Map<String, Object?> _payload = const {};

  /// Answers at most once per second per seeker, so a burst of intent packets
  /// cannot turn into a reply storm.
  void _handle(Datagram datagram, String ownInstanceId) {
    try {
      final decoded = jsonDecode(utf8.decode(datagram.data));
      if (decoded is! Map<String, Object?>) return;
      if (decoded['app'] != 'free-send') return;
      if (decoded['kind'] != 'seek') return;
      final seeker = decoded['id'] as String?;
      if (seeker == null || seeker == ownInstanceId) return;
      final now = DateTime.now();
      final last = _lastReply[seeker];
      if (last != null && now.difference(last) < const Duration(seconds: 1)) {
        AppLog.debug('responder', 'seek from $seeker rate-limited');
        return;
      }
      _lastReply[seeker] = now;
      AppLog.debug(
          'responder',
          'answered seeker $seeker '
              'from ${datagram.address.address}:${datagram.port}');
      _socket?.send(
        utf8.encode(jsonEncode(_payload)),
        datagram.address,
        datagram.port,
      );
    } on Object {
      // Ignore malformed packets.
    }
  }

  Future<void> stop() async {
    _socket?.close();
    _socket = null;
    _lastReply.clear();
  }
}
