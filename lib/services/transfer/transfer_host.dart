import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:free_send/core/app_constants.dart';
import 'package:free_send/core/format.dart';
import 'package:free_send/models/peer_info.dart';
import 'package:free_send/models/transfer_item.dart';
import 'package:free_send/services/app_logger.dart';
import 'package:free_send/services/device_identity.dart';
import 'package:free_send/services/local_store.dart';
import 'package:free_send/services/transfer/checksum.dart';
import 'package:free_send/services/transfer/secure_channel.dart';
import 'package:free_send/services/transfer/frame_channel.dart';
import 'package:free_send/services/transfer/protocol.dart';

/// Events the sending UI cares about. Kept as callbacks because the host is a
/// plain object owned by a controller, not a long-lived global service.
class HostEvents {
  const HostEvents({
    this.onListening,
    this.onPeerConnected,
    this.onPeerDisconnected,
    this.onPeerCountChanged,
    this.onSelectionAccepted,
    this.onProgress,
    this.onFinished,
    this.onError,
    this.onPeerClosed,
    this.onPeersChanged,
    this.onPeerFinished,
    this.onPeerError,
  });

  final void Function(int port)? onListening;
  final void Function(String name, String? platform)? onPeerConnected;
  final void Function(String name, String? platform)? onPeerDisconnected;
  final void Function(int count)? onPeerCountChanged;
  final void Function(List<TransferItem> selected)? onSelectionAccepted;
  final void Function(TransferItem item, int bytesSent)? onProgress;
  final void Function(int fileCount, int bytes, Duration elapsed)? onFinished;
  final void Function(String message)? onError;
  final void Function()? onPeerClosed;

  /// Snapshot of every receiver, including per-peer progress and status.
  final void Function(List<PeerInfo> peers)? onPeersChanged;
  final void Function(
          String peerId, int fileCount, int bytes, Duration elapsed)?
      onPeerFinished;
  final void Function(String peerId, String message)? onPeerError;
}

/// Runs the TCP server on the hotspot host and pushes files to every connected
/// peer. Each peer negotiates its own manifest and selection, which is what
/// makes a single sender able to serve a group.
class TransferHost {
  TransferHost({
    required this.items,
    required this.deviceName,
    required this.events,
    required this.instanceId,
    this.identityStore,
  });

  final List<TransferItem> items;
  final String deviceName;
  final HostEvents events;
  final String instanceId;
  final LocalStore? identityStore;
  DeviceIdentity? _identity;

  ServerSocket? _server;
  final Map<String, _HostPeer> _peers = {};
  bool _disposed = false;
  bool _paused = false;
  Completer<void>? _resumeWaiter;
  int _peerCounter = 0;
  int _port = AppConstants.transferPort;

  Future<DeviceIdentity> _deviceIdentity() {
    final existing = _identity;
    if (existing != null) return Future<DeviceIdentity>.value(existing);
    return DeviceIdentity.load(identityStore)
        .then((value) => _identity = value);
  }

  bool get isListening => _server != null;
  int get port => _port;
  int get peerCount => _peers.length;
  bool get hasPeer => _peers.isNotEmpty;
  List<String> get connectedPeerNames =>
      _peers.values.map((peer) => peer.name).toList(growable: false);
  List<PeerInfo> get peers =>
      _peers.values.map((peer) => peer.snapshot()).toList(growable: false);

  /// Binds the transfer port, walking forward a few ports if it is taken so a
  /// second session on the same machine still gets a listener.
  Future<int> start() async {
    Object? lastError;
    for (var offset = 0; offset < 6; offset++) {
      final candidate = AppConstants.transferPort + offset;
      try {
        _server = await ServerSocket.bind(InternetAddress.anyIPv4, candidate);
        _port = candidate;
        _server!.listen(_onConnection, onError: (Object error) {
          AppLog.error('host', 'listener failed: $error');
          events.onError?.call('Listener problem: $error');
        });
        AppLog.info(
            'host',
            'listening on :$_port '
                '(${items.length} files, '
                '${items.fold<int>(0, (sum, item) => sum + item.size)} bytes)');
        events.onListening?.call(_port);
        return _port;
      } on SocketException catch (error) {
        AppLog.debug('host', 'port $candidate busy: ${error.message}');
        lastError = error;
      }
    }
    AppLog.error('host', 'no free transfer port: $lastError');
    throw SocketException('No free transfer port ($lastError)');
  }

