import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:free_send/models/peer_info.dart';
import 'package:free_send/models/transfer_item.dart';
import 'package:free_send/services/transfer/frame_channel.dart';
import 'package:free_send/services/transfer/protocol.dart';
import 'package:free_send/services/transfer/transfer_client.dart';
import 'package:free_send/services/transfer/transfer_host.dart';

/// End-to-end exercise of the real socket protocol on localhost: host serves
/// files, client writes them to disk, bytes must match and callbacks must fire.
void main() {
  late Directory sourceDir;
  late Directory targetDir;

  setUp(() async {
    sourceDir = await Directory.systemTemp.createTemp('free_send_src');
    targetDir = await Directory.systemTemp.createTemp('free_send_dst');
  });

  tearDown(() async {
    for (final dir in [sourceDir, targetDir]) {
      if (await dir.exists()) await dir.delete(recursive: true);
    }
  });

  Future<File> writeRandomFile(String name, int bytes) async {
    final file = File('${sourceDir.path}${Platform.pathSeparator}$name');
    final random = Random(7);
    final chunk = Uint8List(bytes);
    for (var i = 0; i < bytes; i++) {
      chunk[i] = random.nextInt(256);
    }
    await file.writeAsBytes(chunk, flush: true);
    return file;
  }

  test('transfers multiple files with matching contents', () async {
    final small = await writeRandomFile('notes.txt', 1200);
    final large = await writeRandomFile('clip.bin', 3 * 1024 * 1024 + 17);

    final items = [
      TransferItem.fromFile(small)!..id = 'f0',
      TransferItem.fromFile(large)!..id = 'f1',
    ];

    final hostFinished = Completer<(int, int)>();
    final host = TransferHost(
      items: items,
      deviceName: 'Sender',
      instanceId: 'host1',
      events: HostEvents(
        onPeerConnected: (name, platform) {},
        onProgress: (item, _) {},
        onFinished: (files, bytes, elapsed) =>
            hostFinished.complete((files, bytes)),
        onError: (message) => hostFinished.completeError(StateError(message)),
      ),
    );
    final port = await host.start();
    addTearDown(host.dispose);

    final received = <String, int>{};
    final client = TransferClient(
      deviceName: 'Receiver',
      instanceId: 'client1',
      events: ClientEvents(
        onProgress: (item, _) => received[item.name] = item.transferred,
        onError: (message) => fail('client error: $message'),
      ),
    );
    addTearDown(client.dispose);

    final manifest = await client.connect('127.0.0.1', port);
    expect(manifest.hostName, 'Sender');
    expect(manifest.items.length, 2);
    expect(manifest.totalBytes, items.fold<int>(0, (sum, i) => sum + i.size));

    await client.receive(
      ids: manifest.items.map((item) => item.id).toList(),
      downloadRoot: targetDir.path,
    );

    final (files, bytes) = await hostFinished.future.timeout(
      const Duration(seconds: 10),
    );
    expect(files, 2);
    expect(bytes, manifest.totalBytes);

    for (final item in manifest.items) {
      final receivedFile =
          File('${targetDir.path}${Platform.pathSeparator}${item.name}');
      expect(await receivedFile.exists(), isTrue, reason: item.name);
      final source = item.name == 'notes.txt' ? small : large;
      expect(
        await receivedFile.readAsBytes(),
        await source.readAsBytes(),
        reason: '${item.name} contents must match',
      );
    }
    expect(received.keys, containsAll(['notes.txt', 'clip.bin']));
  });

  test('receiver can accept a subset of the manifest', () async {
    final a = await writeRandomFile('a.txt', 4096);
    final b = await writeRandomFile('b.txt', 8192);
    final items = [
      TransferItem.fromFile(a)!..id = 'f0',
      TransferItem.fromFile(b)!..id = 'f1',
    ];

    final host = TransferHost(
      items: items,
      deviceName: 'Sender',
      instanceId: 'host2',
      events: const HostEvents(),
    );
    final port = await host.start();
    addTearDown(host.dispose);

    final client = TransferClient(
      deviceName: 'Receiver',
      instanceId: 'client2',
      events: const ClientEvents(),
    );
    addTearDown(client.dispose);

    await client.connect('127.0.0.1', port);
    await client.receive(ids: ['f1'], downloadRoot: targetDir.path);

    expect(
      await File('${targetDir.path}${Platform.pathSeparator}b.txt').exists(),
      isTrue,
    );
    expect(
      await File('${targetDir.path}${Platform.pathSeparator}a.txt').exists(),
      isFalse,
    );
  });

  test('frame reader reassembles frames split at arbitrary boundaries',
      () async {
    final frames = <Frame>[];
    final reader = FrameReader(frames.add);

    final payloads = [
      FrameCodec.json(FrameType.hello, {'name': 'tiny'}),
      FrameCodec.json(
        FrameType.session,
        {
          'files': List.generate(40, (i) => {'id': 'f$i', 'size': i * 1000}),
        },
      ),
    ];
    final all = Uint8List.fromList([for (final frame in payloads) ...frame]);

    // Feed one byte at a time: the worst case for a buffering parser.
    for (final byte in all) {
      reader.add(Uint8List.fromList([byte]));
    }

    expect(frames.length, 2);
    expect(frames.first.type, FrameType.hello);
    expect(frames.first.json()['name'], 'tiny');
    expect(
      (frames.last.json()['files'] as List<Object?>).length,
      40,
    );
  });

  test('a peer exiting mid-transfer surfaces an error, not a hang', () async {
    final file = await writeRandomFile('big.bin', 24 * 1024 * 1024);
    final errors = <String>[];
    final finished = <int>[];
    final firstProgress = Completer<void>();

    final host = TransferHost(
      items: [TransferItem.fromFile(file)!..id = 'f0'],
      deviceName: 'Sender',
      instanceId: 'host3',
      events: HostEvents(
        onError: errors.add,
        onFinished: (files, bytes, elapsed) => finished.add(bytes),
        onProgress: (item, sent) {
          if (!firstProgress.isCompleted) firstProgress.complete();
        },
      ),
    );
    final port = await host.start();
    addTearDown(host.dispose);

    final socket = await Socket.connect('127.0.0.1', port);
    final channel = FrameChannel(socket);
    channel.writer.json(FrameType.hello, {
      'v': AppConstantsForTest.version,
      'name': 'Flaky',
    });
    await channel.writer.flush();
    final session = await channel.next();
    expect(session.type, FrameType.session);
    channel.writer.json(FrameType.accept, {
      'ids': ['f0']
    });
    await channel.writer.flush();

    // Vanish while the host is still streaming, so it is writing into a socket
    // that no longer has a reader.
    await firstProgress.future.timeout(const Duration(seconds: 5));
    socket.destroy();

    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (errors.isEmpty && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    expect(
      errors,
      isNotEmpty,
      reason:
          'the host must notice the disconnect (finished=${finished.length})',
    );
  });

  test('recreates folder paths on the receiver', () async {
    final folder = Directory('${sourceDir.path}/bundle');
    await folder.create(recursive: true);
    await File('${folder.path}/a.txt').writeAsString('alpha');
    await Directory('${folder.path}/sub').create();
    await File('${folder.path}/sub/b.bin').writeAsBytes(
      Uint8List.fromList(List.generate(1000, (i) => i % 256)),
    );
    final items = [
      TransferItem.fromFile(
        File('${folder.path}/a.txt'),
        relativePath: 'bundle/a.txt',
      )!
        ..id = 'f0',
      TransferItem.fromFile(
        File('${folder.path}/sub/b.bin'),
        relativePath: 'bundle/sub/b.bin',
      )!
        ..id = 'f1',
    ];

    final host = TransferHost(
      items: items,
      deviceName: 'Sender',
      instanceId: 'host-folder',
      events: const HostEvents(),
    );
    final port = await host.start();
    addTearDown(host.dispose);

    final client = TransferClient(
      deviceName: 'Receiver',
      instanceId: 'client-folder',
      events: const ClientEvents(),
    );
    addTearDown(client.dispose);

    await client.connect('127.0.0.1', port);
    await client.receive(
      ids: ['f0', 'f1'],
      downloadRoot: targetDir.path,
    );

    final a = File('${targetDir.path}/bundle/a.txt');
    final b = File('${targetDir.path}/bundle/sub/b.bin');
    expect(await a.exists(), isTrue);
    expect(await b.exists(), isTrue);
    expect(await a.readAsString(), 'alpha');
  });

  test('serves two receivers in the same session', () async {
    final file = await writeRandomFile('group.bin', 512 * 1024 + 31);
    final items = [TransferItem.fromFile(file)!..id = 'f0'];

    final selected = Completer<void>();
    final host = TransferHost(
      items: items,
      deviceName: 'Sender',
      instanceId: 'host-group',
      events: HostEvents(
        onPeersChanged: (peers) {
          if (peers.length == 2 &&
              peers.every(
                (peer) =>
                    peer.selectedIds.contains('f0') && peer.totalBytes > 0,
              )) {
            if (!selected.isCompleted) selected.complete();
          }
        },
      ),
    );
    final port = await host.start();
    addTearDown(host.dispose);

    final dirA = await Directory.systemTemp.createTemp('free_send_grp_a');
    final dirB = await Directory.systemTemp.createTemp('free_send_grp_b');
    addTearDown(() async {
      for (final dir in [dirA, dirB]) {
        if (await dir.exists()) await dir.delete(recursive: true);
      }
    });

    final clientA = TransferClient(
      deviceName: 'Receiver A',
      instanceId: 'client-a',
      events: const ClientEvents(),
    );
    final clientB = TransferClient(
      deviceName: 'Receiver B',
      instanceId: 'client-b',
      events: const ClientEvents(),
    );
    addTearDown(clientA.dispose);
    addTearDown(clientB.dispose);

    final manifestA = await clientA.connect('127.0.0.1', port);
    final manifestB = await clientB.connect('127.0.0.1', port);
    expect(host.peerCount, 2);
    expect(
      host.peers.map((peer) => peer.name),
      containsAll(['Receiver A', 'Receiver B']),
    );

    final receiveA = clientA.receive(ids: ['f0'], downloadRoot: dirA.path);
    final receiveB = clientB.receive(ids: ['f0'], downloadRoot: dirB.path);
    await selected.future.timeout(const Duration(seconds: 5));
    expect(host.peers.length, 2);
    expect(host.peers.every((peer) => peer.totalBytes > 0), isTrue);
    await Future.wait([receiveA, receiveB]);

    for (final dir in [dirA, dirB]) {
      final received = File('${dir.path}/group.bin');
      expect(await received.exists(), isTrue);
      expect(await received.readAsBytes(), await file.readAsBytes());
    }
    expect(manifestA.items.length, 1);
    expect(manifestB.items.length, 1);
  });

  test('sender can pause and resume the live stream', () async {
    final file = await writeRandomFile('pausable.bin', 2 * 1024 * 1024 + 5);
    final items = [TransferItem.fromFile(file)!..id = 'f0'];
    final firstProgress = Completer<void>();

    final host = TransferHost(
      items: items,
      deviceName: 'Sender',
      instanceId: 'host-pause',
      events: HostEvents(
        onProgress: (item, sent) {
          if (sent >= 64 * 1024 && !firstProgress.isCompleted) {
            firstProgress.complete();
          }
        },
      ),
    );
    final port = await host.start();
    addTearDown(host.dispose);

    final client = TransferClient(
      deviceName: 'Receiver',
      instanceId: 'client-pause',
      events: const ClientEvents(),
    );
    addTearDown(client.dispose);

    final dir = await Directory.systemTemp.createTemp('free_send_pause');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    await client.connect('127.0.0.1', port);
    final receiveFuture = client.receive(
      ids: ['f0'],
      downloadRoot: dir.path,
    );
    await firstProgress.future.timeout(const Duration(seconds: 5));

    await host.pauseTransfer();
    await Future<void>.delayed(const Duration(milliseconds: 250));
    await host.resumeTransfer();

    await receiveFuture.timeout(const Duration(seconds: 15));
    final received = File('${dir.path}/pausable.bin');
    expect(await received.exists(), isTrue);
    expect(await received.readAsBytes(), await file.readAsBytes());
  });

  test('receiver can pause and resume the live stream', () async {
    final file = await writeRandomFile('receiver-pause.bin', 32 * 1024 * 1024);
    final items = [TransferItem.fromFile(file)!..id = 'f0'];
    var hostSent = 0;
    final firstProgress = Completer<void>();

    final host = TransferHost(
      items: items,
      deviceName: 'Sender',
      instanceId: 'host-receiver-pause',
      events: HostEvents(
        onProgress: (item, sent) {
          hostSent = sent;
          if (sent >= 256 * 1024 && !firstProgress.isCompleted) {
            firstProgress.complete();
          }
        },
      ),
    );
    final port = await host.start();
    addTearDown(host.dispose);

    final client = TransferClient(
      deviceName: 'Receiver',
      instanceId: 'client-receiver-pause',
      events: const ClientEvents(),
    );
    addTearDown(client.dispose);

    final dir = await Directory.systemTemp.createTemp('free_send_recv_pause');
    addTearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    await client.connect('127.0.0.1', port);
    final receiveFuture = client.receive(
      ids: ['f0'],
      downloadRoot: dir.path,
    );
    await firstProgress.future.timeout(const Duration(seconds: 10));

    await client.pause();
    expect(client.isPaused, isTrue);
    await Future<void>.delayed(const Duration(seconds: 2));
    final settled = hostSent;
    await Future<void>.delayed(const Duration(milliseconds: 800));
    expect(
      hostSent,
      closeTo(settled, 64 * 1024),
      reason: 'a paused receiver must stop draining the socket',
    );

    await client.resume();
    expect(client.isPaused, isFalse);
    await receiveFuture.timeout(const Duration(seconds: 60));

    final received = File('${dir.path}/receiver-pause.bin');
    expect(await received.exists(), isTrue);
    expect(await received.readAsBytes(), await file.readAsBytes());
  });

  test('peer progress is per receiver', () {
    const peer = PeerInfo(
      id: 'p0',
      name: 'Receiver',
      totalBytes: 200,
      transferred: 50,
      completedFiles: 1,
    );
    expect(peer.progress, 0.25);
    expect(
      peer.copyWith(status: TransferStatus.done).progress,
      1.0,
    );
  });
}

/// Mirrors the app-wide protocol constant without importing app_constants
/// through Flutter layers.
abstract final class AppConstantsForTest {
  static const version = 1;
}
