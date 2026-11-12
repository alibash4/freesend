import 'dart:typed_data';

import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';

/// Incremental SHA-256 so a file can be hashed while it is being streamed,
/// without a second read from disk.
class Sha256Stream {
  final AccumulatorSink<Digest> _sink = AccumulatorSink<Digest>();
  late final _input = sha256.startChunkedConversion(_sink);

  void add(Uint8List bytes) => _input.add(bytes);

  String finish() {
    _input.close();
    return _sink.events.single.toString();
  }
}