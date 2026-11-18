import 'dart:convert';
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
    SetupStep(index: 1, granted: false),
    SetupStep(index: 2, granted: false),
    SetupStep(index: 3, granted: false, mustGrant: false),
  ];

  setUpAll(() async {
    await _loadFont('Roboto', [
      'Roboto-Regular.ttf',
      'Roboto-Medium.ttf',
      'Roboto-Bold.ttf',
    ]);
    await _loadFont('MaterialIcons', ['MaterialIcons-Regular.otf']);
    // Package fonts are not part of the test bundle, so the two icon fonts
    // the app uses are registered by hand.
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
    expect(find.text('Wi-Fi is on'), findsOneWidget);
    expect(find.text('VPN is off'), findsOneWidget);
    expect(find.text('Location is on'), findsOneWidget);

    // Nothing here can be toggled in-app: each unmet check says so, the
    // optional one keeps its tag, and the only action is re-checking.
    expect(find.text('Action needed'), findsNWidgets(3));
    expect(find.text('Done'), findsNothing);
    expect(find.text('Optional'), findsOneWidget);
    expect(find.text('Check again', skipOffstage: false), findsOneWidget);

    await capture(tester, '18-setup-receive');
  });

  testWidgets('the send title is the only copy that changes', (tester) async {
    await pump(tester, 'Before you send', dark: true);
    expect(find.text('Before you send'), findsOneWidget);
    expect(find.text('Before you receive'), findsNothing);
    expect(find.text('Action needed'), findsNWidgets(3));

    await capture(tester, '19-setup-send-dark');
  });

  test('optional checks do not block, required ones do', () async {
    TransferSetup.debugLoad = () async => const [
          SetupStep(index: 1, granted: true),
          SetupStep(index: 2, granted: true),
          SetupStep(index: 3, granted: false, mustGrant: false),
        ];
    expect(await TransferSetup.isReady, isTrue);

    TransferSetup.debugLoad = () async => const [
          SetupStep(index: 1, granted: false),
          SetupStep(index: 2, granted: true),
          SetupStep(index: 3, granted: true),
        ];
    expect(await TransferSetup.isReady, isFalse);
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
