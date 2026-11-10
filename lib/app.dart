import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:free_send/state/app_state.dart';
import 'package:free_send/state/receive_controller.dart';
import 'package:free_send/state/send_controller.dart';
import 'package:free_send/theme/app_theme.dart';
import 'package:free_send/ui/shell.dart';

class FreeSendApp extends StatelessWidget {
  const FreeSendApp({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AppState>.value(value: appState),
        ChangeNotifierProvider<SendController>(
          create: (_) => SendController(appState: appState),
        ),
        ChangeNotifierProvider<ReceiveController>(
          create: (_) => ReceiveController(appState: appState),
        ),
      ],
      child: Consumer<AppState>(
        builder: (context, state, _) {
          return MaterialApp(
            title: 'Free Send',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: state.themeMode,
            home: const AppShell(),
          );
        },
      ),
    );
  }
}
