import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:free_send/services/local_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late LocalStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    dir = await Directory.systemTemp.createTemp('free_send_recent');
    store = LocalStore();
    await store.init();
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('remembers files newest first and skips duplicates', () async {
    final a = File('${dir.path}/a.txt')..writeAsStringSync('a');
    final b = File('${dir.path}/b.txt')..writeAsStringSync('b');

    await store.addRecentFiles([a]);
    await store.addRecentFiles([b]);
    await store.addRecentFiles([a]);

    final recents = store.recentFiles;
    expect(recents.map((entry) => entry.name), ['a.txt', 'b.txt']);
    expect(recents.first.path, a.path);
    expect(recents.first.size, 1);
  });

  test('keeps a missing path so the UI can filter it', () async {
    final a = File('${dir.path}/gone.txt')..writeAsStringSync('gone');
    await store.addRecentFiles([a]);
    a.deleteSync();

    // The path is kept in storage, but the UI filters it before showing it.
    expect(store.recentFiles.single.path, a.path);
    expect(File(store.recentFiles.single.path).existsSync(), isFalse);
  });
}