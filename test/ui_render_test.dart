import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:material_ui/material_ui.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:free_send/models/peer_info.dart';
import 'package:free_send/l10n/app_localizations.dart';
import 'package:free_send/core/transfer_flow.dart';
import 'package:free_send/services/hotspot/hotspot_service.dart';
import 'package:free_send/services/transfer/doorbell.dart';
import 'package:free_send/services/local_store.dart';
import 'package:free_send/services/pairing_code.dart';
import 'package:free_send/services/update/update_service.dart';
import 'package:free_send/state/app_state.dart';
import 'package:free_send/state/receive_controller.dart';
import 'package:free_send/models/trusted_device.dart';
import 'package:free_send/services/app_logger.dart';
import 'package:free_send/services/discovery_service.dart';
import 'package:free_send/ui/widgets/scan_radar.dart';
import 'package:free_send/state/send_controller.dart';
import 'package:free_send/state/update_controller.dart';
import 'package:free_send/theme/app_icons.dart';
import 'package:free_send/theme/app_theme.dart';
import 'package:free_send/ui/screens/settings_screen.dart';
import 'package:free_send/ui/shell.dart';
import 'package:free_send/ui/screens/logs_screen.dart';
import 'package:free_send/ui/screens/receive_screen.dart';
import 'package:free_send/ui/screens/send_screen.dart';
import 'package:free_send/ui/widgets/pairing_card.dart';
import 'package:free_send/ui/widgets/peer_list.dart';
import 'package:free_send/ui/widgets/update_sheet.dart';

