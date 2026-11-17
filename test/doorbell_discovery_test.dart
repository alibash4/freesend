import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:free_send/services/discovery_service.dart';
import 'package:free_send/services/transfer/doorbell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('sender-driven discovery', () {
    test('a seeker finds a responder that is sitting in Receive', () async {
      final responder = PresenceResponder();
      await responder.start(
        ownInstanceId: 'receiver-1',
        deviceName: 'Pixel 8',
        platform: 'Android',
        consentPort: 47811,
      );
      addTearDown(responder.stop);

      final seeker = SessionSeeker();
      await seeker.start(
        ownInstanceId: 'sender-1',
        deviceName: 'Desk Mini',
        platform: 'Linux',
      );
      addTearDown(seeker.stop);

      final found = await _waitFor(
        () => seeker.current,
        predicate: (candidates) => candidates.isNotEmpty,
      );

      expect(found, hasLength(1));
      expect(found.first.deviceName, 'Pixel 8');
      expect(found.first.platform, 'Android');
      expect(found.first.consentPort, 47811);
      expect(found.first.instanceId, 'receiver-1');
      // The answer arrives from whichever interface the packet used, so only
      // the presence of an address matters here.
      expect(found.first.ip, isNotEmpty);
    });

    test('the seeker never reports its own answers', () async {
      final seeker = SessionSeeker();
      await seeker.start(
        ownInstanceId: 'same-device',
        deviceName: 'Desk Mini',
        platform: 'Linux',
      );
      addTearDown(seeker.stop);
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(seeker.current, isEmpty);
    });

    test('a candidate drops off after it stops answering', () async {
      final responder = PresenceResponder();
      await responder.start(
        ownInstanceId: 'receiver-2',
        deviceName: 'MacBook',
        platform: 'macOS',
        consentPort: 47811,
      );

      final seeker = SessionSeeker(ttl: const Duration(milliseconds: 200));
      await seeker.start(
        ownInstanceId: 'sender-2',
        deviceName: 'Desk Mini',
        platform: 'Linux',
      );
      addTearDown(seeker.stop);

      await _waitFor(
        () => seeker.current,
        predicate: (candidates) => candidates.isNotEmpty,
      );
      await responder.stop();
      final pruned = await _waitFor(
        () => seeker.current.length,
        predicate: (count) => count == 0,
        timeout: const Duration(seconds: 5),
      );
      expect(pruned, 0);
    });
  });

  group('doorbell', () {
    test('a knock is delivered with the sender details and accepted',
        () async {
      final doorbell = ConsentDoorbell();
      await doorbell.start();
      addTearDown(doorbell.stop);

      Knock? received;
      doorbell.onKnock = (knock) => received = knock;

      final answer = KnockClient.send(
        host: InternetAddress.loopbackIPv4.address,
        port: doorbell.port!,
        senderInstanceId: 'sender-1',
        senderName: 'Desk Mini',
        platform: 'Linux',
        fileCount: 12,
        totalBytes: 640 * 1024 * 1024,
        fileServerHost: InternetAddress.loopbackIPv4.address,
        fileServerPort: 47811,
      );

      await _waitFor(() => received, predicate: (knock) => knock != null);
      expect(received!.senderName, 'Desk Mini');
      expect(received!.fileCount, 12);
      expect(received!.totalBytes, 640 * 1024 * 1024);
      expect(received!.senderPort, 47811);
      expect(received!.requestId, isNotEmpty);

      await doorbell.decide(received!.requestId, true);
      expect(await answer, KnockOutcome.accepted);
    });

    test('a decline reaches the sender as a decline', () async {
      final doorbell = ConsentDoorbell();
      await doorbell.start();
      addTearDown(doorbell.stop);

      Knock? received;
      doorbell.onKnock = (knock) => received = knock;

      final answer = KnockClient.send(
        host: InternetAddress.loopbackIPv4.address,
        port: doorbell.port!,
        senderInstanceId: 'sender-2',
        senderName: 'Pixel 8',
        platform: 'Android',
        fileCount: 1,
        totalBytes: 1024,
        fileServerHost: InternetAddress.loopbackIPv4.address,
        fileServerPort: 47811,
      );

      await _waitFor(() => received, predicate: (knock) => knock != null);
      await doorbell.decide(received!.requestId, false);
      expect(await answer, KnockOutcome.declined);
    });

    test('an unanswered knock never blocks a later decision', () async {
      final doorbell = ConsentDoorbell();
      await doorbell.start();
      addTearDown(doorbell.stop);
      var knocks = 0;
      doorbell.onKnock = (_) => knocks++;

      final lost = KnockClient.send(
        host: InternetAddress.loopbackIPv4.address,
        port: doorbell.port!,
        senderInstanceId: 'sender-3',
        senderName: 'Pixel 8',
        platform: 'Android',
        fileCount: 1,
        totalBytes: 1024,
        fileServerHost: InternetAddress.loopbackIPv4.address,
        fileServerPort: 47811,
        timeout: const Duration(milliseconds: 200),
      );
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(knocks, 1);
      // Deciding after the sender gave up must not throw.
      expect(await doorbell.decide('missing-request', true), isFalse);
      expect(await lost, anyOf(KnockOutcome.accepted, KnockOutcome.timedOut));
    });

    test('a knock to a closed port times out', () async {
      final outcome = await KnockClient.send(
        host: InternetAddress.loopbackIPv4.address,
        port: 1,
        senderInstanceId: 'sender-4',
        senderName: 'Pixel 8',
        platform: 'Android',
        fileCount: 1,
        totalBytes: 1,
        fileServerHost: InternetAddress.loopbackIPv4.address,
        fileServerPort: 47811,
        timeout: const Duration(milliseconds: 300),
      );
      expect(outcome, KnockOutcome.timedOut);
    });
  });
}

/// Polls [read] until [predicate] accepts the value, or fails the test.
Future<T> _waitFor<T>(
  T Function() read, {
  required bool Function(T value) predicate,
  Duration timeout = const Duration(seconds: 5),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final value = read();
    if (predicate(value)) return value;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  return read();
}