import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'theme.dart';

/// Slow-drifting aurora blobs behind the whole app. Intensifies while
/// connected. Pure CustomPaint — no images, no blur passes.
class AuroraBackground extends StatefulWidget {
  final bool active;
  final bool dark;
  const AuroraBackground({super.key, required this.active, required this.dark});
  @override
  State<AuroraBackground> createState() => _AuroraBackgroundState();
}

class _AuroraBackgroundState extends State<AuroraBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 24))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => CustomPaint(
        size: Size.infinite,
        painter: _AuroraPainter(
            t: _c.value, active: widget.active, dark: widget.dark),
      ),
    );
  }
}

class _AuroraPainter extends CustomPainter {
  final double t;
  final bool active;
  final bool dark;
  _AuroraPainter({required this.t, required this.active, required this.dark});

  @override
  void paint(Canvas canvas, Size size) {
    const tau = math.pi * 2;
    void blob(Color color, double fx, double fy, double phase, double rf,
        double intensity) {
      final cx = size.width * (0.5 + 0.34 * math.sin(t * tau * fx + phase));
      final cy =
          size.height * (0.34 + 0.30 * math.cos(t * tau * fy + phase * 1.3));
      final radius = size.shortestSide * rf;
      canvas.drawCircle(
        Offset(cx, cy),
        radius,
        Paint()
          ..shader = RadialGradient(colors: [
            color.withOpacity(intensity),
            color.withOpacity(0.0),
          ]).createShader(
              Rect.fromCircle(center: Offset(cx, cy), radius: radius)),
      );
    }

    final boost = active ? 1.5 : 1.0;
    final base = dark ? 0.22 : 0.16;
    blob(kGreen, 0.6, 0.8, 0.0, 0.62, base * boost);
    blob(kAqua, 0.8, 0.5, 2.0, 0.55, base * 0.9 * boost);
    blob(kGreenDeep, 0.4, 0.7, 4.1, 0.5, base * 0.7 * boost);
  }

  @override
  bool shouldRepaint(_AuroraPainter old) =>
      old.t != t || old.active != active || old.dark != dark;
}
