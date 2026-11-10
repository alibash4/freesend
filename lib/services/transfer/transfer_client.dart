import 'dart:async';
import 'dart:io';

import 'package:free_send/core/app_constants.dart';
import 'package:free_send/core/format.dart';
import 'package:free_send/models/transfer_item.dart';
import 'package:free_send/services/transfer/frame_channel.dart';
import 'package:free_send/services/transfer/protocol.dart';

/// What the host offers after the handshake.
class TransferManifest {
  TransferManifest({
    required this.hostName,
    required this.hostPlatform,
    required this.items,
  });

  final String hostName;
  final String? hostPlatform;
  final List<TransferItem> items;

  int get totalBytes => items.fold<int>(0, (sum, item) => sum + item.size);
}

class ClientEvents {
  const ClientEvents({
    this.onProgress,
    this.onFinished,
    this.onError,
    this.onRemoteClosed,
  });

  final void Function(TransferItem item, int bytesReceived)? onProgress;
  final void Function(int fileCount, int bytes, Duration elapsed)? onFinished;
  final void Function(String message)? onError;
  final void Function()? onRemoteClosed;
}

/// Connects to a host and writes received frames to disk.
class TransferClient {
  TransferClient({
    required this.deviceName,
    required this.events,
    required this.instanceId,
  });

  final String deviceName;
  final ClientEvents events;
  final String instanceId;

  FrameChannel? _channel;
  bool _cancelled = false;
  bool _finished = false;

  bool get isConnected => _channel != null && !_channel!.isClosed;

  Future<TransferManifest> connect(
    String host,
    int port, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final socket = await Socket.connect(host, port, timeout: timeout);
    final channel = FrameChannel(socket);
    _channel = channel;
    try {
      channel.writer.json(FrameType.hello, {
        'v': AppConstants.protocolVersion,
        'name': deviceName,
        'platform': Platform.operatingSystem,
      });
      await channel.writer.flush();

      final frame = await channel.next(timeout: timeout);
      if (frame.type == FrameType.error) {
        throw ProtocolException(
          frame.json()['message'] as String? ?? 'The other device refused the connection',
        );
      }
      if (frame.type != FrameType.session) {
        throw ProtocolException('Unexpected reply from the other device');
      }
      final json = frame.json();
      final files = (json['files'] as List<Object?>? ?? const [])
          .whereType<Map<String, Object?>>()
          .map(TransferItem.fromWire)
          .toList();
      return TransferManifest(
        hostName: (json['name'] as String?) ?? 'Nearby device',
        hostPlatform: json['platform'] as String?,
        items: files,
      );
    } on Object {
      await channel.close();
      _channel = null;
      rethrow;
    }
  }

  /// Writes every accepted file under [downloadRoot], creating a
  /// `Free Send` subfolder when the root is a shared directory.
  Future<void> receive({
    required List<String> ids,
    required String downloadRoot,
  }) async {
    final channel = _channel;
    if (channel == null) throw ProtocolException('Not connected');

    final stopwatch = Stopwatch()..start();
    var receivedFiles = 0;
    var receivedBytes = 0;

    channel.writer.json(FrameType.accept, {'ids': ids});
    await channel.writer.flush();

    RandomAccessFile? handle;
    TransferItem? current;
    final taken = <String>{};

    try {
      while (!_cancelled) {
        final frame = await channel.next(timeout: const Duration(minutes: 15));
        switch (frame.type) {
          case FrameType.fileHeader:
            final json = frame.json();
            final name = sanitizeFileName((json['name'] as String?) ?? 'file');
            final size = (json['size'] as num?)?.toInt() ?? 0;
            final unique = uniqueFileName(name, taken);
            taken.add(unique.toLowerCase());
            final dir = Directory(downloadRoot);
            if (!await dir.exists()) {
              await dir.create(recursive: true);
            }
            final target = File('${dir.path}${Platform.pathSeparator}$unique');
            handle = await target.open(mode: FileMode.write);
            current = TransferItem(
              id: (json['id'] as String?) ?? '',
              name: unique,
              size: size,
              path: target.path,
              receivedPath: target.path,
            );
            break;

          case FrameType.data:
            final file = current;
            final raf = handle;
            if (file == null || raf == null) {
              throw ProtocolException('Received data before a file header');
            }
            await raf.writeFrom(frame.payload);
            file.transferred += frame.payload.length;
            receivedBytes += frame.payload.length;
            events.onProgress?.call(file, receivedBytes);
            break;

          case FrameType.fileEnd:
            final file = current;
            if (file != null) {
              file.done = true;
              if (file.transferred != file.size) {
                // A short file is corrupt; surface it rather than silently
                // leaving a truncated file on disk.
                throw ProtocolException(
                  '${file.name} arrived incomplete '
                  '(${formatBytes(file.transferred)} of ${formatBytes(file.size)})',
                );
              }
              events.onProgress?.call(file, receivedBytes);
              receivedFiles++;
            }
            await handle?.close();
            handle = null;
            current = null;
            channel.writer.json(FrameType.ackFile, {'id': file?.id ?? ''});
            await channel.writer.flush();
            break;

          case FrameType.transferEnd:
            // All file data is on disk and verified at this point; a failure to
            // deliver the courtesy ack must not turn a good transfer bad.
            if (!channel.isClosed) {
              try {
                channel.writer.json(FrameType.ackAll, {'bytes': receivedBytes});
                await channel.writer.flush();
              } on Object {
                // The host may already have closed its side.
              }
            }
            stopwatch.stop();
            _finished = true;
            events.onFinished?.call(receivedFiles, receivedBytes, stopwatch.elapsed);
            return;

          case FrameType.error:
            throw ProtocolException(
              frame.json()['message'] as String? ?? 'The other device reported an error',
            );

          case FrameType.cancel:
            throw ProtocolException('The other device cancelled the transfer');

          default:
            // Ignore unknown frames so a newer minor version can add fields.
            break;
        }
      }
      throw ProtocolException('Transfer cancelled');
    } on ProtocolException catch (error) {
      await handle?.close();
      handle = null;
      if (_cancelled) {
        events.onRemoteClosed?.call();
      } else if (!_finished) {
        events.onError?.call(error.message);
      }
      rethrow;
    } on SocketException catch (error) {
      await handle?.close();
      handle = null;
      if (!_cancelled && !_finished) {
        events.onError?.call('Connection lost: ${error.message}');
      }
      rethrow;
    } finally {
      await handle?.close();
    }
  }

  Future<void> cancel() async {
    _cancelled = true;
    final channel = _channel;
    if (channel != null) {
      if (!channel.isClosed) {
        try {
          channel.writer.json(FrameType.cancel, {'reason': 'cancelled'});
          await channel.writer.flush();
        } on Object {
          // Peer already gone.
        }
      }
      await channel.close();
    }
    _channel = null;
  }

  Future<void> dispose() async {
    if (!_finished) {
      await cancel();
    } else {
      await _channel?.close();
      _channel = null;
    }
  }
}
