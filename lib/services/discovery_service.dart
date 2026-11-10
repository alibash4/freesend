import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
      final bindTo = bindAddress == null ? null : InternetAddress.tryParse(bindAddress);
      final socket = await RawDatagramSocket.bind(
        bindTo ?? InternetAddress.anyIPv4,
        0,
      );
      socket.broadcastEnabled = true;
      _socket = socket;
    } on SocketException {
      // Broadcasting is unavailable (some locked-down desktop stacks); the
      // receiver can still connect by IP, so this is not fatal.
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
      socket.send(data, InternetAddress('255.255.255.255'), AppConstants.discoveryPort);
      // Some hotspot stacks drop the limited broadcast; also try the usual
      // gateway addresses so at least one copy lands.
      for (final target in const ['192.168.43.255', '192.168.49.255', '10.42.0.255']) {
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

  Future<bool> start({required String ownInstanceId}) async {
    if (_socket != null) return true;
    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        AppConstants.discoveryPort,
        reuseAddress: true,
        reusePort: true,
      );
    } on SocketException {
      try {
        // reusePort is not supported everywhere; retry without it.
        _socket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          AppConstants.discoveryPort,
          reuseAddress: true,
        );
      } on SocketException {
        _socket = null;
        return false;
      }
    }
    final socket = _socket!;
    socket.listen(
      (event) {
        if (event != RawSocketEvent.read) return;
        final datagram = socket.receive();
        if (datagram == null) return;
        _handle(datagram, ownInstanceId);
      },
      onError: (_) {},
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