  void _onConnection(Socket socket) {
    if (_disposed) {
      socket.destroy();
      return;
    }
    final id = 'p${_peerCounter++}';
    final peer = _HostPeer(id, FrameChannel(socket, tag: 'host:$id'));
    AppLog.info(
        'host',
        'connection from '
            '${socket.remoteAddress.address}:${socket.remotePort} ($id)');
    _peers[peer.id] = peer;
    _emitPeers();
    unawaited(_serve(peer));
  }

  Future<void> _serve(_HostPeer peer) async {
    final channel = peer.channel;
    try {
      final hello = await channel.next(timeout: const Duration(seconds: 20));
      if (hello.type != FrameType.hello) {
        throw ProtocolException('Expected a handshake');
      }
      final payload = hello.json();
      final version = (payload['v'] as num?)?.toInt() ?? 1;
      if (version < 1 || version > AppConstants.protocolVersion) {
        await channel.writer.error(
          'Version mismatch: this device speaks FreeSend protocol '
          'v$AppConstants.protocolVersion',
        );
        await channel.close();
        return;
      }
      peer.protocolVersion = version;
      peer.name = (payload['name'] as String?)?.trim().isNotEmpty == true
          ? (payload['name'] as String).trim()
          : 'Nearby device';
      peer.platform = payload['platform'] as String?;
      peer.connected = true;
      AppLog.info(
          'host',
          '${peer.id}: ${peer.name} '
              '(${peer.platform ?? '?'}) spoke protocol v$version');
      events.onPeerConnected?.call(peer.name, peer.platform);
      _emitPeers();

      final clientKey = payload['key'];
      if (version >= 3 && clientKey is String && clientKey.isNotEmpty) {
        final salt = base64.decode(
          (payload['nonce'] as String?) ?? base64.encode(_zeroSalt),
        );
        final handshake = await SecureHandshake.withSalt(salt);
        final hostPublicKey = await handshake.publicKey;
        final cipher =
            SecureChannel(await handshake.derive(base64.decode(clientKey)));

        final identity = await _deviceIdentity();
        final signedMessage = utf8.encode(
          '${base64.encode(hostPublicKey)}|${base64.encode(salt)}|$instanceId',
        );
        final signature = await identity.sign(signedMessage);
        // The receiver may answer as soon as it sees the ack; hold the read
        // loop until the cipher is installed so the answer is decrypted.
        channel.pause();
        await channel.writer.json(FrameType.helloAck, {
          'v': 3,
          'key': base64.encode(hostPublicKey),
          'identity': identity.publicKeyBase64,
          'fingerprint': identity.fingerprint,
          'instanceId': instanceId,
          'signature': base64.encode(signature),
        });
        await channel.writer.flush();
        channel.useCipher(encrypt: cipher.seal, decrypt: cipher.open);
        channel.resume();
        peer.encrypted = true;
        AppLog.info('host', '${peer.id}: encrypted session established');
        final confirm =
            await channel.next(timeout: const Duration(seconds: 20));
        if (confirm.type != FrameType.helloConfirm) {
          throw ProtocolException('The receiver did not confirm the key');
        }
        AppLog.debug('host', '${peer.id}: key confirmed');
      }

      await channel.writer.json(FrameType.session, {
        'v': AppConstants.protocolVersion,
        'name': deviceName,
        'platform': Platform.operatingSystem,
        'port': _port,
        'files': [for (final item in items) item.toWire()],
        'totalBytes': items.fold<int>(0, (sum, item) => sum + item.size),
        'caps': const ['folders', 'checksums', 'pause'],
        'instanceId': instanceId,
        'fingerprint': _identity?.fingerprint,
      });
      await channel.writer.flush();
      AppLog.info(
          'host',
          '${peer.id}: manifest sent '
              '(${items.length} files offered)');

      final accept = await channel.next(timeout: const Duration(minutes: 2));
      if (accept.type == FrameType.cancel) {
        events.onPeerClosed?.call();
        await channel.close();
        return;
      }
      if (accept.type == FrameType.error) {
        throw ProtocolException(
          accept.json()['message'] as String? ??
              'The other device refused the transfer',
        );
      }
      if (accept.type != FrameType.accept) {
        throw ProtocolException('Unexpected response from the other device');
      }
      final ids = <String>{
        for (final id in (accept.json()['ids'] as List<Object?>? ?? const []))
          if (id is String) id,
      };
      final offsets = <String, int>{};
      final rawOffsets = accept.json()['offsets'];
      if (rawOffsets is Map<Object?, Object?>) {
        for (final entry in rawOffsets.entries) {
          final key = entry.key;
          final value = entry.value;
          if (key is String && value is num) {
            offsets[key] = value.toInt();
          }
        }
      }
      final selected =
          items.where((item) => ids.contains(item.id)).toList(growable: false);
      AppLog.info(
          'host',
          '${peer.id}: receiver selected '
              '${selected.length}/${items.length} files '
              '(${offsets.length} resume offsets)');
      if (selected.isEmpty) {
        await channel.writer.error('No files were selected');
        await channel.close();
        return;
      }
      peer.sending = true;
      peer.selectedIds = [for (final item in selected) item.id];
      peer.totalBytes = selected.fold<int>(0, (sum, item) => sum + item.size);
      peer.transferred = selected.fold<int>(
        0,
        (sum, item) => sum + (offsets[item.id] ?? 0).clamp(0, item.size),
      );
      peer.completedFiles = 0;
      peer.currentFile = null;
      peer.status = TransferStatus.active;
      _emitPeers();
      events.onSelectionAccepted?.call(selected);
      AppLog.info(
          'host',
          '${peer.id}: transfer started '
              '(${selected.length} files, '
              '${selected.fold<int>(0, (sum, item) => sum + item.size)} bytes)');

      final stopwatch = Stopwatch()..start();
      for (final item in selected) {
        if (peer.aborted || channel.isClosed) break;
        await _sendFile(
          channel,
          item,
          peer,
          startOffset: offsets[item.id] ?? 0,
        );
      }
      stopwatch.stop();

      if (peer.aborted) {
        unawaited(channel.close());
        return;
      }
      if (channel.isClosed) {
        throw ProtocolException('The other device disconnected');
      }

      final total =
          selected.fold<int>(0, (sum, item) => sum + item.transferred);
      await channel.writer.json(FrameType.transferEnd, {
        'files': selected.length,
        'bytes': total,
      });
      await channel.writer.flush();
      AppLog.info('host', '${peer.id}: all bytes sent, waiting for ackAll');

      // Wait for the receiver's *final* acknowledgement. Per-file acks arrive
      // on the same socket, so keep reading until ackAll (or the peer closes);
      // closing on the first trailing frame would cut the receiver off
      // mid-write.
      final deadline = DateTime.now().add(const Duration(seconds: 20));
      while (true) {
        final remaining = deadline.difference(DateTime.now());
        if (remaining.isNegative) break;
        final ack = await channel.nextOrNull(timeout: remaining);
        if (ack == null) break;
        if (ack.type == FrameType.error) {
          throw ProtocolException(
            ack.json()['message'] as String? ??
                'The other device reported an error',
          );
        }
        if (ack.type == FrameType.ackAll) {
          AppLog.info('host', '${peer.id}: receiver confirmed all files');
          break;
        }
      }
      peer.transferred = total;
      peer.completedFiles = selected.length;
      peer.currentFile = null;
      peer.status = TransferStatus.done;
      _emitPeers();
      events.onPeerFinished?.call(
        peer.id,
        selected.length,
        total,
        stopwatch.elapsed,
      );
      events.onFinished?.call(selected.length, total, stopwatch.elapsed);
      await channel.close();
    } on TimeoutException {
      AppLog.error(
          'host', '${peer.id}: timed out - $peer.name stopped responding');
      _peerFailed(peer, 'The other device stopped responding');
      await channel.close();
    } on ProtocolException catch (error) {
      AppLog.error('host', '${peer.id}: protocol error - ${error.message}');
      _peerFailed(peer, error.message);
      await channel.close();
    } on SocketException catch (error) {
      AppLog.error('host', '${peer.id}: socket error - ${error.message}');
      if (!peer.aborted) {
        _peerFailed(peer, 'Connection lost: ${error.message}');
      }
      await channel.close();
    } on Object catch (error) {
      AppLog.error('host', '${peer.id}: transfer failed - $error');
      _peerFailed(peer, 'Transfer failed: $error');
      await channel.close();
    } finally {
      peer.sending = false;
      peer.finished = true;
      if (_peers.remove(peer.id) != null) {
        AppLog.info(
            'host',
            '${peer.id}: ${peer.name} session ended '
                '(${peer.completedFiles} files done)');
        if (peer.connected) {
          events.onPeerDisconnected?.call(peer.name, peer.platform);
        }
        _emitPeers();
      }
    }
  }

