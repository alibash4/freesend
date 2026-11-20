import 'dart:async';

import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalCupertinoLocalizations, GlobalWidgetsLocalizations;
import 'package:material_ui/material_ui.dart';
import 'package:provider/provider.dart';

import 'package:free_send/l10n/app_localizations.dart';
import 'package:free_send/services/tray_controller.dart';
import 'package:free_send/state/app_state.dart';
import 'package:free_send/state/receive_controller.dart';
import 'package:free_send/state/send_controller.dart';
import 'package:free_send/state/update_controller.dart';
import 'package:free_send/theme/app_theme.dart';
import 'package:free_send/ui/shell.dart';
import 'package:free_send/ui/widgets/knock_gate.dart';
import 'package:free_send/ui/widgets/update_sheet.dart';

/// Picks the concrete [ThemeData] for the current choice. MaterialApp only
/// understands light/dark/system, so the black variant is resolved here and
/// the app is pinned to [ThemeMode.light] to keep it stable.
ThemeData _resolveTheme(AppState state) {
  if (!state.effectiveDark) return AppTheme.light();
  return state.blackTheme ? AppTheme.black() : AppTheme.dark();
}

class FreeSendApp extends StatelessWidget {
  const FreeSendApp({super.key, required this.appState, required this.tray});

  final AppState appState;

  /// Kept alive with the widget tree; it owns the native tray listeners.
  final TrayController tray;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: appState),
        ChangeNotifierProvider<SendController>(
          create: (_) => SendController(appState: appState),
        ),
        ChangeNotifierProvider<ReceiveController>(
          // Eager: it owns the foreground-service event stream, which must be
          // listening before the OS delivers a notification action.
          lazy: false,
          create: (_) => ReceiveController(appState: appState),
        ),
        ChangeNotifierProvider<UpdateController>(
          create: (_) => UpdateController(),
        ),
      ],
      child: _UpdateBootstrap(appState: appState),
    );
  }
}

/// Runs the startup update check.
///
/// It has to sit below the providers to read [UpdateController], and above
/// [MaterialApp] so it can reach the navigator when a release is found.
class _UpdateBootstrap extends StatefulWidget {
  const _UpdateBootstrap({required this.appState});

  final AppState appState;

  @override
  State<_UpdateBootstrap> createState() => _UpdateBootstrapState();
}

class _UpdateBootstrapState extends State<_UpdateBootstrap> {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  Future<void> _bootstrap() async {
    if (!mounted) return;
    final updates = context.read<UpdateController>();
    updates.setAutoCheck(widget.appState.autoUpdate);
    final found = await updates.checkSilently();
    if (found) _showUpdates();
  }

  /// Resolves the navigator context itself, so the async check above never
  /// touches a context after an await.
  void _showUpdates() {
    final navigatorContext = _navigatorKey.currentContext;
    if (navigatorContext == null) return;
    unawaited(UpdateSheet.show(navigatorContext));
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) => MaterialApp(
        title: 'FreeSend',
        debugShowCheckedModeBanner: false,
        navigatorKey: _navigatorKey,
        theme: _resolveTheme(state),
        themeMode: ThemeMode.light,
        locale: state.locale,
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('ar'), Locale('en')],
        home: const KnockGate(child: AppShell()),
      ),
    );
  }
}
