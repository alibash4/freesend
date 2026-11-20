import 'dart:async';
import 'dart:io';

import 'package:free_send/services/app_logger.dart';
import 'package:free_send/services/transfer/protocol.dart';

/// A sender asking a receiver to accept files.
///
/// The knock carries everything the receiver needs to show the authorization
/// modal, plus where to reach the sender's file server afterwards.
class Knock {
  const Knock({
    required this.requestId,
    required this.senderInstanceId,
    required this.senderName,
    required this.platform,
    required this.fileCount,
    required this.totalBytes,
    required this.senderHost,
    required this.senderPort,
    required this.socket,
  });

  final String requestId;
  final String senderInstanceId;
  final String senderName;
  final String platform;
  final int fileCount;
  final int totalBytes;

  /// The sender's file server, which the receiver dials back after accepting.
  final String senderHost;
  final int senderPort;

  /// The connection the answer is written to.
  final Socket socket;

  Map<String, Object?> encode() => {
        'rid': requestId,
        'id': senderInstanceId,
        'name': senderName,
        'pf': platform,
        'count': fileCount,
        'bytes': totalBytes,
        'host': senderHost,
        'port': senderPort,
      };

  static Knock? tryParse(Frame frame, Socket socket) {
    if (frame.type != FrameType.knock) return null;
    final json = frame.json();
    final requestId = json['rid'];
    final instanceId = json['id'];
    final host = json['host'];
    final port = json['port'];
    if (requestId is! String ||
        instanceId is! String ||
        host is! String ||
        port is! int) {
      return null;
    }
    return Knock(
      requestId: requestId,
      senderInstanceId: instanceId,
      senderName: (json['name'] as String?) ?? 'Nearby device',
      platform: (json['pf'] as String?) ?? 'unknown',
      fileCount: (json['count'] as num?)?.toInt() ?? 0,
      totalBytes: (json['bytes'] as num?)?.toInt() ?? 0,
      senderHost: host,
      senderPort: port,
      socket: socket,
    );
  }
}

enum KnockOutcome { accepted, declined, timedOut }

/// The receiver's front door.
///
/// It listens on its own TCP port, reports every knock through [onKnock], and
/// writes the user's answer back on the same connection when [decide] is
/// called. One doorbell serves a whole session, not one peer.
class ConsentDoorbell {
  ServerSocket? _server;
  final Map<String, Socket> _open = {};

  /// Called for each knock. It must return quickly; the answer comes later.
  void Function(Knock knock)? onKnock;

  bool get isListening => _server != null;
  int? get port => _server?.port;

  Future<void> start({int? port}) async {
    if (_server != null) return;
    final server = await ServerSocket.bind(InternetAddress.anyIPv4, port ?? 0);
    _server = server;
    server.listen(_handle, onError: (Object error) {
      AppLog.error('knock', 'doorbell listener failed: $error');
    });
    AppLog.info('knock', 'doorbell listening on :${server.port}');
  }

  void _handle(Socket socket) {
    AppLog.debug(
        'knock',
        'connection from '
            '${socket.remoteAddress.address}:${socket.remotePort}');
    final reader = FrameReader(
      (frame) {
        final knock = Knock.tryParse(frame, socket);
        if (knock == null) {
          AppLog.warn(
              'knock',
              'dropped malformed frame '
                  'type=${FrameType.nameOf(frame.type)} from '
                  '${socket.remoteAddress.address}');
          socket.destroy();
          return;
        }
        _open[knock.requestId] = socket;
        AppLog.info(
          'knock',
          '${knock.senderName} asks for ${knock.fileCount} files '
              '(${knock.totalBytes} bytes) -> '
              '${knock.senderHost}:${knock.senderPort} '
              '[${knock.requestId}]',
        );
        onKnock?.call(knock);
      },
      onError: (Object error) {
        AppLog.warn(
            'knock',
            'bad frame from '
                '${socket.remoteAddress.address}: $error');
        socket.destroy();
      },
    );
    socket.listen(
      reader.add,
      onError: (Object error) {
        AppLog.debug(
            'knock',
            'knocker '
                '${socket.remoteAddress.address} went away: $error');
      },
      onDone: () {},
      cancelOnError: true,
    );
  }

