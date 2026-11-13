import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:free_send/services/transfer/transfer_foreground.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.freesend.free_send/transfer');
  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('starts, updates, and stops the foreground service', () async {
    final foreground = TransferForeground(channel: channel, supported: true);

    await foreground.start(title: 'Receiving files', text: '2 files');
    expect(foreground.isStarted, isTrue);
    await foreground.update(
      title: 'Receiving 50%',
      text: 'clip.bin',
      throttle: Duration.zero,
    );
    await foreground.stop();
    expect(foreground.isStarted, isFalse);

    expect(calls.map((call) => call.method), ['start', 'update', 'stop']);
    expect(calls.first.arguments, {
      'title': 'Receiving files',
      'text': '2 files',
    });
  });

  test('throttles notification updates', () async {
    final foreground = TransferForeground(channel: channel, supported: true);
    await foreground.start(title: 'Sending', text: '1 file');
    await foreground.update(title: 'Sending 1%', text: 'a.bin');
    await foreground.update(title: 'Sending 2%', text: 'a.bin');

    expect(calls.where((call) => call.method == 'update'), isEmpty);
  });

  test('is a no-op off Android', () async {
    final foreground = TransferForeground(channel: channel, supported: false);
    await foreground.start(title: 'Sending', text: '1 file');
    await foreground.update(title: 'Sending 1%');
    await foreground.stop();

    expect(calls, isEmpty);
    expect(foreground.isStarted, isFalse);
  });
}