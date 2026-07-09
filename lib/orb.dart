import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme.dart';
import 'state.dart';

/// The hero connect control. Tapping it toggles the (simulated) tunnel.
/// A single repeating controller drives every painted effect.
class ConnectOrb extends StatefulWidget {
  const ConnectOrb({super.key});
  @override
  State<ConnectOrb> createState() => _ConnectOrbState();
}

class _ConnectOrbState extends State<ConnectOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 12))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final status = app.status;
    return GestureDetector(
      onTap: () {
        if (app.haptics) HapticFeedback.mediumImpact();
        app.toggle();
      },
      child: SizedBox(
        width: 280,
        height: 280,
        child: Stack(alignment: Alignment.center, children: [
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) => CustomPaint(
              size: const Size(280, 280),
              painter: OrbPainter(t: _c.value * 12, status: status, dark: dark),
            ),
          ),
          _CenterMark(status: status, dark: dark),
        ]),
      ),
    );
  }
}

class _CenterMark extends StatelessWidget {
  final VpnStatus status;
  final bool dark;
  const _CenterMark({required this.status, required this.dark});
  @override
  Widget build(BuildContext context) {
    if (status == VpnStatus.connecting) {
      return const SizedBox(
        width: 62,
        height: 62,
        child: CircularProgressIndicator(
            strokeWidth: 3.2,
            valueColor: AlwaysStoppedAnimation(Colors.white)),
      );
    }
    final on = status == VpnStatus.connected;
    final iconColor = on ? Colors.white : (dark ? Colors.white : kInk);
    return TweenAnimationBuilder<double>(
      key: ValueKey(on),
      tween: Tween(begin: 0.85, end: 1.0),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutBack,
      builder: (context, s, child) => Transform.scale(scale: s, child: child),
      child: Icon(Icons.power_settings_new_rounded, size: 74, color: iconColor),
    );
  }
}

class OrbPainter extends CustomPainter {
  final double t; // seconds
  final VpnStatus status;
  final bool dark;
  OrbPainter({required this.t, required this.status, required this.dark});

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final r = size.width / 2;
    final on = status == VpnStatus.connected;
    final connecting = status == VpnStatus.connecting;
    const tau = math.pi * 2;

    // Ambient glow.
    final glowR = r * (on ? 1.15 : 0.95);
    canvas.drawCircle(
      center,
      glowR,
      Paint()
        ..shader = RadialGradient(colors: [
          (on ? kGreen : (dark ? Colors.white : kInk))
              .withOpacity(on ? 0.32 : (dark ? 0.10 : 0.06)),
          Colors.transparent,
        ]).createShader(Rect.fromCircle(center: center, radius: glowR)),
    );

    // Expanding pulse rings while connected.
    if (on) {
      for (int i = 0; i < 3; i++) {
        final ph = ((t / 3.0) + (i / 3.0)) % 1.0;
        final rr = _lerp(r * 0.62, r * 1.0, ph);
        final op = ((1 - ph) * 0.45).clamp(0.0, 1.0);
        canvas.drawCircle(
          center,
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = kGreen.withOpacity(op),
        );
      }
    }

    // Rotating sweep sheen ring.
    final ringR = r * 0.80;
    final sweepColors = on
        ? [
            Colors.transparent,
            kMint.withOpacity(0.0),
            kGreen,
            kMint,
            kGreen,
            Colors.transparent,
          ]
        : [
            Colors.transparent,
            (dark ? Colors.white : kInk).withOpacity(0.0),
            (dark ? Colors.white24 : Colors.black12),
            (dark ? Colors.white38 : Colors.black26),
            Colors.transparent,
            Colors.transparent,
          ];
    canvas.drawCircle(
      center,
      ringR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = on ? 8 : 4
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          transform: GradientRotation(t * (connecting ? 3.0 : 0.9)),
          colors: sweepColors,
        ).createShader(Rect.fromCircle(center: center, radius: ringR)),
    );

    // Fast indeterminate arc while connecting.
    if (connecting) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: r * 0.66),
        t * 6,
        1.3,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 5
          ..strokeCap = StrokeCap.round
          ..color = kGreen,
      );
    }

    // Core sphere.
    final coreR = r * 0.62;
    final coreColors = on
        ? [kMint, kGreen, kGreenDeep]
        : (dark
            ? [const Color(0xFF20283A), const Color(0xFF121722)]
            : [Colors.white, const Color(0xFFE3EAF4)]);
    final coreStops = on ? [0.0, 0.55, 1.0] : [0.0, 1.0];
    canvas.drawCircle(
      center,
      coreR,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.35, -0.4),
          colors: coreColors,
          stops: coreStops,
        ).createShader(Rect.fromCircle(center: center, radius: coreR)),
    );

    // Rim highlight.
    canvas.drawCircle(
      center,
      coreR,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = on
            ? Colors.white.withOpacity(0.35)
            : (dark
                ? Colors.white.withOpacity(0.06)
                : Colors.white.withOpacity(0.9)),
    );

    // Top-left specular highlight.
    final hiCenter = center + Offset(-coreR * 0.35, -coreR * 0.4);
    canvas.drawCircle(
      hiCenter,
      coreR * 0.7,
      Paint()
        ..shader = RadialGradient(colors: [
          Colors.white.withOpacity(on ? 0.5 : 0.6),
          Colors.white.withOpacity(0.0),
        ]).createShader(Rect.fromCircle(center: hiCenter, radius: coreR * 0.7)),
    );

    // Orbiting particles.
    if (on || connecting) {
      const count = 10;
      for (int i = 0; i < count; i++) {
        final a = t * 0.8 + i * (tau / count);
        final orbitR = r * 0.86 + math.sin(t * 2 + i) * 5;
        final pos = center + Offset(math.cos(a) * orbitR, math.sin(a) * orbitR);
        final sz = 1.6 + (math.sin(t * 3 + i) + 1) * 1.3;
        canvas.drawCircle(pos, sz + 3, Paint()..color = kGreen.withOpacity(0.18));
        canvas.drawCircle(pos, sz, Paint()..color = kMint.withOpacity(0.9));
      }
    }
  }

  @override
  bool shouldRepaint(OrbPainter old) =>
      old.t != t || old.status != status || old.dark != dark;
}