  /// Answers a knock. Returns false when the request is unknown or already
  /// gone, so a late tap never crashes the sender.
  Future<bool> decide(String requestId, bool accepted) async {
    final socket = _open.remove(requestId);
    if (socket == null) {
      AppLog.warn('consent', 'answer for unknown request $requestId');
      return false;
    }
    AppLog.info(
        'consent', 'answered $requestId: ${accepted ? 'accept' : 'decline'}');
    try {
      socket.add(
        FrameCodec.json(FrameType.knockReply, {
          'rid': requestId,
          'ok': accepted,
        }),
      );
      await socket.flush();
      AppLog.debug(
          'knock',
          'reply for $requestId sent '
              '(${accepted ? 'accept' : 'decline'})');
    } on Object catch (error) {
      // The sender hung up; there is nobody to answer.
      AppLog.debug('knock', 'reply for $requestId failed: $error');
    } finally {
      socket.destroy();
    }
    return true;
  }

  /// Drops every open knock unanswered and stops listening.
  Future<void> stop() async {
    final sockets = _open.values.toList();
    _open.clear();
    for (final socket in sockets) {
      socket.destroy();
    }
    await _server?.close();
    _server = null;
    AppLog.info('knock', 'doorbell stopped');
  }
}

/// Sender side: knock once and wait for the answer.
abstract final class KnockClient {
  static Future<KnockOutcome> send({
    required String host,
    required int port,
    required String senderInstanceId,
    required String senderName,
    required String platform,
    required int fileCount,
    required int totalBytes,
    required String fileServerHost,
    required int fileServerPort,
    Duration timeout = const Duration(seconds: 20),
  }) async {
    final requestId = DateTime.now().microsecondsSinceEpoch.toString();
    Socket? socket;
    AppLog.info(
        'knock',
        'knocking $host:$port as "$senderName" '
            '($fileCount files, $totalBytes bytes, file server '
            '$fileServerHost:$fileServerPort)');
    try {
      socket = await Socket.connect(host, port, timeout: timeout);
      AppLog.debug('knock', 'connected to $host:$port, waiting for answer');
      final answer = Completer<Frame>();
      final reader = FrameReader(
        (frame) {
          if (!answer.isCompleted) answer.complete(frame);
        },
        onError: (error) {
          if (!answer.isCompleted) answer.completeError(error);
        },
      );
      socket.listen(
        reader.add,
        onError: (_) {},
        onDone: () {
          if (!answer.isCompleted) {
            answer.completeError(
              const SocketException('The receiver closed the door'),
            );
          }
        },
        cancelOnError: true,
      );
      socket.add(
        FrameCodec.json(FrameType.knock, {
          'rid': requestId,
          'id': senderInstanceId,
          'name': senderName,
          'pf': platform,
          'count': fileCount,
          'bytes': totalBytes,
          'host': fileServerHost,
          'port': fileServerPort,
        }),
      );
      await socket.flush();
      final frame = await answer.future.timeout(timeout);
      if (frame.type != FrameType.knockReply) {
        AppLog.warn(
            'knock',
            '$host:$port replied with unexpected '
                '${FrameType.nameOf(frame.type)}');
        return KnockOutcome.declined;
      }
      final accepted = frame.json()['ok'] == true;
      AppLog.info(
          'consent',
          '$host:$port answered '
              '${accepted ? 'accepted' : 'declined'}');
      return accepted ? KnockOutcome.accepted : KnockOutcome.declined;
    } on SocketException catch (error) {
      AppLog.warn('knock', 'no answer from $host:$port ($error)');
      return KnockOutcome.timedOut;
    } on TimeoutException {
      AppLog.warn('knock', 'timed out waiting for $host:$port');
      return KnockOutcome.timedOut;
    } on Object catch (error) {
      AppLog.error('knock', 'failed to knock $host:$port: $error');
      return KnockOutcome.timedOut;
    } finally {
      socket?.destroy();
    }
  }
}
