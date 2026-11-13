import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:free_send/core/app_constants.dart';
import 'package:free_send/models/trusted_device.dart';
import 'package:free_send/services/device_identity.dart';
import 'package:free_send/services/local_store.dart';
import 'package:free_send/core/format.dart';
import 'package:free_send/models/transfer_item.dart';
import 'package:free_send/services/transfer/checksum.dart';
import 'package:free_send/services/transfer/frame_channel.dart';
import 'package:free_send/services/transfer/protocol.dart';
import 'package:free_send/services/transfer/secure_channel.dart';

/// What the host offers after the handshake.
class TransferManifest {
  TransferManifest({
    required this.hostName,
    required this.hostPlatform,
    required this.items,
    this.hostInstanceId,
    this.encrypted = false,
    this.securityCode,
  });

  final String hostName;
  final String? hostPlatform;
  final List<TransferItem> items;
  final String? hostInstanceId;
  final bool encrypted;
  final String? securityCode;

  int get totalBytes => items.fold<int>(0, (sum, item) => sum + item.size);
}

class ClientEvents {
  const ClientEvents({
    this.onProgress,
    this.onStatus,
    this.onFinished,
    this.onError,
    this.onRemoteClosed,
  });

  final void Function(TransferItem item, int bytesReceived)? onProgress;
  final void Function(TransferItem item)? onStatus;
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
    this.store,
  });

  final String deviceName;
  final ClientEvents events;
  final String instanceId;
  final LocalStore? store;

  FrameChannel? _channel;
  bool _cancelled = false;
  bool _finished = false;
  bool _pausedByReceiver = false;
  Completer<void>? _resumeWaiter;

  bool get isConnected => _channel != null && !_channel!.isClosed;
  bool get isPaused => _pausedByReceiver;

  Future<TransferManifest> connect(
    String host,
    int port, {
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final socket = await Socket.connect(host, port, timeout: timeout);
    final channel = FrameChannel(socket);
    _channel = channel;
    try {
      final handshake = await SecureHandshake.create();
      final clientPublicKey = await handshake.publicKey;
      await channel.writer.json(FrameType.hello, {
        'v': AppConstants.protocolVersion,
        'name': deviceName,
        'platform': Platform.operatingSystem,
        'key': base64.encode(clientPublicKey),
        'nonce': base64.encode(handshake.salt),
        'caps': const ['checksums', 'resume', 'encryption'],
      });
      await channel.writer.flush();

      var frame = await channel.next(timeout: timeout);
      if (frame.type == FrameType.helloAck) {
        final ack = frame.json();
        final hostKey = (ack['key'] as String?) ?? '';
        final instance = (ack['instanceId'] as String?) ?? '';
        final identity = (ack['identity'] as String?) ?? '';
        final signature = (ack['signature'] as String?) ?? '';
        if (hostKey.isEmpty) {
          throw ProtocolException('The sender did not provide a key');
        }
        if (identity.isNotEmpty && signature.isNotEmpty) {
          final signed = utf8.encode(
            '$hostKey|${base64.encode(handshake.salt)}|$instance',
          );
          final trusted = store?.trustedDevices
              .where((device) => device.instanceId == instance)
              .toList(growable: false);
          if (trusted != null && trusted.isNotEmpty) {
            if (trusted.first.publicKey != identity) {
              throw ProtocolException(
                'This sender\'s identity changed. Stop and verify the device '
                'before sending anything.',
              );
            }
          } else {
            final valid = await DeviceIdentity.verify(
              signed,
              base64.decode(signature),
              identity,
            );
            if (!valid) {
              throw ProtocolException('The sender\'s identity signature is invalid');
            }
            if (store != null) {
              await store!.trustDevice(TrustedDevice(
                instanceId: instance,
                name: (ack['name'] as String?) ?? 'Nearby device',
                publicKey: identity,
                fingerprint: (ack['fingerprint'] as String?) ?? '',
                addedAt: DateTime.now(),
              ));
            }
          }
        }
        final key = await handshake.derive(base64.decode(hostKey));
        final cipher = SecureChannel(key);
        channel.useCipher(encrypt: cipher.seal, decrypt: cipher.open);
        await channel.writer.json(FrameType.helloConfirm, {});
        await channel.writer.flush();
        frame = await channel.next(timeout: timeout);
      }

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
        hostInstanceId: json['instanceId'] as String?,
        encrypted: channel.isEncrypted,
        securityCode: json['fingerprint'] as String?,
      );
    } on Object {
      await channel.close();
      _channel = null;
      rethrow;
    }
  }

  /// Writes every accepted file under [downloadRoot], creating a
  /// `FreeSend` subfolder when the root is a shared directory.
  Future<void> receive({
    required List<String> ids,
    required String downloadRoot,
    Map<String, String> retryPaths = const <String, String>{},
    Map<String, String> resumePaths = const <String, String>{},
    Map<String, int> resumeOffsets = const <String, int>{},
    int baseBytes = 0,
  }) async {
    final channel = _channel;
    if (channel == null) throw ProtocolException('Not connected');

    final stopwatch = Stopwatch()..start();
    var receivedFiles = 0;
    var receivedBytes = baseBytes;

    await channel.writer.json(FrameType.accept, {
      'ids': ids,
      'offsets': resumeOffsets,
      'caps': const ['checksums', 'resume'],
    });
    await channel.writer.flush();

    RandomAccessFile? handle;
    TransferItem? current;
    Sha256Stream? hash;
    String? expectedSha;
    final taken = <String>{};

    try {
      while (!_cancelled) {
        if (_pausedByReceiver) {
          await (_resumeWaiter ??= Completer<void>()).future;
        }
        final frame = await channel.next(timeout: const Duration(minutes: 15));
        switch (frame.type) {
          case FrameType.fileHeader:
            final json = frame.json();
            final id = (json['id'] as String?) ?? '';
            final rawName = (json['name'] as String?) ?? 'file';
            final size = (json['size'] as num?)?.toInt() ?? 0;
            final rawRelative = json['dir'] as String?;
            final relative = rawRelative == null || rawRelative.isEmpty
                ? null
                : rawRelative.replaceAll('\\', '/');
            final retryPath = retryPaths[id];
            final resumePath = resumePaths[id];
            final reusePath = retryPath ?? resumePath;
            var offset = retryPath != null
                ? 0
                : (resumeOffsets[id] ?? 0).clamp(0, size);
            final root = Directory(downloadRoot);
            if (!await root.exists()) {
              await root.create(recursive: true);
            }

            final String parent;
            final String targetPath;
            final String name;
            if (reusePath != null) {
              // A retry overwrites the partial file it left behind rather
              // than creating "name (1).ext" next to it.
              final reuseFile = File(reusePath);
              parent = reuseFile.parent.path;
              if (!await reuseFile.parent.exists()) {
                await reuseFile.parent.create(recursive: true);
              }
              targetPath = reuseFile.path;
              name = reuseFile.uri.pathSegments.last;
            } else {
              final unique = uniqueFileName(sanitizeFileName(rawName), taken);
              taken.add(unique.toLowerCase());
              parent = relative == null
                  ? root.path
                  : '${root.path}${Platform.pathSeparator}'
                      '${relative.replaceAll('/', Platform.pathSeparator)}';
              if (relative != null) {
                await Directory(parent).create(recursive: true);
              }
              targetPath = '$parent${Platform.pathSeparator}$unique';
              name = unique;
            }

            final target = File(targetPath);
            if (offset > 0 &&
                await target.exists() &&
                await target.length() >= offset) {
              handle = await target.open(mode: FileMode.append);
              await handle.truncate(offset);
            } else {
              offset = 0;
              handle = await target.open(mode: FileMode.write);
            }

            hash = Sha256Stream();
            if (offset > 0) {
              // The digest at file end covers the whole file, so the bytes
              // already on disk have to be folded in before the new ones.
              final prefix = await target.open();
              try {
                var remaining = offset;
                while (remaining > 0) {
                  final chunk = await prefix.read(
                    remaining < AppConstants.chunkSize
                        ? remaining
                        : AppConstants.chunkSize,
                  );
                  if (chunk.isEmpty) break;
                  hash.add(chunk);
                  remaining -= chunk.length;
                }
                if (remaining > 0) {
                  // The partial file is shorter than the sidecar claimed;
                  // start over instead of padding it.
                  await handle.close();
                  handle = await target.open(mode: FileMode.write);
                  offset = 0;
                  hash = Sha256Stream();
                }
              } finally {
                await prefix.close();
              }
            }

            current = TransferItem(
              id: id,
              name: name,
              size: size,
              path: target.path,
              receivedPath: target.path,
              relativePath: relative,
              transferred: offset,
              sha256: json['sha256'] as String?,
              status: TransferStatus.active,
            );
            expectedSha = json['sha256'] as String?;
            events.onStatus?.call(current);
            break;

          case FrameType.data:
            final file = current;
            final raf = handle;
            if (file == null || raf == null) {
              throw ProtocolException('Received data before a file header');
            }
            hash?.add(frame.payload);
            await raf.writeFrom(frame.payload);
            file.transferred += frame.payload.length;
            receivedBytes += frame.payload.length;
            events.onProgress?.call(file, receivedBytes);
            break;

          case FrameType.fileEnd:
            final file = current;
            if (file != null) {
              final json = frame.json();
              final digest = hash?.finish();
              final wanted = (json['sha256'] as String?) ??
                  expectedSha ??
                  file.sha256;
              if (file.transferred != file.size) {
                // A short file is corrupt; surface it rather than silently
                // leaving a truncated file on disk.
                throw ProtocolException(
                  '${file.name} arrived incomplete '
                  '(${formatBytes(file.transferred)} of ${formatBytes(file.size)})',
                );
              }
              if (wanted != null && digest != null && wanted != digest) {
                throw ProtocolException(
                  '${file.name} failed its checksum; the copy is corrupt.',
                );
              }
              file.done = true;
              file.status = TransferStatus.done;
              file.sha256 = digest ?? wanted;
              events.onStatus?.call(file);
              events.onProgress?.call(file, receivedBytes);
              receivedFiles++;
            }
            await handle?.close();
            handle = null;
            current = null;
            hash = null;
            expectedSha = null;
            await channel.writer.json(FrameType.ackFile, {'id': file?.id ?? ''});
            await channel.writer.flush();
            break;

          case FrameType.pause:
            final file = current;
            if (file != null) {
              file.status = TransferStatus.paused;
              events.onStatus?.call(file);
            }
            break;

          case FrameType.resume:
            final file = current;
            if (file != null) {
              file.status = TransferStatus.active;
              events.onStatus?.call(file);
            }
            break;

          case FrameType.transferEnd:
            // All file data is on disk and verified at this point; a failure to
            // deliver the courtesy ack must not turn a good transfer bad.
            if (!channel.isClosed) {
              try {
                await channel.writer.json(FrameType.ackAll, {'bytes': receivedBytes});
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
      if (current != null) {
        current.status = TransferStatus.failed;
        events.onStatus?.call(current);
      }
      if (_cancelled) {
        events.onRemoteClosed?.call();
      } else if (!_finished) {
        events.onError?.call(error.message);
      }
      rethrow;
    } on SocketException catch (error) {
      await handle?.close();
      handle = null;
      if (current != null) {
        current.status = TransferStatus.failed;
        events.onStatus?.call(current);
      }
      if (!_cancelled && !_finished) {
        events.onError?.call('Connection lost: ${error.message}');
      }
      rethrow;
    } finally {
      await handle?.close();
    }
  }

  /// Stops reading from the socket so the sender blocks on write. The session
  /// stays open, so resuming continues the current file from its last offset.
  Future<void> pause() async {
    if (_pausedByReceiver) return;
    _pausedByReceiver = true;
    final channel = _channel;
    if (channel == null) return;
    channel.pause();
    if (!channel.isClosed) {
      try {
        await channel.writer.json(FrameType.pause, {'reason': 'Paused by receiver'});
        await channel.writer.flush();
      } on Object {
        // The peer may already be gone; the local pause still holds.
      }
    }
  }

  Future<void> resume() async {
    if (!_pausedByReceiver) return;
    _pausedByReceiver = false;
    final waiter = _resumeWaiter;
    _resumeWaiter = null;
    final channel = _channel;
    channel?.resume();
    if (channel != null && !channel.isClosed) {
      try {
        await channel.writer.json(FrameType.resume, {});
        await channel.writer.flush();
      } on Object {
        // Nothing to do: the local stream still resumes.
      }
    }
    if (waiter != null && !waiter.isCompleted) waiter.complete();
  }

  Future<void> cancel() async {
    _cancelled = true;
    final waiter = _resumeWaiter;
    _resumeWaiter = null;
    if (waiter != null && !waiter.isCompleted) waiter.complete();
    final channel = _channel;
    if (channel != null) {
      channel.resume();
      if (!channel.isClosed) {
        try {
          await channel.writer.json(FrameType.cancel, {'reason': 'cancelled'});
          await channel.writer.flush();
        } on Object {
          // Peer already gone.
        }
      }
      await channel.close();
    }
    _channel = null;
    _pausedByReceiver = false;
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
