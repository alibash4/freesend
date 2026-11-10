import 'package:flutter/material.dart';

import 'package:free_send/app.dart';
import 'package:free_send/services/local_store.dart';
import 'package:free_send/state/app_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appState = AppState(LocalStore());
  await appState.init();
  runApp(FreeSendApp(appState: appState));
}
