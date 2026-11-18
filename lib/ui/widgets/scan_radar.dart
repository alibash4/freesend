import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';


/// A sonar-style sweep: the ring, the rotating beam, and one blip per session
/// that fades back into the dark as it ages out.
///
/// The sweep runs on its own ticker so it keeps turning with no session on
/// screen; blips are placed once, from a stable per-session seed, and are not
/// re-rolled on every rebuild.
class ScanRadar extends StatefulWidget {
  const ScanRadar({
    super.key,
    required this.blips,
    required this.active,
    required this.sweepColor,
    required this.ringColor,
    required this.blipColor,
    required this.size,
    required this.seed,
  });

  /// How many devices are on the radar. Empty is the normal state while
  /// waiting for a receiver to open its screen.
  final int blips;

  /// Whether the sweep should turn. False while joining or paused.
  final bool active;

  final Color sweepColor;
  final Color ringColor;
  final Color blipColor;
  final double size;

  /// Changes only when the transport changes, so blip positions stay put
  /// between scans of the same link.
  final int seed;

  @override
  State<ScanRadar> createState() => _ScanRadarState();
}

class _ScanRadarState extends State<ScanRadar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) _sweep.repeat();
  }

  @override
  void didUpdateWidget(ScanRadar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active == oldWidget.active) return;
    if (widget.active) {
      _sweep.repeat();
    } else {
      _sweep.stop();
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _sweep,
        builder: (context, _) => CustomPaint(
          painter: _RadarPainter(
            progress: _sweep.value,
            active: widget.active,
            rings: 3,
            sweepColor: widget.sweepColor,
            ringColor: widget.ringColor,
            blipColor: widget.blipColor,
            blips: [
              for (var i = 0; i < widget.blips; i++)
                _Blip.forIndex(i, widget.seed),
            ],
          ),
        ),
      ),
    );
  }
}

/// A blip's fixed place on the dial, derived from its index and the transport
/// seed so it never jumps while the same set of devices stays in range.
class _Blip {
  const _Blip({
    required this.angle,
    required this.distance,
    required this.size,
  });

  factory _Blip.forIndex(int index, int seed) {
    final random = math.Random('$seed:$index'.hashCode);
    return _Blip(
      angle: random.nextDouble() * math.pi * 2,
      // A hair off the rim and a hair off the centre reads as "in range"
      // without the blips climbing over the rings.
      distance: 0.22 + random.nextDouble() * 0.68,
      size: 4.5 + random.nextDouble() * 2.5,
    );
  }

  final double angle;
  final double distance;
  final double size;
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.progress,
    required this.active,
    required this.rings,
    required this.sweepColor,
    required this.ringColor,
    required this.blipColor,
    required this.blips,
  });

  /// 0..1 around the dial, clockwise from twelve o'clock.
  final double progress;
  final bool active;
  final int rings;
  final Color sweepColor;
  final Color ringColor;
  final Color blipColor;
  final List<_Blip> blips;

  static const _start = -math.pi / 2;
  static const _turn = math.pi * 2;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;

    final dial = Paint()..color = ringColor;
    canvas.drawCircle(center, radius, dial);

    final ringPaint = Paint()
      ..color = sweepColor.withValues(alpha: 0.34)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 1; i <= rings; i++) {
      canvas.drawCircle(center, radius * i / (rings + 0.6), ringPaint);
    }

    // Cross hairs, thinner than the rings so the dial stays quiet.
    final hairline = Paint()
      ..color = sweepColor.withValues(alpha: 0.16)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(center.dx, radius * 0.08),
      Offset(center.dx, radius * 0.92),
      hairline,
    );
    canvas.drawLine(
      Offset(radius * 0.08, center.dy),
      Offset(radius * 0.92, center.dy),
      hairline,
    );

    final sweep = active ? progress : 0.0;
    final arc = Paint()
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: _turn,
        transform: const GradientRotation(_start),
        colors: [
          sweepColor.withValues(alpha: 0),
          sweepColor.withValues(alpha: 0.05),
          sweepColor.withValues(alpha: 0.22),
          sweepColor,
        ],
        stops: const [0, 0.62, 0.88, 1],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, arc);

    // The leading edge, drawn last so it sits on top of the wash.
    final leading = Paint()
      ..color = sweepColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center,
      center +
          Offset(math.cos(_start + _turn * sweep), math.sin(_start + _turn * sweep)) *
              radius,
      leading,
    );

    final dot = Paint()..color = sweepColor;
    canvas.drawCircle(center, 3, dot);
    canvas.drawCircle(
      center,
      7,
      Paint()
        ..color = sweepColor.withValues(alpha: 0.28)
        ..style = PaintingStyle.fill,
    );

    for (final blip in blips) {
      final offset = center +
          Offset(math.cos(blip.angle), math.sin(blip.angle)) *
              radius *
              blip.distance;
      canvas.drawCircle(
        offset,
        blip.size * 2.4,
        Paint()..color = blipColor.withValues(alpha: 0.16),
      );
      canvas.drawCircle(offset, blip.size, Paint()..color = blipColor);
    }
  }

  @override
  bool shouldRepaint(_RadarPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.active != active ||
      oldDelegate.sweepColor != sweepColor ||
      oldDelegate.ringColor != ringColor ||
      oldDelegate.blipColor != blipColor ||
      oldDelegate.blips.length != blips.length;
}
