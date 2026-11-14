import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:free_send/services/transfer/protocol.dart';

/// Turns a socket into an await-able sequence of frames plus a buffered writer.
///
/// Reading is pull-based (`next()`), which serialises file writes on the
/// receiving side and gives natural backpressure through TCP.
class FrameChannel {
  FrameChannel(this.socket) {
    try {
      socket.setOption(SocketOption.tcpNoDelay, true);
    } on Object {
      // Not fatal: some desktop stacks ignore this option.
    }
    writer = FrameWriter(socket);
    // A write to a reset socket surfaces on `done`; with no listener that error
    // escapes as an unhandled async error in the app's zone.
    unawaited(socket.done.then<void>((_) {}, onError: (Object _) {}));
    _reader = FrameReader(_onFrame, onError: _fail);
    // Keep the subscription alive after an error: a reset connection often
    // reports a second error, and with `cancelOnError` that one would reach the
    // zone's uncaught handler instead of being folded into `_fail`.
    _subscription = socket.listen(
      _reader.add,
      onError: _fail,
      onDone: _markClosed,
      cancelOnError: false,
    );
  }

  final Socket socket;
  late final FrameWriter writer;
  late final FrameReader _reader;
  late final StreamSubscription<Uint8List> _subscription;

  final _pending = <Frame>[];
  Completer<Frame>? _waiter;
  Object? _error;
  bool _closed = false;
  bool _paused = false;
  Future<Uint8List> Function(Uint8List)? _decrypt;
  Future<void> _deliverQueue = Future<void>.value();
  Completer<void>? _resumeWaiter;

  bool get isClosed => _closed || _error != null;
  bool get isPaused => _paused;
  bool get isEncrypted => _decrypt != null;

  /// Switches every frame written and read from now on through [cipher].
  void useCipher({
    required Future<Uint8List> Function(Uint8List) encrypt,
    required Future<Uint8List> Function(Uint8List) decrypt,
  }) {
    _decrypt = decrypt;
    writer.useCipher(encrypt);
  }

  /// Stops reading from the socket. The OS receive window then fills and the
  /// sender blocks on write, which is what gives the receiver real control over
  /// how fast bytes arrive.
  void pause() {
    if (_paused || _closed) return;
    _paused = true;
    _subscription.pause();
  }

  void resume() {
    if (!_paused) return;
    _paused = false;
    _subscription.resume();
    final waiter = _resumeWaiter;
    _resumeWaiter = null;
    if (waiter != null && !waiter.isCompleted) waiter.complete();
  }

  Future<void> get whenResumed {
    if (!_paused) return Future<void>.value();
    _resumeWaiter ??= Completer<void>();
    return _resumeWaiter!.future;
  }

  Future<Frame> next({Duration timeout = const Duration(minutes: 5)}) async {
    if (_paused) await whenResumed;
    if (_pending.isNotEmpty) {
      return _pending.removeAt(0);
    }
    if (_error != null) return Future.error(_error!);
    if (_closed) {
      return Future.error(ProtocolException('The other device closed the connection'));
    }
    final completer = Completer<Frame>();
    _waiter = completer;
    return completer.future.timeout(timeout, onTimeout: () {
      if (identical(_waiter, completer)) _waiter = null;
      throw TimeoutException('Timed out waiting for the other device', timeout);
    });
  }

  void _onFrame(Frame frame) {
    // Decrypt one frame at a time so a slow cipher cannot reorder the stream.
    _deliverQueue = _deliverQueue.then((_) => _deliver(frame));
  }

  Future<void> _deliver(Frame frame) async {
    if (frame.type == FrameType.secure) {
      final decrypt = _decrypt;
      if (decrypt == null) {
        _fail(ProtocolException('Encrypted frame arrived before the handshake'));
        return;
      }
      try {
        final plain = await decrypt(frame.payload);
        frame = Frame(FrameCodec.typeOf(plain), plain.sublist(5));
      } on Object catch (error) {
        _fail(error);
        return;
      }
    }
    if (_error != null || _closed) return;
    final waiter = _waiter;
    if (waiter != null && !waiter.isCompleted) {
      _waiter = null;
      waiter.complete(frame);
      return;
    }
    _pending.add(frame);
  }

  void _fail(Object error) {
    if (_error != null) return;
    _error = error is ProtocolException
        ? error
        : ProtocolException(error.toString());
    final waiter = _waiter;
    _waiter = null;
    if (waiter != null && !waiter.isCompleted) {
      waiter.completeError(_error!);
    }
  }

  void _markClosed() {
    _closed = true;
    final waiter = _waiter;
    _waiter = null;
    if (waiter != null && !waiter.isCompleted) {
      waiter.completeError(
        ProtocolException('The other device closed the connection'),
      );
    }
  }

  /// Returns the next frame, or null when the peer closes cleanly.
  Future<Frame?> nextOrNull({Duration timeout = const Duration(seconds: 30)}) async {
    try {
      return await next(timeout: timeout);
    } catch (_) {
      return null;
    }
  }

  Future<void> close() async {
    try {
      await socket.flush();
    } on Object {
      // Ignore: the socket may already be gone.
    }
    try {
      await _subscription.cancel();
    } on Object {
      // Ignore.
    }
    socket.destroy();
    _closed = true;
  }
}
