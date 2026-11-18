import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:free_send/services/discovery_service.dart';
import 'package:free_send/services/transfer/doorbell.dart';

/// A private port: a FreeSend instance running on the same machine would
/// otherwise answer the test's intent packets.
const testDiscoveryPort = 47821;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('sender-driven discovery', () {
    testWidgets('a seeker finds a responder that is sitting in Receive', (
      tester,
    ) async {
      final responder = PresenceResponder();
      final listening = await tester.runAsync(
        () => responder.start(
          ownInstanceId: 'receiver-1',
          deviceName: 'Pixel 8',
          platform: 'Android',
          consentPort: 47811,
          discoveryPort: testDiscoveryPort,
        ),
      );
      expect(listening, isTrue, reason: 'responder must bind the test port');
      addTearDown(responder.stop);

      final seeker = SessionSeeker();
      await tester.runAsync(
        () => seeker.start(
          ownInstanceId: 'sender-1',
          deviceName: 'Desk Mini',
          platform: 'Linux',
          discoveryPort: testDiscoveryPort,
        ),
      );
      addTearDown(seeker.stop);

      final found = await tester.runAsync(
        () => _waitFor(
          () => seeker.current,
          predicate: (candidates) => candidates.isNotEmpty,
        ),
      );

      final candidate = found!.single;
      expect(candidate.deviceName, 'Pixel 8');
      expect(candidate.platform, 'Android');
      expect(candidate.consentPort, 47811);
      expect(candidate.instanceId, 'receiver-1');
      // The answer arrives from whichever interface the packet used, so only
      // the presence of an address matters here.
      expect(candidate.ip, isNotEmpty);
    });

    testWidgets('the seeker never reports its own answers', (tester) async {
      final seeker = SessionSeeker();
      await tester.runAsync(
        () => seeker.start(
          ownInstanceId: 'same-device',
          deviceName: 'Desk Mini',
          platform: 'Linux',
          discoveryPort: testDiscoveryPort,
        ),
      );
      addTearDown(seeker.stop);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      expect(seeker.current, isEmpty);
    });

    testWidgets('a candidate drops off after it stops answering', (tester) async {
      final responder = PresenceResponder();
      await tester.runAsync(
        () => responder.start(
          ownInstanceId: 'receiver-2',
          deviceName: 'MacBook',
          platform: 'macOS',
          consentPort: 47811,
          discoveryPort: testDiscoveryPort,
        ),
      );

      final seeker = SessionSeeker(ttl: const Duration(milliseconds: 200));
      await tester.runAsync(
        () => seeker.start(
          ownInstanceId: 'sender-2',
          deviceName: 'Desk Mini',
          platform: 'Linux',
          discoveryPort: testDiscoveryPort,
        ),
      );
      addTearDown(seeker.stop);

      await tester.runAsync(
        () => _waitFor(
          () => seeker.current,
          predicate: (candidates) => candidates.isNotEmpty,
        ),
      );
      await tester.runAsync(responder.stop);
      final pruned = await tester.runAsync(
        () => _waitFor(
          () => seeker.current.length,
          predicate: (count) => count == 0,
          timeout: const Duration(seconds: 5),
        ),
      );
      expect(pruned, 0);
    });
  });

  group('doorbell', () {
    testWidgets('a knock is delivered with the sender details and accepted', (
      tester,
    ) async {
      final doorbell = ConsentDoorbell();
      await tester.runAsync(doorbell.start);
      final port = doorbell.port!;
      addTearDown(doorbell.stop);

      Knock? received;
      doorbell.onKnock = (knock) => received = knock;

      // One real-async window: the knock must be in flight before we can answer.
      final answer = await tester.runAsync(() async {
        final pending = KnockClient.send(
          host: InternetAddress.loopbackIPv4.address,
          port: port,
          senderInstanceId: 'sender-1',
          senderName: 'Desk Mini',
          platform: 'Linux',
          fileCount: 12,
          totalBytes: 640 * 1024 * 1024,
          fileServerHost: InternetAddress.loopbackIPv4.address,
          fileServerPort: 47811,
        );
        await _waitFor(() => received, predicate: (knock) => knock != null);
        await doorbell.decide(received!.requestId, true);
        return pending;
      });

      expect(received!.senderName, 'Desk Mini');
      expect(received!.fileCount, 12);
      expect(received!.totalBytes, 640 * 1024 * 1024);
      expect(received!.senderPort, 47811);
      expect(received!.requestId, isNotEmpty);
      expect(answer, KnockOutcome.accepted);
    });

    testWidgets('a decline reaches the sender as a decline', (tester) async {
      final doorbell = ConsentDoorbell();
      await tester.runAsync(doorbell.start);
      final port = doorbell.port!;
      addTearDown(doorbell.stop);

      Knock? received;
      doorbell.onKnock = (knock) => received = knock;

      final answer = await tester.runAsync(() async {
        final pending = KnockClient.send(
          host: InternetAddress.loopbackIPv4.address,
          port: port,
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
        return pending;
      });
      expect(answer, KnockOutcome.declined);
    });

    testWidgets('an unanswered knock never blocks a later decision', (
      tester,
    ) async {
      final doorbell = ConsentDoorbell();
      await tester.runAsync(doorbell.start);
      addTearDown(doorbell.stop);
      var knocks = 0;
      doorbell.onKnock = (_) => knocks++;

      await tester.runAsync(() async {
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
        expect(await doorbell.decide('missing', true), isFalse);
        await lost;
      });
    });

    testWidgets('a knock to a closed port times out', (tester) async {
      final outcome = await tester.runAsync(
        () => KnockClient.send(
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
        ),
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