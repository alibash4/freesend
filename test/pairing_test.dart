import 'package:flutter_test/flutter_test.dart';

import 'package:free_send/services/pairing_code.dart';

/// The pairing code is scanned off a screen, so it has to survive a round trip
/// unchanged and has to refuse anything it did not create.
void main() {
  const full = PairingCode(
    ssid: 'FreeSend-Pixel 7',
    password: 'a&b+c d/#?é=',
    host: '192.168.43.1',
    port: 47891,
    senderName: 'Pixel 7',
    senderPlatform: 'Android',
  );

  test('round-trips a full code, including awkward characters', () {
    final raw = full.encode();
    final parsed = PairingCode.tryParse(raw);

    expect(parsed, isNotNull);
    expect(parsed!.ssid, full.ssid);
    expect(parsed.password, full.password);
    expect(parsed.host, full.host);
    expect(parsed.port, full.port);
    expect(parsed.senderName, full.senderName);
    expect(parsed.senderPlatform, full.senderPlatform);
    expect(parsed.hasHotspot, isTrue);
  });

  test('stays small enough to scan on a phone screen', () {
    // A ~130 character payload fits a version 7 QR code, which still resolves
    // at the 176pt the card renders it at.
    expect(full.encode().length, lessThan(200));
  });

  test('an address-only code pairs without a hotspot', () {
    const code = PairingCode(host: '10.0.0.5', port: 47812, senderName: 'Mac');
    final parsed = PairingCode.tryParse(code.encode());

    expect(parsed, isNotNull);
    expect(parsed!.hasHotspot, isFalse);
    expect(parsed.hasAddress, isTrue);
    expect(parsed.isUsable, isTrue);
    expect(parsed.port, 47812);
    expect(parsed.label, 'Mac');
  });

  test('rejects payloads that are not ours', () {
    const rejected = [
      '',
      'just some text',
      'https://example.com/pair?ssid=FreeSend&host=192.168.43.1',
      // Unknown version: the fields could mean something else entirely.
      'freesend://pair?v=2&ssid=FreeSend&host=192.168.43.1',
      // Nothing to join and nothing to connect to.
      'freesend://pair?v=1&port=47811',
      'freesend://pair?v=1&ssid=FreeSend&port=70000',
      'freesend://pair?v=1&host=192.168.43.1&port=0',
    ];
    for (final raw in rejected) {
      expect(PairingCode.tryParse(raw), isNull, reason: raw);
    }
  });

  test('never trusts a hostname where an address is expected', () {
    final code = PairingCode.tryParse(
      'freesend://pair?v=1&ssid=FreeSend&host=example.com',
    );

    expect(code, isNotNull);
    expect(code!.hasAddress, isFalse, reason: 'no DNS lookups from a QR code');
    expect(code.isUsable, isTrue, reason: 'the hotspot is still joinable');
  });

  test('tolerates a code that was copied with whitespace around it', () {
    final parsed = PairingCode.tryParse('  ${full.encode()}\n');
    expect(parsed?.host, full.host);
  });
}
