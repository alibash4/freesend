import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

enum LogLevel { debug, info, warn, error }

class LogEntry {
  const LogEntry(this.time, this.level, this.tag, this.message);

  final DateTime time;
  final LogLevel level;
  final String tag;
  final String message;

  String format() =>
      '[${time.toIso8601String()}] ${level.name.toUpperCase().padRight(5)} '
      '$tag: $message';
}

/// Ring-buffer logger that always writes to a file, so a release build can be
/// diagnosed after the fact, and mirrors to the console in debug builds.
///
/// Every stage of the transfer flow tags its lines: `seeker`, `responder`,
/// `knock`, `consent`, `host`, `hotspot`.
abstract final class AppLog {
  static const int maxEntries = 3000;

  /// Bumps on every write so a listener can refresh without polling.
  static final ValueNotifier<int> revision = ValueNotifier<int>(0);

  static final List<LogEntry> _entries = <LogEntry>[];
  static File? _file;
  static bool _initialised = false;

  /// In-memory snapshot, oldest first.
  static List<LogEntry> get entries => List.unmodifiable(_entries);

  static Future<void> init() async {
    if (_initialised) return;
    _initialised = true;
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/freesend.log');
      // Keep the previous run rather than growing without bound.
      if (await file.exists()) {
        await file.rename('${dir.path}/freesend.previous.log');
      }
      await file.create(recursive: true);
      _file = file;
      await _append('--- FreeSend log opened ${DateTime.now().toIso8601String()} ---');
    } on Object catch (error) {
      // Logging must never break a transfer.
      debugPrint('FreeSend: log file unavailable ($error)');
    }
  }

  static void log(LogLevel level, String tag, String message) {
    final entry = LogEntry(DateTime.now(), level, tag, message);
    _entries.add(entry);
    if (_entries.length > maxEntries) {
      _entries.removeRange(0, _entries.length - maxEntries);
    }
    final line = entry.format();
    if (kDebugMode) debugPrint(line);
    revision.value++;
    unawaited(_append(line));
  }

  static void debug(String tag, String message) =>
      log(LogLevel.debug, tag, message);

  static void info(String tag, String message) =>
      log(LogLevel.info, tag, message);

  static void warn(String tag, String message) =>
      log(LogLevel.warn, tag, message);

  static void error(String tag, String message) =>
      log(LogLevel.error, tag, message);

  static Future<void> _append(String line) async {
    final file = _file;
    if (file == null) return;
    try {
      await file.writeAsString('$line\n', mode: FileMode.append);
    } on Object {
      // Disk full or removed; keep the in-memory buffer.
    }
  }

  /// Everything currently buffered, oldest first, ready to paste.
  static String dump() =>
      _entries.map((entry) => entry.format()).join('\n');

  /// Writes the whole buffer somewhere the user can attach it to a report.
  static Future<String> dumpToFile() async {
    final dir = await getApplicationDocumentsDirectory();
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final file = File('${dir.path}/freesend-log-$stamp.txt');
    await file.writeAsString(dump());
    return file.path;
  }

  static Future<void> clear() async {
    _entries.clear();
    revision.value++;
    await _append('--- cleared ${DateTime.now().toIso8601String()} ---');
  }
}