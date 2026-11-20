import 'dart:ui' show Size;

import 'package:window_manager/window_manager.dart';

import 'package:free_send/core/platform_env.dart';

/// Desktop window geometry.
///
/// Opens at 900x625 every launch, centered. The floor is phone-sized so the
/// narrow layout (bottom nav, stacked panels) can be previewed on desktop.
abstract final class WindowSetup {
  static const size = Size(900, 625);
  static const minSize = Size(360, 600);

  static Future<void> apply() async {
    if (!PlatformEnv.isDesktop) return;
    try {
      await windowManager.ensureInitialized();
      await windowManager.setTitle('FreeSend');
      await windowManager.setMinimumSize(minSize);
      await windowManager.setSize(size);
      await windowManager.center();
    } on Object {
      // A missing window manager (tests, some Linux hosts) must not stop start.
    }
  }

  /// Restores the saved window instead of forcing the launch size.
  static Future<void> restore() async {
    if (!PlatformEnv.isDesktop) return;
    try {
      await windowManager.ensureInitialized();
      await windowManager.setMinimumSize(minSize);
      await windowManager.show();
      await windowManager.focus();
    } on Object {
      // Same as [apply]: never fatal.
    }
  }
}