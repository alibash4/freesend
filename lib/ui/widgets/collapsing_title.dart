import 'dart:ui' show lerpDouble;

import 'package:material_ui/material_ui.dart';

import 'package:free_send/theme/app_theme.dart';
import 'package:free_send/ui/kit/tokens.dart';

/// An always-visible page header that morphs with scroll. Expanded it shows
/// [leading] at the top-left with a large left-aligned [title] beneath it;
/// as the content scrolls the header shrinks and the title glides up beside
/// the leading control at a smaller size - the iOS large-title / Material
/// flexible app bar pattern, without any title or back affordance inside
/// the scrolling body.
///
/// The child must use [controller] as its scroll controller and pad its top
/// by at least [expandedHeight] so the first content sits below the header.
class CollapsingHeader extends StatefulWidget {
  const CollapsingHeader({
    super.key,
    required this.controller,
    required this.title,
    required this.child,
    this.leading,
  });

  /// Header height fully expanded and fully collapsed.
  static const double expandedHeight = 104;
  static const double collapsedHeight = 56;

  /// Scroll distance over which the morph happens.
  static const double collapseDistance = 56;

  /// The scroll controller driving both the child and the morph.
  final ScrollController controller;

  /// The page title, shown large at rest and small beside [leading] on scroll.
  final String title;

  /// Optional control pinned at the top-left in both states (e.g. a back
  /// button on pushed routes). Expected to be ~40px wide.
  final Widget? leading;

  /// The scrollable content, typically a [ListView] using [controller].
  final Widget child;

  @override
  State<CollapsingHeader> createState() => _CollapsingHeaderState();
}

class _CollapsingHeaderState extends State<CollapsingHeader> {
  double _t = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_update);
  }

  @override
  void didUpdateWidget(CollapsingHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_update);
      widget.controller.addListener(_update);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_update);
    super.dispose();
  }

  void _update() {
    final t = (widget.controller.offset / CollapsingHeader.collapseDistance)
        .clamp(0.0, 1.0);
    if (t != _t) setState(() => _t = t);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = _t;
    final height = lerpDouble(
      CollapsingHeader.expandedHeight,
      CollapsingHeader.collapsedHeight,
      t,
    )!;
    final dark = theme.brightness == Brightness.dark;
    // Expanded: title sits under the leading control, left-aligned. Collapsed:
    // it glides up beside the control (or stays left when there is none).
    final titleLeft = lerpDouble(
      AppSpacing.md,
      widget.leading == null ? AppSpacing.md : AppSpacing.md + 52,
      t,
    )!;
    final titleTop = lerpDouble(72, 22, t)!;
    const leadingTop = 12.0;
    final titleStyle = AppTypography.pageTitle.copyWith(
      fontSize: lerpDouble(24, 22, t),
      color: dark ? AppColors.neutral200 : AppColors.neutral800,
    );

    return Stack(
      children: [
        widget.child,
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            height: height,
            color: theme.scaffoldBackgroundColor,
            child: Stack(
              children: [
                if (widget.leading != null)
                  Positioned(
                    left: AppSpacing.md,
                    top: leadingTop,
                    child: widget.leading!,
                  ),
                Positioned(
                  left: titleLeft,
                  top: titleTop,
                  right: AppSpacing.md,
                  child: Text(
                    widget.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: titleStyle,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
