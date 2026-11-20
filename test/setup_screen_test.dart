import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:free_send/l10n/app_localizations.dart';
import 'package:free_send/services/permissions/transfer_setup.dart';
import 'package:free_send/theme/app_theme.dart';
import 'package:free_send/ui/screens/setup_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final captureKey = GlobalKey();

  const steps = [
    SetupStep(index: 1, kind: SetupKind.nearby, granted: false),
    SetupStep(index: 2, kind: SetupKind.wifi, granted: false),
    SetupStep(index: 3, kind: SetupKind.vpn, granted: false, mustGrant: false),
  ];

  setUpAll(() async {
    await _loadFont('Roboto', [
      'Roboto-Regular.ttf',
      'Roboto-Medium.ttf',
      'Roboto-Bold.ttf',
    ]);
    await _loadFont('MaterialIcons', ['MaterialIcons-Regular.otf']);
    // Icon fonts ship as plain project assets, so they are registered by
    // hand for the test bundle.
    await _loadAssetFont(
        'uicons-regular-rounded', 'assets/fonts/uicons-rr.ttf');
    await _loadAssetFont('uicons-solid-rounded', 'assets/fonts/uicons-sr.ttf');
    await _loadAssetFont('uicons-brands', 'assets/fonts/uicons-brands.ttf');
  });

  setUp(() {
    TransferSetup.debugLoad = () async => steps;
  });

  tearDown(() {
    TransferSetup.debugLoad = null;
  });

  Future<void> pump(WidgetTester tester, String title,
      {bool dark = false}) async {
    tester.view.physicalSize = const Size(390, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final base = dark ? AppTheme.dark() : AppTheme.light();
    await tester.pumpWidget(
      MaterialApp(
        theme: _withFont(base),
        localizationsDelegates: [AppLocalizations.delegate],
        supportedLocales: const [Locale('en')],
        home: RepaintBoundary(
          key: captureKey,
          child: SetupScreen(title: title),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The PNG has to be taken inside `runAsync`: outside it the image
  /// conversion never completes and the test hangs until it times out.
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

  testWidgets('every check shows its status', (tester) async {
    await pump(tester, 'Before you receive');

    expect(find.text('Before you receive'), findsOneWidget);
    expect(find.text('Nearby devices'), findsOneWidget);
    expect(find.text('Wi-Fi is on'), findsOneWidget);
    expect(find.text('VPN is off'), findsOneWidget);

    // Every unmet row carries its own inline action: permission rows ask
    // the system (Allow), status rows jump to settings. Nothing is locked.
    expect(find.text('Done'), findsNothing);
    expect(find.text('Optional'), findsOneWidget);
    expect(find.text('Allow'), findsOneWidget);
    expect(find.text('Settings'), findsNWidgets(2));

    await capture(tester, '18-setup-receive');
  });

  testWidgets('the send title is the only copy that changes', (tester) async {
    await pump(tester, 'Before you send', dark: true);
    expect(find.text('Before you send'), findsOneWidget);
    expect(find.text('Before you receive'), findsNothing);
    expect(find.text('Allow'), findsOneWidget);
    expect(find.text('Settings'), findsNWidgets(2));

    await capture(tester, '19-setup-send-dark');
  });

  test('optional checks do not block, required ones do', () async {
    TransferSetup.debugLoad = () async => const [
          SetupStep(index: 1, kind: SetupKind.nearby, granted: true),
          SetupStep(index: 2, kind: SetupKind.wifi, granted: true),
          SetupStep(
            index: 3,
            kind: SetupKind.vpn,
            granted: false,
            mustGrant: false,
          ),
        ];
    expect(await TransferSetup.isReady, isTrue);

    TransferSetup.debugLoad = () async => const [
          SetupStep(index: 1, kind: SetupKind.nearby, granted: false),
          SetupStep(index: 2, kind: SetupKind.wifi, granted: true),
          SetupStep(index: 3, kind: SetupKind.vpn, granted: true),
        ];
    expect(await TransferSetup.isReady, isFalse);
  });
}

ThemeData _withFont(ThemeData base) => base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: 'Roboto'),
      primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'Roboto'),
    );

Future<void> _loadAssetFont(String family, String path) async {
  final file = File(path);
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
