import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Controls the Android foreground service that keeps a transfer running when
/// the app is not in the foreground. On every other platform this is a no-op.
class TransferForeground {
  TransferForeground({
    MethodChannel? channel,
    bool? supported,
  })  : _channel = channel ??
            const MethodChannel('com.freesend.free_send/transfer'),
        _supported = supported ?? Platform.isAndroid;

  final MethodChannel _channel;
  final bool _supported;

  bool _started = false;
  DateTime _lastUpdate = DateTime.fromMillisecondsSinceEpoch(0);

  bool get isSupported => _supported;
  bool get isStarted => _started;

  Future<void> start({required String title, String? text}) async {
    if (!_supported) return;
    try {
      await _channel.invokeMethod<void>('start', {
        'title': title,
        'text': text,
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