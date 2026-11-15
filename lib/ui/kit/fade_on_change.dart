import 'package:material_ui/material_ui.dart';

/// Fades its child in whenever [index] changes. The child is never rebuilt, so
/// it is safe to wrap a stateful page view in this.
class FadeOnChange extends StatefulWidget {
  const FadeOnChange({
    super.key,
    required this.index,
    required this.child,
    this.animate = true,
    this.duration = const Duration(milliseconds: 260),
  });

  final int index;
  final Widget child;
  final bool animate;
  final Duration duration;

  @override
  State<FadeOnChange> createState() => _FadeOnChangeState();
}

class _FadeOnChangeState extends State<FadeOnChange>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _opacity = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
  );

  @override
  void initState() {
    super.initState();
    _controller.value = 1;
  }

  @override
  void didUpdateWidget(FadeOnChange oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && oldWidget.index != widget.index) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(opacity: _opacity, child: widget.child);
  }
}