/// Renders the real screens at phone size so layout overflow and missing
/// widgets fail loudly, and writes PNGs to `artifacts/` for visual review.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final captureKey = GlobalKey();
  var appState = AppState(LocalStore());

  setUpAll(() async {
    await _loadFont('Roboto', [
      'Roboto-Regular.ttf',
      'Roboto-Medium.ttf',
      'Roboto-Bold.ttf',
    ]);
    await _loadFont('MaterialIcons', ['MaterialIcons-Regular.otf']);
    // Package fonts are not part of the test bundle, so the two UIcons builds
    // the app icons use are registered by hand.
    await _loadPackageFont(
      family: 'uicons_regular_rounded',
      package: 'uicons_regular_rounded',
      asset: 'font/uicons_regular_rounded.ttf',
    );
    await _loadPackageFont(
      family: 'uicons_solid_rounded',
      package: 'uicons_solid_rounded',
      asset: 'font/uicons_solid_rounded.ttf',
    );
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({'device_name': 'Desk Mini'});
    appState = AppState(LocalStore());
    await appState.init();
  });

  Widget harness({
    required Widget home,
    SendController? sendController,
    UpdateController? updateController,
    ReceiveController? receiveController,
  }) {
    final light = AppTheme.light();
    final dark = AppTheme.dark();
    return RepaintBoundary(
      key: captureKey,
      child: MultiProvider(
        providers: [
          ChangeNotifierProvider<AppState>.value(value: appState),
          if (sendController == null)
            ChangeNotifierProvider<SendController>(
              create: (_) => SendController(appState: appState),
            )
          else
            ChangeNotifierProvider<SendController>.value(value: sendController),
          if (receiveController == null)
            ChangeNotifierProvider<ReceiveController>(
              create: (_) => ReceiveController(
                appState: appState,
                hotspotService: ManualHotspotService(),
              ),
            )
          else
            ChangeNotifierProvider<ReceiveController>.value(
              value: receiveController,
            ),
          if (updateController == null)
            ChangeNotifierProvider<UpdateController>(
              create: (_) => UpdateController(),
            )
          else
            ChangeNotifierProvider<UpdateController>.value(
              value: updateController,
            ),
        ],
        child: Consumer<AppState>(
          builder: (context, state, _) => MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: _withFont(light),
            darkTheme: _withFont(dark),
            themeMode: state.themeMode,
            locale: const Locale('en'),
            supportedLocales: const [Locale('en'), Locale('ar')],
            localizationsDelegates: [AppLocalizations.delegate],
            home: home,
          ),
        ),
      ),
    );
  }

  /// Some screens show a looping pulse, which `pumpAndSettle` can never
  /// satisfy; pump a fixed window instead.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(harness(home: const AppShell()));
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    final boundary =
        tester.renderObject<RenderRepaintBoundary>(find.byKey(captureKey));
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return;
      final file = File('artifacts/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data.buffer.asUint8List());
    });
  }

  testWidgets('every tab scrolls with its own controller', (tester) async {
    await pumpApp(tester);

    // The home tab is a two-button launcher without its own ListView; the
    // shell keeps the other tabs alive in an IndexedStack.
    final controllers = tester
        .widgetList<ListView>(find.byType(ListView, skipOffstage: false))
        .map((list) => list.controller)
        .toSet();

    expect(controllers.length, 3);
  });

  testWidgets('home renders and both flows open', (tester) async {
    await pumpApp(tester);

    expect(find.text('Send File'), findsWidgets);
    expect(find.text('Receive File'), findsWidgets);
    expect(tester.takeException(), isNull);
    await capture(tester, '01-home-light');

    await tester.tap(find.text('Send File').first);
    await tester.pumpAndSettle();
    // The send control asks how to send before anything else.
    expect(find.text('How do you want to send?'), findsOneWidget);
    await tester.tap(find.text('Share to nearby'));
    await tester.pumpAndSettle();
    expect(find.text('How do you want to send?'), findsNothing);
    expect(find.byType(SendScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture(tester, '02-send-empty');

    await tester.tap(find.byIcon(AppIcons.back));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Receive File').first);
    await settle(tester);
    expect(find.text('Waiting for a device'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture(tester, '03-receive-scan');

    await tester.tap(find.byIcon(AppIcons.back));
    await tester.pumpAndSettle();

    // Settings and History copy is owned by other work in progress; this test
    // covers the send and receive entry points only.
    expect(tester.takeException(), isNull);
  });

  testWidgets('dark mode renders home and receive', (tester) async {
    await appState.setThemeMode(ThemeMode.dark);
    await pumpApp(tester);
    expect(find.text('Send File'), findsWidgets);
    expect(tester.takeException(), isNull);
    await capture(tester, '11-home-dark');

    await tester.tap(find.text('Receive File').first);
    await settle(tester);
    expect(find.text('Waiting for a device'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture(tester, '12-receive-dark');
  });

  testWidgets('pairing card renders a code and its instructions',
      (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    const code = PairingCode(
      ssid: 'FreeSend-Desk-Mini',
      password: 'hq7KmV2rTn9X',
      host: '192.168.43.1',
      port: 47811,
      senderName: 'Desk Mini',
      senderPlatform: 'Linux',
    );
    await tester.pumpWidget(
      harness(
        home: Scaffold(
          appBar: AppBar(title: const Text('Send')),
          body: SingleChildScrollView(
            padding: kPagePadding,
            child: PairingCard(code: code, onCopy: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('Scan to pair'), findsOneWidget);
    expect(find.text('Copy code'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture(tester, '09-pairing-card');
  });

  testWidgets('a live session hunts for a receiver', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    // This machine has no Wi-Fi adapter, so host over the current network the
    // way the Windows and macOS builds do.
    final controller = SendController(
      appState: appState,
      hotspotService: ManualHotspotService(),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      harness(home: const AppShell(), sendController: controller),
    );
    await tester.pumpAndSettle();

    final dir = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('freesend_test'),
    ))!;
    final file = File('${dir.path}/notes.txt')
      ..writeAsStringSync('hunting render test');
    addTearDown(() => dir.delete(recursive: true));
    controller.addFiles([file]);

    await tester.tap(find.text('Send File').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Share to nearby'));
    await tester.pumpAndSettle();
    // The radar only exists once the session is really up: a real listener and
    // seeker socket.
    await tester.runAsync(controller.startSession);
    await settle(tester);

    expect(find.text('Looking for a device to receive these'), findsOneWidget);
    expect(find.byType(ScanRadar), findsOneWidget);
    expect(
      find.text(
        'Nobody is ready yet - on the other device, open FreeSend and tap '
        'Receive.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await capture(tester, '10-send-hunting');

    // A receiver opens its screen, answers the sender's signal, and appears.
    final candidate = SeekCandidate(
      instanceId: 'receiver-1',
      deviceName: 'Pixel 8',
      platform: 'Android',
      ip: InternetAddress.loopbackIPv4.address,
      consentPort: 1,
      lastSeen: DateTime.now(),
    );
    controller.candidates = [candidate];
    await settle(tester);
    expect(find.text('Pixel 8'), findsOneWidget);
    await capture(tester, '12-send-candidate');

    // Asking a dead doorbell ends in an unreachable state, not a hang. The
    // knock uses a real socket, so its completion needs a real-async window.
    await tester.tap(find.text('Pixel 8'));
    await tester.pump();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 600)),
    );
    await settle(tester);
    expect(controller.stateOf(candidate), AuthState.offline);
    expect(tester.takeException(), isNull);

    await appState.setThemeMode(ThemeMode.dark);
    await settle(tester);
    expect(find.byType(ScanRadar), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture(tester, '13-send-hunting-dark');
    await appState.setThemeMode(ThemeMode.light);
    await settle(tester);

    await tester.runAsync(() async {
      await controller.cancelSession();
      controller.clearFiles();
    });
    await settle(tester);
  });

  testWidgets('the send control offers entries and group mode asks in bulk',
      (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final controller = SendController(
      appState: appState,
      hotspotService: ManualHotspotService(),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      harness(home: const AppShell(), sendController: controller),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Send File').first);
    await tester.pumpAndSettle();
    expect(find.text('How do you want to send?'), findsOneWidget);
    // A desktop never offers the camera entry.
    expect(find.text('Share to nearby'), findsOneWidget);
    expect(find.text('Send to a group'), findsOneWidget);
    expect(find.text('Scan a QR code'), findsNothing);

    await tester.tap(find.text('Send to a group'));
    await tester.pumpAndSettle();
    expect(controller.mode, SendMode.group);

    final dir = (await tester.runAsync(
      () => Directory.systemTemp.createTemp('freesend_group'),
    ))!;
    final file = File('${dir.path}/notes.txt')..writeAsStringSync('group');
    addTearDown(() => dir.delete(recursive: true));
    controller.addFiles([file]);
    await tester.runAsync(controller.startSession);
    await settle(tester);

    final first = SeekCandidate(
      instanceId: 'r1',
      deviceName: 'Pixel 8',
      platform: 'Android',
      ip: InternetAddress.loopbackIPv4.address,
      consentPort: 1,
      lastSeen: DateTime.now(),
    );
    final second = SeekCandidate(
      instanceId: 'r2',
      deviceName: 'Desk Mini',
      platform: 'Linux',
      ip: InternetAddress.loopbackIPv4.address,
      consentPort: 1,
      lastSeen: DateTime.now(),
    );
    controller.candidates = [first, second];
    await settle(tester);

    expect(find.text('Choose who receives these'), findsOneWidget);
    await tester.tap(find.text('Pixel 8'));
    await settle(tester);
    expect(controller.selected, {first.id});
    expect(find.text('Ask 1 device'), findsOneWidget);
    expect(find.text('Select a device'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the receive screen waits and asks before accepting',
      (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final controller = ReceiveController(
      appState: appState,
      hotspotService: ManualHotspotService(),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      harness(home: const ReceiveScreen(), receiveController: controller),
    );
    await settle(tester);

    expect(find.text('Waiting for a device'), findsOneWidget);
    // On a desktop the phone hosts, so this device waits to be joined first.
    expect(find.text("Connect to the phone's hotspot"), findsOneWidget);
    expect(controller.doorbellPort, isNotNull);
    expect(controller.presence, ReceiverPresence.joinPrompt);
    expect(tester.takeException(), isNull);
    await capture(tester, '18-receive-waiting');

    await tester.runAsync(() async {
      await KnockClient.send(
        host: InternetAddress.loopbackIPv4.address,
        port: controller.doorbellPort!,
        senderInstanceId: 'sender-test',
        senderName: 'Desk Mini',
        platform: 'Linux',
        fileCount: 12,
        totalBytes: 640 * 1024 * 1024,
        fileServerHost: InternetAddress.loopbackIPv4.address,
        fileServerPort: 47811,
        timeout: const Duration(seconds: 5),
      );
    });
    await settle(tester);
    expect(find.text('Accept files from Desk Mini?'), findsOneWidget);
    expect(find.text('Decline'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Decline'));
    await settle(tester);
    expect(find.text('Accept files from Desk Mini?'), findsNothing);
    expect(controller.activeKnock, isNull);

    // The desktop escape hatch shows an address code for the phone.
    await tester.tap(find.text('Unable to connect? Use local Wi-Fi network'));
    await tester.pump();
    // Resolving the local address is real I/O.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 400)),
    );
    await settle(tester);
    expect(controller.showLocalWifiQr, isTrue);
    expect(controller.localWifiQrPayload, isNotNull);
    expect(find.byType(QrImageView), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture(tester, '19-receive-local-wifi');

    // A device pinned by an earlier encrypted session is not asked again.
    await tester.runAsync(() => appState.store.trustDevice(TrustedDevice(
      instanceId: 'sender-test',
      name: 'Desk Mini',
      publicKey: 'pin-key',
      fingerprint: 'pin-fingerprint',
      addedAt: DateTime.now(),
    )));
    await tester.runAsync(() => KnockClient.send(
      host: InternetAddress.loopbackIPv4.address,
      port: controller.doorbellPort!,
      senderInstanceId: 'sender-test',
      senderName: 'Desk Mini',
      platform: 'Linux',
      fileCount: 12,
      totalBytes: 1024,
      fileServerHost: InternetAddress.loopbackIPv4.address,
      fileServerPort: 47811,
      timeout: const Duration(seconds: 5),
    ));
    await settle(tester);
    expect(find.text('Accept files from Desk Mini?'), findsNothing);
    expect(controller.activeKnock, isNull);
  });

  testWidgets('the logs screen shows entries and can copy them', (
    tester,
  ) async {
    // Start from an empty buffer: earlier tests fill it, and a ListView only
    // builds what is on screen.
    await AppLog.clear();
    AppLog.info('test', 'a line from the test');
    AppLog.warn('test', 'a warning from the test');
    await tester.pumpWidget(
      harness(home: const LogsScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Logs'), findsOneWidget);
    expect(find.textContaining('a line from the test'), findsOneWidget);
    expect(find.textContaining('a warning from the test'), findsOneWidget);

    // Filtering narrows to warnings only.
    await tester.tap(find.text('warn'));
    await tester.pumpAndSettle();
    expect(find.textContaining('a line from the test'), findsNothing);
    expect(find.textContaining('a warning from the test'), findsOneWidget);

    await tester.tap(find.text('all'));
    await tester.pumpAndSettle();
    expect(find.byIcon(AppIcons.copy), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture(tester, '20-logs');
    await AppLog.clear();
  });

  testWidgets('narrow screens do not overflow', (tester) async {
    tester.view.physicalSize = const Size(960, 1600);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(harness(home: const AppShell()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await capture(tester, '07-home-narrow');

    final receiveCard = find.text('Receive File').first;
    await tester.ensureVisible(receiveCard);
    await tester.pumpAndSettle();
    await tester.tap(receiveCard);
    await settle(tester);
    expect(tester.takeException(), isNull);
    await capture(tester, '08-receive-narrow');
  });

  // The phone-size tests above never exercise the two-column home layout,
  // where a stretch Row inside a ListView gets unbounded height and crashes.
  testWidgets('wide screens lay out the two-column home', (tester) async {
    tester.view.physicalSize = const Size(2560, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(harness(home: const AppShell()));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Send File'), findsOneWidget);
    expect(find.text('Receive File'), findsOneWidget);
    await capture(tester, '14-home-wide');
  });

  testWidgets('peer list shows independent receiver progress', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: EdgeInsets.all(AppSpacing.lg),
            child: PeerList(
              peers: [
                PeerInfo(
                  id: 'p1',
                  name: 'Pixel',
                  selectedIds: ['f0'],
                  totalBytes: 200,
                  transferred: 100,
                  completedFiles: 1,
                ),
                PeerInfo(
                  id: 'p2',
                  name: 'Desktop',
                  selectedIds: ['f0'],
                  totalBytes: 200,
                  transferred: 20,
                  completedFiles: 0,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.text('Receivers'), findsOneWidget);
    expect(find.text('Pixel'), findsOneWidget);
    expect(find.text('Desktop'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('10%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('settings shows the updates section', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Updates'), findsOneWidget);
    expect(find.text('Check automatically'), findsOneWidget);
    expect(find.text('Check for updates'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture(tester, '17-settings-updates');

    // The toggle persists through the app state. It sits below the fold, so
    // scroll it into view before tapping.
    final toggle = find.descendant(
      of: find.ancestor(
        of: find.text('Check automatically'),
        matching: find.byType(Row),
      ),
      matching: find.byType(Switch),
    );
    expect(tester.widget<Switch>(toggle).value, isFalse);
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(tester.widget<Switch>(toggle).value, isTrue);
    expect(appState.autoUpdate, isTrue);
    expect(
      tester
          .element(find.byType(SettingsScreen))
          .read<UpdateController>()
          .autoCheck,
      isTrue,
    );
  });

  testWidgets('settings can turn on minimize to tray on close', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('System tray'), findsOneWidget);
    final toggle = find.descendant(
      of: find.ancestor(
        of: find.text('Minimize to tray on close'),
        matching: find.byType(Row),
      ),
      matching: find.byType(Switch),
    );
    expect(tester.widget<Switch>(toggle).value, isFalse);
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(appState.minimizeToTray, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the update sheet shows notes and downloads', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    final updates = UpdateController(
      // Seeded so the test never touches PackageInfo, whose platform channel
      // cannot resolve inside a widget test.
      initialVersion: '1.0.0',
      service: UpdateService(
        client: MockClient((request) async {
          if (request.url.path.endsWith('/releases')) {
            return http.Response(
                jsonEncode([
                  {
                    'tag_name': 'v9.9.9',
                    'description': 'Faster handshakes and a new icon.',
                    'assets': {
                      'links': [
                        {
                          'name': 'FreeSend for Linux',
                          'direct_asset_url':
                              'https://gitlab.com/a/freesend.AppImage',
                        },
                      ],
                    },
                  },
                ]),
                200);
          }
          return http.Response('apk-bytes', 200);
        }),
      ),
    );
    addTearDown(updates.dispose);

    await tester.pumpWidget(
      harness(home: const AppShell(), updateController: updates),
    );
    await tester.pumpAndSettle();

    // Real file I/O and sockets cannot complete inside the fake-async zone a
    // widget test runs in, so the network-bound steps go through runAsync.
    await tester.runAsync(() => updates.checkManually());
    await tester.pumpAndSettle();
    expect(updates.phase, UpdatePhase.available);

    // showModalBottomSheet's future completes on dismissal, so it is not
    // awaited here.
    unawaited(UpdateSheet.show(tester.element(find.byType(AppShell))));
    await tester.pumpAndSettle();

    expect(find.text('FreeSend 9.9.9 is available'), findsOneWidget);
    expect(find.text('Faster handshakes and a new icon.'), findsOneWidget);
    expect(find.text('Download update'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await capture(tester, '15-update-sheet');

    await tester.tap(find.text('Download update'));
    await tester.runAsync(() => updates.download());
    await tester.pumpAndSettle();

    expect(updates.phase, UpdatePhase.readyToInstall);
    expect(updates.downloadedFile, isNotNull);
    // Reading the file back is real I/O, so it goes through runAsync too.
    final downloaded = await tester.runAsync(
      () => updates.downloadedFile!.readAsString(),
    );
    expect(downloaded, 'apk-bytes');
    await capture(tester, '16-update-ready');
  });
}

ThemeData _withFont(ThemeData base) => base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: 'Roboto'),
      primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'Roboto'),
    );

Future<void> _loadPackageFont({
  required String family,
  required String package,
  required String asset,
}) async {
  // flutter_test cannot resolve package URIs, so the package root comes from
  // the project's own package config.
  final config = File('.dart_tool/package_config.json');
  if (!config.existsSync()) return;
  final decoded =
      jsonDecode(await config.readAsString()) as Map<String, Object?>;
  final packages =
      (decoded['packages'] as List<Object?>).cast<Map<String, Object?>>();
  final match = packages.where((entry) => entry['name'] == package);
  if (match.isEmpty) return;
  final root = config.uri.resolve(match.first['rootUri']! as String);
  final rootPath = root.toFilePath().replaceAll(RegExp(r'/+$'), '');
  final file = File('$rootPath/$asset');
  if (!await file.exists()) return;
  final bytes = await file.readAsBytes();
  final loader = FontLoader(family)
    ..addFont(Future.value(ByteData.sublistView(bytes)));
  await loader.load();
}

Future<void> _loadFont(String family, List<String> files) async {
  final home = Platform.environment['HOME'];
  if (home == null) return;
  final dir = Directory(
    '$home/tools/flutter/bin/cache/artifacts/material_fonts',
  );
  if (!await dir.exists()) return;
  final loader = FontLoader(family);
  var loaded = false;
  for (final name in files) {
    final file = File('${dir.path}/$name');
    if (!await file.exists()) continue;
    final bytes = await file.readAsBytes();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
    loaded = true;
  }
  if (loaded) await loader.load();
}
