import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:crypto/crypto.dart';

import 'package:free_send/services/local_store.dart';

/// Long-term Ed25519 identity for this device. The seed is stored locally and
/// never leaves the device; the public key is pinned on peers the first time
/// they connect.
class DeviceIdentity {
  DeviceIdentity._(this._keyPair, this._publicBytes);

  final SimpleKeyPair _keyPair;
  final Uint8List _publicBytes;

  static Future<DeviceIdentity> load(LocalStore? store) async {
    final seed = store?.deviceIdentitySeed;
    final algorithm = Ed25519();
    SimpleKeyPair? loaded;
    if (seed != null && seed.isNotEmpty) {
      try {
        loaded = await algorithm.newKeyPairFromSeed(base64.decode(seed));
      } on Object {
        loaded = null;
      }
    } else {
      loaded = null;
    }
    if (loaded != null) {
      final public = await loaded.extractPublicKey();
      return DeviceIdentity._(loaded, Uint8List.fromList(public.bytes));
    }
    final keyPair = await algorithm.newKeyPair();
    await _persist(store, keyPair);
    final public = await keyPair.extractPublicKey();
    return DeviceIdentity._(keyPair, Uint8List.fromList(public.bytes));
  }

  static Future<void> _persist(LocalStore? store, SimpleKeyPair keyPair) async {
    if (store == null) return;
    final seed = await keyPair.extractPrivateKeyBytes();
    await store.saveDeviceIdentity(
      seed: base64.encode(seed),
      publicKey: base64.encode((await keyPair.extractPublicKey()).bytes),
    );
  }

  String get publicKeyBase64 => base64.encode(_publicBytes);
  String get fingerprint {
    final digest = sha256.convert(_publicBytes).bytes;
    final hex = digest
        .take(8)
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();
    return hex.toUpperCase().replaceAllMapped(
      RegExp(r'(.{4})'),
      (match) => '${match.group(0)} ',
    ).trim();
  }

  Future<Uint8List> sign(List<int> message) async {
    final signature = await Ed25519().sign(message, keyPair: _keyPair);
    return Uint8List.fromList(signature.bytes);
  }

  static Future<bool> verify(
    List<int> message,
    List<int> signature,
    String publicKeyBase64,
  ) async {
    try {
      final key = SimplePublicKey(
        base64.decode(publicKeyBase64),
        type: KeyPairType.ed25519,
      );
      return await Ed25519().verify(
        message,
        signature: Signature(signature, publicKey: key),
      );
    } on Object {
      return false;
    }
  }
}
