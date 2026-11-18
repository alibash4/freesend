import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// Frame layout: `[type: u8][payloadLength: u32 BE][payload]`.
///
/// Data frames carry raw bytes; every other frame carries UTF-8 JSON. TCP is
/// already reliable and ordered, so the protocol deliberately has no
/// per-chunk acknowledgement — only per-file ones, which keeps the pipe full.
abstract final class FrameType {
  static const hello = 1;
  static const session = 2;
  static const accept = 3;
  static const fileHeader = 4;
  static const data = 5;
  static const fileEnd = 6;
  static const transferEnd = 7;
  static const ackFile = 8;
  static const ackAll = 9;
  static const error = 10;
  static const cancel = 11;
  /// The sender is stopping the current file but keeping the session alive.
  static const pause = 12;
  /// The receiver wants the current file continued from its current offset.
  static const resume = 13;
  /// Per-file status for UI that is not the active transfer screen.
  static const fileStatus = 14;
  /// Server's ephemeral key and identity signature for the encrypted handshake.
  static const helloAck = 15;
  /// Receiver acknowledges the ephemeral key, so the host can start sending
  /// encrypted frames only after both sides have switched ciphers.
  static const helloConfirm = 16;
  /// Outer envelope for an encrypted frame. The payload is the sealed frame.
  static const secure = 17;
  /// A sender asking a receiver to accept files. Carries identity, file count,
  /// size, and the sender's file-server address so the receiver can dial back.
  static const knock = 18;
  /// The receiver's answer to a knock.
  static const knockReply = 19;
}

class Frame {
  const Frame(this.type, this.payload);
  final int type;
  final Uint8List payload;

  Map<String, Object?> json() {
    if (payload.isEmpty) return const {};
    final decoded = jsonDecode(utf8.decode(payload));
    return decoded is Map<String, Object?> ? decoded : const {};
  }
}

class ProtocolException implements Exception {
  ProtocolException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Encodes control frames. Data frames bypass this and write the 5-byte header
/// plus the payload directly, so large chunks are never copied twice.
abstract final class FrameCodec {
  static Uint8List header(int type, int length) {
    final header = Uint8List(5);
    header[0] = type;
    ByteData.view(header.buffer).setUint32(1, length, Endian.big);
    return header;
  }

  static Uint8List json(int type, Map<String, Object?> payload) {
    final body = utf8.encode(jsonEncode(payload));
    final frame = Uint8List(5 + body.length);
    frame[0] = type;
    ByteData.view(frame.buffer).setUint32(1, body.length, Endian.big);
    frame.setRange(5, frame.length, body);
    return frame;
  }

  static int typeOf(Uint8List frame) => frame[0];

  static int lengthOf(Uint8List frame) =>
      ByteData.sublistView(frame, 1, 5).getUint32(0, Endian.big);
}

/// Reassembles frames from arbitrary TCP chunk boundaries.
class FrameReader {
  FrameReader(this._onFrame, {this.onError});

  final void Function(Frame frame) _onFrame;
  final void Function(Object error)? onError;

  Uint8List _buffer = Uint8List(64 * 1024);
  int _start = 0;
  int _end = 0;

  void add(Uint8List chunk) {
    try {
      _append(chunk);
      while (_end - _start >= 5) {
        final available = _end - _start;
        final length = ByteData.sublistView(
          _buffer,
          _start + 1,
          _start + 5,
        ).getUint32(0, Endian.big);
        if (length > 8 * 1024 * 1024) {
          throw ProtocolException('Frame too large ($length bytes)');
        }
        if (available < 5 + length) break;
        final type = _buffer[_start];
        final payload = Uint8List.fromList(
          Uint8List.sublistView(_buffer, _start + 5, _start + 5 + length),
        );
        _start += 5 + length;
        _onFrame(Frame(type, payload));
      }
      _compact();
    } on Object catch (error) {
      onError?.call(error);
    }
  }

  void _append(Uint8List chunk) {
    final needed = _end + chunk.length;
    if (needed <= _buffer.length) {
      _buffer.setRange(_end, needed, chunk);
      _end = needed;
      return;
    }
    var grown = _buffer.length * 2;
    while (grown < needed) {
      grown *= 2;
    }
    final next = Uint8List(grown);
    next.setRange(0, _end - _start, Uint8List.sublistView(_buffer, _start, _end));
    _end -= _start;
    _start = 0;
    next.setRange(_end, _end + chunk.length, chunk);
    _end += chunk.length;
    _buffer = next;
  }

  void _compact() {
    if (_start == 0) return;
    if (_start == _end) {
      _start = 0;
      _end = 0;
      return;
    }
    // Reclaim the consumed prefix once it dominates the buffer.
    if (_start > 256 * 1024 && _start * 2 > _buffer.length) {
      final remaining = _end - _start;
      _buffer.setRange(0, remaining, Uint8List.sublistView(_buffer, _start, _end));
      _start = 0;
      _end = remaining;
    }
  }
}

/// Buffered writer that never awaits a syscall per chunk.
class FrameWriter {
  FrameWriter(this._socket);

  final Socket _socket;
  int _pending = 0;
  static const _flushThreshold = 4 * 1024 * 1024;
  Future<Uint8List> Function(Uint8List)? _encrypt;

  bool get isEncrypted => _encrypt != null;

  void useCipher(Future<Uint8List> Function(Uint8List) encrypt) {
    _encrypt = encrypt;
  }

  Future<void> json(int type, Map<String, Object?> payload) =>
      _write(FrameCodec.json(type, payload));

  Future<void> frame(int type, List<int> payload) {
    final body = Uint8List.fromList(payload);
    final frame = Uint8List(5 + body.length);
    frame[0] = type;
    ByteData.view(frame.buffer).setUint32(1, body.length, Endian.big);
    frame.setRange(5, frame.length, body);
    return _write(frame);
  }

  Future<void> _write(Uint8List frame) async {
    final encrypt = _encrypt;
    if (encrypt == null) {
      _socket.add(frame);
      _pending += frame.length;
      return;
    }
    final out = await encrypt(frame);
    _socket.add(FrameCodec.header(FrameType.secure, out.length));
    _socket.add(out);
    _pending += out.length + 5;
  }

  void beginDataFrame(int length) {
    _socket.add(FrameCodec.header(FrameType.data, length));
  }

  void data(Uint8List chunk) {
    _socket.add(chunk);
    _pending += chunk.length;
  }

  /// Only drains the socket buffer once it has grown to a few megabytes, which
  /// keeps the network pipe saturated without unbounded memory growth.
  Future<void> maybeFlush({bool force = false}) async {
    if (!force && _pending < _flushThreshold) return;
    _pending = 0;
    await _socket.flush();
  }

  Future<void> flush() async {
    _pending = 0;
    await _socket.flush();
  }

  Future<void> error(String message) =>
      json(FrameType.error, {'message': message});
}

const u8Empty = <int>[];