  Future<int> _sendFile(
    FrameChannel channel,
    TransferItem item,
    _HostPeer peer, {
    int startOffset = 0,
  }) async {
    final path = item.path;
    if (path == null) return 0;
    final file = File(path);
    RandomAccessFile handle;
    try {
      handle = await file.open();
    } on FileSystemException {
      await channel.writer.error('Cannot read ${item.name}');
      await channel.writer.flush();
      return 0;
    }

    final requested = startOffset.clamp(0, item.size);
    var offset = requested;
    String? fullDigest;
    Sha256Stream? hash;
    var sent = 0;

    try {
      final fileLength = await file.length();
      if (offset >= item.size || offset >= fileLength) {
        offset = 0;
      }
      if (offset != requested) {
        // The receiver's partial copy is stale; do not count bytes the sender
        // is about to send again.
        peer.transferred -= requested - offset;
      }

      if (offset > 0) {
        // A resumed file must still end with the digest of the whole file, so
        // hash the prefix before seeking to the resume point.
        final prefix = Sha256Stream();
        await handle.setPosition(0);
        var remaining = fileLength;
        while (remaining > 0) {
          final chunk = await handle.read(
            remaining < AppConstants.chunkSize
                ? remaining
                : AppConstants.chunkSize,
          );
          if (chunk.isEmpty) break;
          prefix.add(chunk);
          remaining -= chunk.length;
        }
        fullDigest = prefix.finish();
        await handle.setPosition(offset);
      } else {
        hash = Sha256Stream();
      }

      final relativeSegments =
          item.relativePath?.split('/') ?? const <String>[];
      final relativeDir = relativeSegments.length > 1
          ? relativeSegments.sublist(0, relativeSegments.length - 1).join('/')
          : null;
      await channel.writer.json(FrameType.fileHeader, {
        'id': item.id,
        'name': item.name,
        'size': item.size,
        if (relativeDir != null) 'dir': relativeDir,
        if (offset > 0) 'offset': offset,
      });
      item.transferred = offset;
      item.done = false;
      item.status = TransferStatus.active;
      peer.currentFile = item.name;
      peer.status = TransferStatus.active;
      _emitPeers();
      AppLog.info(
          'host',
          '${peer.id}: sending "${item.name}" '
              '(${formatBytes(item.size)}'
              '${offset > 0 ? ', resuming at ${formatBytes(offset)}' : ''})');

      var completed = false;
      while (!peer.aborted && !channel.isClosed) {
        await _waitIfPaused(peer);
        if (peer.aborted || channel.isClosed) break;
        final chunk = await handle.read(AppConstants.chunkSize);
        if (chunk.isEmpty) {
          completed = true;
          break;
        }
        hash?.add(chunk);
        if (channel.writer.isEncrypted) {
          await channel.writer.frame(FrameType.data, chunk);
        } else {
          channel.writer.beginDataFrame(chunk.length);
          channel.writer.data(chunk);
        }
        await channel.writer.maybeFlush();
        item.transferred += chunk.length;
        sent += chunk.length;
        peer.transferred += chunk.length;
        _emitPeersThrottled(peer);
        events.onProgress?.call(item, sent);
      }

      if (completed && !channel.isClosed && !peer.aborted) {
        final digest = hash?.finish() ?? fullDigest;
        await channel.writer.json(FrameType.fileEnd, {
          'id': item.id,
          'sha256': digest,
        });
        await channel.writer.flush();
        item.sha256 = digest;
        item.done = true;
        item.status = TransferStatus.done;
        peer.completedFiles++;
        peer.currentFile = null;
        _emitPeers();
        AppLog.info(
            'host',
            '${peer.id}: "${item.name}" sent '
                '(${formatBytes(sent + offset)})');
      }
      return sent;
    } on FileSystemException catch (error) {
      AppLog.error(
          'host',
          '${peer.id}: cannot read "${item.name}": '
              '${error.message}');
      item.status = TransferStatus.failed;
      await channel.writer
          .error('Read error on ${item.name}: ${error.message}');
      await channel.writer.flush();
      return sent;
    } finally {
      await handle.close();
    }
  }

