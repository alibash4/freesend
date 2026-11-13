import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:free_send/services/device_identity.dart';
import 'package:free_send/services/transfer/secure_channel.dart';

void main() {
  test('both sides derive the same session key', () async {
    final client = await SecureHandshake.create();
    final host = await SecureHandshake.withSalt(client.salt);

    final hostKey = await host.derive(await client.publicKey);
    final clientKey = await client.derive(await host.publicKey);

    final hostCipher = SecureChannel(hostKey);
    final clientCipher = SecureChannel(clientKey);
    final sealed = await hostCipher.seal(utf8.encode('hello FreeSend'));
    expect(utf8.decode(await clientCipher.open(sealed)), 'hello FreeSend');
  });

  test('a tampered frame is rejected', () async {
    final host = await SecureHandshake.create();
    final client = await SecureHandshake.create();
    final hostCipher = SecureChannel(await host.derive(await client.publicKey));
    final clientCipher = SecureChannel(await client.derive(await host.publicKey));

    final sealed = await hostCipher.seal(utf8.encode('payload'));
    sealed[sealed.length - 1] ^= 0x01;
    await expectLater(clientCipher.open(sealed), throwsA(isA<Object>()));
  });

  test('a mismatched key cannot open the frame', () async {
    final client = await SecureHandshake.create();
    final host = await SecureHandshake.withSalt(client.salt);
    final other = await SecureHandshake.create();

    final hostCipher = SecureChannel(await host.derive(await client.publicKey));
    final wrong = SecureChannel(await other.derive(await client.publicKey));
    final sealed = await hostCipher.seal(utf8.encode('secret'));
    await expectLater(wrong.open(sealed), throwsA(isA<Object>()));
  });

  test('device identity signatures verify and reject tampering', () async {
    final identity = await DeviceIdentity.load(null);
    final message = utf8.encode('free send');
    final signature = await identity.sign(message);

    expect(
      await DeviceIdentity.verify(message, signature, identity.publicKeyBase64),
      isTrue,
    );
    message[0] ^= 0x01;
    expect(
      await DeviceIdentity.verify(message, signature, identity.publicKeyBase64),
      isFalse,
    );
    expect(identity.fingerprint, isNotEmpty);
    expect(Uint8List(0), isA<Uint8List>());
  });
}
