import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// X25519 + HKDF-SHA256 + AES-256-GCM session cipher. Every frame after the
/// handshake is sealed with a fresh 96-bit nonce.
class SecureChannel {
  SecureChannel(this._key) : _aes = AesGcm.with256bits();

  final SecretKey _key;
  final AesGcm _aes;

  Future<Uint8List> seal(Uint8List plain) async {
    final nonce = _randomBytes(_aes.nonceLength);
    final box = await _aes.encrypt(
      plain,
      secretKey: _key,
      nonce: nonce,
    );
    return Uint8List.fromList(box.concatenation(nonce: true, mac: true));
  }

  Future<Uint8List> open(Uint8List sealed) async {
    if (sealed.length <= _aes.nonceLength + 16) {
      throw const SecureChannelException('Encrypted frame is too short');
    }
    final nonce = sealed.sublist(0, _aes.nonceLength);
    final mac = Mac(sealed.sublist(sealed.length - 16));
    final cipher = sealed.sublist(_aes.nonceLength, sealed.length - 16);
    final plain = await _aes.decrypt(
      SecretBox(cipher, nonce: nonce, mac: mac),
      secretKey: _key,
    );
    return Uint8List.fromList(plain);
  }
}

class SecureChannelException implements Exception {
  const SecureChannelException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// One side of the ephemeral X25519 exchange. The salt is public and is sent
/// in the clear so both sides run HKDF with the same info.
class SecureHandshake {
  SecureHandshake._(this._local, this.salt);

  final SimpleKeyPair _local;
  final Uint8List salt;

  static Future<SecureHandshake> create() async {
    final local = await X25519().newKeyPair();
    return SecureHandshake._(local, _randomBytes(16));
  }

  static Future<SecureHandshake> withSalt(Uint8List salt) async {
    final local = await X25519().newKeyPair();
    return SecureHandshake._(local, salt);
  }

  static Future<SecureHandshake> fromKeyPair(
    SimpleKeyPair local,
    Uint8List salt,
  ) async {
    return SecureHandshake._(local, salt);
  }

  Future<Uint8List> get publicKey async {
    final key = await _local.extractPublicKey();
    return Uint8List.fromList(key.bytes);
  }

  Future<SecretKey> derive(List<int> remotePublicKeyBytes) async {
    final remote = SimplePublicKey(
      remotePublicKeyBytes,
      type: KeyPairType.x25519,
    );
    final shared = await X25519().sharedSecretKey(
      keyPair: _local,
      remotePublicKey: remote,
    );
    final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
    final material = await hkdf.deriveKey(
      secretKey: shared,
      nonce: salt,
      info: utf8.encode('FreeSend/transfer/v3'),
    );
    return SecretKey(await material.extractBytes());
  }
}

Uint8List _randomBytes(int length) {
  final random = Random.secure();
  return Uint8List.fromList(
    List<int>.generate(length, (_) => random.nextInt(256)),
  );
}