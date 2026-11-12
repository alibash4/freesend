import 'dart:async';
import 'dart:io';

import 'package:free_send/core/app_constants.dart';
import 'package:free_send/models/transfer_item.dart';
import 'package:free_send/services/transfer/checksum.dart';
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
  });

  final List<TransferItem> items;
  final String deviceName;
  final HostEvents events;
  final String instanceId;

  ServerSocket? _server;
  final Map<String, _HostPeer> _peers = {};
  bool _disposed = false;
  bool _paused = false;
  Completer<void>? _resumeWaiter;
  int _peerCounter = 0;
  int _port = AppConstants.transferPort;

  bool get isListening => _server != null;
  int get port => _port;
  int get peerCount => _peers.length;
  bool get hasPeer => _peers.isNotEmpty;
  List<String> get connectedPeerNames =>
      _peers.values.map((peer) => peer.name).toList(growable: false);

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
          events.onError?.call('Listener problem: $error');
        });
        events.onListening?.call(_port);
        return _port;
      } on SocketException catch (error) {
        lastError = error;
      }
    }
    throw SocketException('No free transfer port ($lastError)');
  }

  void _onConnection(Socket socket) {
    if (_disposed) {
      socket.destroy();
      return;
    }
    final peer = _HostPeer('p${_peerCounter++}', FrameChannel(socket));
    _peers[peer.id] = peer;
    events.onPeerCountChanged?.call(_peers.length);
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
        channel.writer.error(
          'Version mismatch: this device speaks Free Send protocol '
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
      events.onPeerConnected?.call(peer.name, peer.platform);

      channel.writer.json(FrameType.session, {
        'v': AppConstants.protocolVersion,
        'name': deviceName,
        'platform': Platform.operatingSystem,
        'port': _port,
        'files': [for (final item in items) item.toWire()],
        'totalBytes': items.fold<int>(0, (sum, item) => sum + item.size),
        'caps': const ['folders', 'checksums', 'pause'],
      });
      await channel.writer.flush();

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
      final selected =
          items.where((item) => ids.contains(item.id)).toList(growable: false);
      if (selected.isEmpty) {
        channel.writer.error('No files were selected');
        await channel.close();
        return;
      }
      peer.sending = true;
      events.onSelectionAccepted?.call(selected);

      final stopwatch = Stopwatch()..start();
      for (final item in selected) {
        if (peer.aborted || channel.isClosed) break;
        await _sendFile(channel, item, peer);
      }
      stopwatch.stop();

      if (peer.aborted) {
        unawaited(channel.close());
        return;
      }
      if (channel.isClosed) {
        throw ProtocolException('The other device disconnected');
      }

      final total = selected.fold<int>(0, (sum, item) => sum + item.transferred);
      channel.writer.json(FrameType.transferEnd, {
        'files': selected.length,
        'bytes': total,
      });
      await channel.writer.flush();

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
        if (ack.type == FrameType.ackAll) break;
      }
      events.onFinished?.call(selected.length, total, stopwatch.elapsed);
      await channel.close();
    } on TimeoutException {
      events.onError?.call('The other device stopped responding');
      await channel.close();
    } on ProtocolException catch (error) {
      events.onError?.call(error.message);
      await channel.close();
    } on SocketException catch (error) {
      if (!peer.aborted) {
        events.onError?.call('Connection lost: ${error.message}');
      }
      await channel.close();
    } on Object catch (error) {
      events.onError?.call('Transfer failed: $error');
      await channel.close();
    } finally {
      peer.sending = false;
      peer.finished = true;
      if (_peers.remove(peer.id) != null) {
        if (peer.connected) {
          events.onPeerDisconnected?.call(peer.name, peer.platform);
        }
        events.onPeerCountChanged?.call(_peers.length);
      }
    }
  }

  Future<int> _sendFile(
    FrameChannel channel,
    TransferItem item,
    _HostPeer peer,
  ) async {
    final path = item.path;
    if (path == null) return 0;
    final file = File(path);
    RandomAccessFile handle;
    try {
      handle = await file.open();
    } on FileSystemException {
      channel.writer.error('Cannot read ${item.name}');
      await channel.writer.flush();
      return 0;
    }

    final hash = Sha256Stream();
    final relativeSegments = item.relativePath?.split('/') ?? const <String>[];
    final relativeDir = relativeSegments.length > 1
        ? relativeSegments.sublist(0, relativeSegments.length - 1).join('/')
        : null;
    channel.writer.json(FrameType.fileHeader, {
      'id': item.id,
      'name': item.name,
      'size': item.size,
      if (relativeDir != null) 'dir': relativeDir,
    });
    item.transferred = 0;
    item.done = false;
    item.status = TransferStatus.active;
    var sent = 0;
    var completed = false;
    try {
      while (!peer.aborted && !channel.isClosed) {
        await _waitIfPaused(peer);
        if (peer.aborted || channel.isClosed) break;
        final chunk = await handle.read(AppConstants.chunkSize);
        if (chunk.isEmpty) {
          completed = true;
          break;
        }
        hash.add(chunk);
        channel.writer.beginDataFrame(chunk.length);
        channel.writer.data(chunk);
        await channel.writer.maybeFlush();
        item.transferred += chunk.length;
        sent += chunk.length;
        events.onProgress?.call(item, sent);
      }
    } on FileSystemException catch (error) {
      item.status = TransferStatus.failed;
      channel.writer.error('Read error on ${item.name}: ${error.message}');
      await channel.writer.flush();
    } finally {
      await handle.close();
    }

    if (completed && !channel.isClosed && !peer.aborted) {
      final digest = hash.finish();
      channel.writer.json(FrameType.fileEnd, {
        'id': item.id,
        'sha256': digest,
      });
      await channel.writer.flush();
      item.sha256 = digest;
      item.done = true;
      item.status = TransferStatus.done;
    }
    return sent;
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
    for (final peer in _peers.values) {
      if (peer.finished || peer.channel.isClosed) continue;
      try {
        peer.channel.writer.json(FrameType.pause, {'reason': reason});
        await peer.channel.writer.flush();
      } on Object {
        // The peer may already be gone.
      }
    }
  }

  Future<void> resumeTransfer() async {
    if (!_paused) return;
    _paused = false;
    for (final peer in _peers.values) {
      if (peer.finished || peer.channel.isClosed) continue;
      try {
        peer.channel.writer.json(FrameType.resume, {});
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
    final waiter = _resumeWaiter;
    _resumeWaiter = null;
    if (waiter != null && !waiter.isCompleted) waiter.complete();
    final peers = _peers.values.toList(growable: false);
    for (final peer in peers) {
      peer.aborted = true;
      try {
        peer.channel.writer.json(FrameType.cancel, {'reason': 'cancelled'});
        await peer.channel.writer.flush();
      } on Object {
        // Peer may already be gone.
      }
      await peer.channel.close();
    }
    _peers.clear();
    events.onPeerCountChanged?.call(0);
  }

  Future<void> dispose() async {
    _disposed = true;
    await abortTransfer();
    await _server?.close();
    _server = null;
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
}