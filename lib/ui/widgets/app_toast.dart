import 'dart:async';

import 'package:material_ui/material_ui.dart';

import 'package:free_send/theme/app_theme.dart';

/// A lightweight animated toast that floats above the content and
/// dismisses itself. Use [AppToast.show] instead of [ScaffoldMessenger]
/// when the app's signature enter/exit motion is wanted.
class AppToast extends StatefulWidget {
  const AppToast({
    super.key,
    required this.message,
    required this.onDismiss,
  });

  final String message;
  final VoidCallback onDismiss;

  /// Shows [message] near the bottom of the screen for ~2.5 seconds.
  static void show(BuildContext context, String message) {
    final overlay = Overlay.of(context, rootOverlay: true);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => AppToast(
        message: message,
        onDismiss: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }

  @override
  State<AppToast> createState() => _AppToastState();
}

class _AppToastState extends State<AppToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.base,
    reverseDuration: const Duration(milliseconds: 200),
  );
  late final Animation<double> _opacity = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );
  Timer? _dismissTimer;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    _dismissTimer = Timer(const Duration(milliseconds: 2500), _dismiss);
  }

  void _dismiss() {
    _dismissTimer?.cancel();
    _controller.reverse().then((_) => widget.onDismiss());
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Positioned(
      left: AppSpacing.lg,
      right: AppSpacing.lg,
      bottom: bottomInset + 72,
      child: Center(
        child: FadeTransition(
          opacity: _opacity,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.15),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: _controller,
              curve: Curves.easeOutCubic,
            )),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1).animate(
                CurvedAnimation(
                  parent: _controller,
                  curve: Curves.easeOutBack,
                ),
              ),
              child: Material(
                color: dark ? AppColors.successWashDark : AppColors.successWash,
                borderRadius: BorderRadius.circular(AppRadii.field),
                elevation: 6,
                shadowColor: scheme.shadow.withValues(alpha: 0.25),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm + 2,
                  ),
                  child: Text(
                    widget.message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: dark
                              ? AppColors.successInkDark
                              : AppColors.successInk,
                        ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
