import 'dart:async';

/// Full-screen overlays the app shell can swap in. The receive/send screens
/// are overlays on top of the tab pages rather than routes.
enum AppOverlay { send, receive }

/// Broadcasts one-shot navigation requests from services (for example the
/// Android notification's "open" tap) to the shell, which owns the overlay
/// index. A request made before the shell subscribes is held as pending so a
/// cold start through the notification still lands on the right screen.
class AppNavigation {
  AppNavigation();

  final _requests = StreamController<AppOverlay>.broadcast();
  AppOverlay? _pending;

  Stream<AppOverlay> get requests => _requests.stream;

  void request(AppOverlay overlay) {
    if (_requests.hasListener) {
      _requests.add(overlay);
    } else {
      _pending = overlay;
    }
  }

  /// Returns and clears an overlay requested before anyone listened.
  AppOverlay? takePending() {
    final pending = _pending;
    _pending = null;
    return pending;
  }

  void dispose() {
    unawaited(_requests.close());
  }
}

/// App-wide instance; the shell subscribes, services publish.
final appNavigation = AppNavigation();
