import 'dart:io';

import 'package:flutter/widgets.dart';

import 'package:free_send/app.dart';
import 'package:free_send/core/app_constants.dart';
import 'package:free_send/services/app_logger.dart';
import 'package:free_send/services/local_store.dart';
import 'package:free_send/services/tray_controller.dart';
import 'package:free_send/services/window_setup.dart';
import 'package:free_send/state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appState = AppState(LocalStore());
  await appState.init();
  final tray = TrayController(appState);
  await tray.init();
  await WindowSetup.apply();
  await AppLog.init();
  AppLog.info('app', 'FreeSend ${AppConstants.appVersion} starting '
      'on ${Platform.operatingSystem}');
  runApp(FreeSendApp(appState: appState, tray: tray));
}