  Future<void> _waitIfPaused(_HostPeer peer) async {
    while (_paused && !peer.aborted && !_disposed) {
      final waiter = _resumeWaiter ??= Completer<void>();
      try {
        await waiter.future;
      } on Object {
        break;
      }
    }
  }

  /// Stops streaming to every peer without closing the session. The receiver
  /// sees the current file stop at its current offset.
  Future<void> pauseTransfer({String reason = 'Paused by sender'}) async {
    if (_paused || _disposed) return;
    _paused = true;
    AppLog.info('host', 'pause requested: $reason');
    for (final peer in _peers.values) {
      if (peer.finished || peer.channel.isClosed) continue;
      try {
        await peer.channel.writer.json(FrameType.pause, {'reason': reason});
        await peer.channel.writer.flush();
      } on Object {
        // The peer may already be gone.
      }
    }
  }

  Future<void> resumeTransfer() async {
    if (!_paused) return;
    _paused = false;
    AppLog.info('host', 'resume requested');
    for (final peer in _peers.values) {
      if (peer.finished || peer.channel.isClosed) continue;
      try {
        await peer.channel.writer.json(FrameType.resume, {});
        await peer.channel.writer.flush();
      } on Object {
        // The peer may already be gone.
      }
    }
    final waiter = _resumeWaiter;
    _resumeWaiter = null;
    if (waiter != null && !waiter.isCompleted) waiter.complete();
  }

