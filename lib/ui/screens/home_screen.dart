import 'package:material_ui/material_ui.dart';

import 'package:free_send/theme/app_icons.dart';
import 'package:free_send/theme/app_theme.dart';
import 'package:free_send/ui/screens/receive_screen.dart';
import 'package:free_send/ui/screens/send_screen.dart';
import 'package:free_send/ui/shell.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const sendColor = Color(0xFF1EFF7C);
    const receiveColor = Color(0xFF1E90FF);
    const sendIconColor = Color(0xFF1C1C1C);
    const receiveIconColor = Color(0xFFFFFFFF);

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: kPagePadding,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 600;
              final gap = compact ? AppSpacing.lg : AppSpacing.xl;
              final available = constraints.maxWidth - AppSpacing.lg * 2 - gap;
              final diameter = (available / 2)
                  .clamp(compact ? 80.0 : 96.0, compact ? 108.0 : 140.0);
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CircleAction(
                    icon: AppIcons.sendPlane,
                    label: 'Send',
                    diameter: diameter,
                    color: sendColor,
                    iconColor: sendIconColor,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const SendScreen(),
                      ),
                    ),
                  ),
                  SizedBox(width: gap),
                  _CircleAction(
                    icon: AppIcons.inbox,
                    label: 'Receive',
                    diameter: diameter,
                    color: receiveColor,
                    iconColor: receiveIconColor,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ReceiveScreen(),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _CircleAction extends StatefulWidget {
  const _CircleAction({
    required this.icon,
    required this.label,
    required this.diameter,
    required this.color,
    required this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final double diameter;
  final Color color;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  State<_CircleAction> createState() => _CircleActionState();
}

class _CircleActionState extends State<_CircleAction> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final circle = _hovered
        ? Color.lerp(widget.color, const Color(0xFF000000), 0.16)!
        : widget.color;
    return Semantics(
      button: true,
      label: widget.label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: widget.diameter,
                height: widget.diameter,
                decoration: BoxDecoration(
                  color: circle,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.icon,
                  size: widget.diameter * 0.38,
                  color: widget.iconColor,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                widget.label,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
