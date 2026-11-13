import 'dart:async';
import 'dart:io';

import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'package:free_send/core/platform_env.dart';
import 'package:free_send/state/app_state.dart';

/// Owns the native system-tray icon on desktop builds.
///
/// The menu itself is drawn by the OS: Windows and macOS pop it up from the
/// tray, while the Linux AppIndicator host shows it on right click. Opening the
/// app restores the window, and closing the window only hides it when the
/// matching setting is on.
class TrayController with TrayListener, WindowListener {
  TrayController(this._appState);

  final AppState _appState;

  bool _initialized = false;
  bool _quitting = false;

  static const _tooltip = 'FreeSend';

  Future<void> init() async {
    if (_initialized || !PlatformEnv.supportsTray) return;

    try {
      await windowManager.ensureInitialized();
      windowManager.addListener(this);
      trayManager.addListener(this);

      await trayManager.setIcon(_iconAsset);
      if (Platform.isWindows) {
        // tray_manager has no Linux tooltip implementation.
        await trayManager.setToolTip(_tooltip);
      }
      await _setMenu();

      // Only intercept close once the icon exists: a hidden window with no
      // tray icon would be impossible to get back.
      await windowManager.setPreventClose(true);
      _initialized = true;
    } on Object {
      // A missing tray host (or a GNOME without the AppIndicator extension)
      // must not stop the window from opening.
      windowManager.removeListener(this);
      trayManager.removeListener(this);
    }
  }

  String get _iconAsset {
    if (Platform.isWindows) return 'assets/tray/app_icon.ico';
    // Full-bleed at a generous size: the tray host scales it to its own
    // height, so padding would only shrink the mark.
    return 'assets/tray/app_icon_256.png';
  }

  Future<void> _setMenu() async {
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(
            key: 'open',
            label: 'Open FreeSend',
            onClick: (_) => unawaited(showWindow()),
          ),
          MenuItem.separator(),
          MenuItem(
            key: 'quit',
            label: 'Quit FreeSend',
            onClick: (_) => unawaited(quit()),
          ),
        ],
      ),
    );
  }

  /// Restores the window after it was hidden to the tray.
  Future<void> showWindow() async {
    if (!_initialized) return;
    await windowManager.show();
    await windowManager.focus();
  }

  /// Removes the tray icon and closes the app for good.
  Future<void> quit() async {
    if (_quitting) return;
    _quitting = true;
    if (!Platform.isLinux) {
      await trayManager.destroy();
    }
    await windowManager.setPreventClose(false);
    await windowManager.destroy();
  }

  @override
  void onTrayIconMouseDown() {
    unawaited(showWindow());
  }

  @override
  void onTrayIconRightMouseDown() {
    // The Linux AppIndicator host shows the menu itself; asking for a popup
    // there would throw because the plugin does not implement it.
    if (Platform.isWindows) {
      unawaited(trayManager.popUpContextMenu());
    }
  }

  @override
  void onWindowClose() {
    if (_appState.minimizeToTray && !_quitting) {
      unawaited(windowManager.hide());
      return;
    }
    if (!_quitting) {
      _quitting = true;
      unawaited(windowManager.destroy());
    }
  }
}