  /// Aborts the in-flight transfer but keeps the listener alive.
  Future<void> abortTransfer() async {
    _paused = false;
    AppLog.info('host', 'abort requested');
    final waiter = _resumeWaiter;
    _resumeWaiter = null;
    if (waiter != null && !waiter.isCompleted) waiter.complete();
    final peers = _peers.values.toList(growable: false);
    for (final peer in peers) {
      peer.aborted = true;
      peer.status = TransferStatus.failed;
      try {
        await peer.channel.writer
            .json(FrameType.cancel, {'reason': 'cancelled'});
        await peer.channel.writer.flush();
      } on Object {
        // Peer may already be gone.
      }
      await peer.channel.close();
    }
    _peers.clear();
    _emitPeers();
  }

  Future<void> dispose() async {
    _disposed = true;
    await abortTransfer();
    await _server?.close();
    _server = null;
  }

  void _emitPeers() {
    final snapshots = peers;
    events.onPeersChanged?.call(snapshots);
    events.onPeerCountChanged?.call(snapshots.length);
  }

  void _emitPeersThrottled(_HostPeer peer) {
    final now = DateTime.now();
    final last = peer.lastEmit;
    if (last != null && now.difference(last).inMilliseconds < 120) return;
    peer.lastEmit = now;
    _emitPeers();
  }

  void _peerFailed(_HostPeer peer, String message) {
    peer.status = TransferStatus.failed;
    peer.currentFile = null;
    _emitPeers();
    events.onPeerError?.call(peer.id, message);
    // With a single receiver there is no other peer to continue, so the old
    // global error path still drives the UI. In a group, one failure is a
    // per-receiver state, not the end of the session.
    if (_peers.length <= 1) events.onError?.call(message);
  }
}

class _HostPeer {
  _HostPeer(this.id, this.channel);

  final String id;
  final FrameChannel channel;
  String name = 'Nearby device';
  String? platform;
  int protocolVersion = 1;
  bool connected = false;
  bool aborted = false;
  bool sending = false;
  bool finished = false;
  bool encrypted = false;
  List<String> selectedIds = const [];
  int transferred = 0;
  int totalBytes = 0;
  int completedFiles = 0;
  String? currentFile;
  TransferStatus status = TransferStatus.pending;
  DateTime? lastEmit;

  PeerInfo snapshot() => PeerInfo(
        id: id,
        name: name,
        platform: platform,
        selectedIds: selectedIds,
        transferred: transferred,
        totalBytes: totalBytes,
        completedFiles: completedFiles,
        currentFile: currentFile,
        status: status,
      );
}

const _zeroSalt = <int>[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
