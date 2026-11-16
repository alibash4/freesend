import 'package:flutter/widgets.dart';

/// Exposes the content-area navigator so pages pushed from inside the shell
/// keep the sidebar visible on desktop.
class ContentNavigatorScope extends InheritedWidget {
  const ContentNavigatorScope({
    super.key,
    required this.navigatorKey,
    required super.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;

  static GlobalKey<NavigatorState>? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<ContentNavigatorScope>()
        ?.navigatorKey;
  }

  @override
  bool updateShouldNotify(ContentNavigatorScope oldWidget) => false;
}