import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Controls the Android foreground service that keeps a transfer or a
/// receive-wait running when the app is not in the foreground. On every
/// other platform this is a no-op.
class TransferForeground {
  TransferForeground({
    MethodChannel? channel,
    EventChannel? events,
    bool? supported,
  })  : _channel =
            channel ?? const MethodChannel('com.freesend.free_send/transfer'),
        _events = events ??
            const EventChannel('com.freesend.free_send/transfer_events'),
        _supported = supported ?? Platform.isAndroid;

  final MethodChannel _channel;
  final EventChannel _events;
  final bool _supported;

  bool _started = false;
  DateTime _lastUpdate = DateTime.fromMillisecondsSinceEpoch(0);

  bool get isSupported => _supported;
  bool get isStarted => _started;

  /// Events raised by the native side: `stop_waiting` when the user taps the
  /// notification's stop action, `open_receive` when they tap the body.
  Stream<String> get events {
    if (!_supported) return const Stream.empty();
    return _events.receiveBroadcastStream().handleError((_) {}).cast<String>();
  }

  Future<void> start({
    required String title,
    String? text,
    String? stopLabel,
  }) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>('start', {
        'title': title,
        'text': text,
        if (stopLabel != null) 'stopLabel': stopLabel,
      });
      _started = true;
      _lastUpdate = DateTime.now();
    } on PlatformException {
      // A foreground service is a battery optimisation, not a requirement.
    } on MissingPluginException {
      // Desktop or an older host app.
    } on Object {
      // Never let the notification layer break a transfer.
    }
  }

  Future<void> update({
    required String title,
    String? text,
    Duration throttle = const Duration(seconds: 1),
  }) async {
    if (!_supported || !_started) return;
    final now = DateTime.now();
    if (now.difference(_lastUpdate) < throttle) return;
    _lastUpdate = now;
    try {
      await _channel.invokeMethod<void>('update', {
        'title': title,
        'text': text,
      });
    } on Object {
      // Ignore: the transfer does not depend on the notification.
    }
  }

  Future<void> stop() async {
    if (!_supported) return;
    _started = false;
    try {
      await _channel.invokeMethod<void>('stop');
    } on Object {
      // Ignore.
    }
  }

  @visibleForTesting
  void resetForTest() {
    _started = false;
    _lastUpdate = DateTime.fromMillisecondsSinceEpoch(0);
  }
}
