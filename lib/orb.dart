import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme.dart';
import 'state.dart';
import 'vpn_service.dart';

/// The hero connect control. Tapping it toggles the tunnel. A single repeating
/// controller drives every painted effect.
class ConnectOrb extends StatefulWidget {
  const ConnectOrb({super.key});
  @override
  State<ConnectOrb> createState() => _ConnectOrbState();
}

class _ConnectOrbState extends State<ConnectOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 16))
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
    final status = app.vpn.status;
    return GestureDetector(
      onTap: () {
        if (app.haptics) HapticFeedback.mediumImpact();
        app.toggleConnection();
      },
      child: SizedBox(
        width: 288,
        height: 288,
        child: Stack(alignment: Alignment.center, children: [
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) => CustomPaint(
              size: const Size(288, 288),
              painter: OrbPainter(t: _c.value * 16, status: status, dark: dark),
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
        width: 60,
        height: 60,
        child: CircularProgressIndicator(
            strokeWidth: 3.0,
            valueColor: AlwaysStoppedAnimation(Colors.white)),
      );
    }
    final on = status == VpnStatus.connected;
    final iconColor = on ? Colors.white : (dark ? Colors.white : kInk);
    return TweenAnimationBuilder<double>(
      key: ValueKey(on),
      tween: Tween(begin: 0.82, end: 1.0),
      duration: const Duration(milliseconds: 460),
      curve: Curves.easeOutBack,
      builder: (context, s, child) => Transform.scale(scale: s, child: child),
      child: Icon(Icons.power_settings_new_rounded, size: 76, color: iconColor),
    );
  }
}

class OrbPainter extends CustomPainter {
  final double t; // seconds
  final VpnStatus status;
  final bool dark;
  OrbPainter({required this.t, required this.status, required this.dark});

  static double _lerp(double a, double b, double x) => a + (b - a) * x;
  static double _op(double x) => x.clamp(0.0, 1.0);
  static const double tau = math.pi * 2;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final base = size.width / 2;
    final on = status == VpnStatus.connected;
    final connecting = status == VpnStatus.connecting;

    // Subtle breathing of the whole orb.
    final r = base * (1 + (on ? 0.02 : 0.012) * math.sin(t * 1.7));
    final accent = on ? kGreen : (dark ? Colors.white : kInk);

    // 1. Ambient glow (pulsing).
    final glowPulse = 0.5 + 0.5 * math.sin(t * 1.3);
    final glowR = r * (on ? (1.12 + 0.07 * glowPulse) : 0.95);
    canvas.drawCircle(
      center,
      glowR,
      Paint()
        ..shader = RadialGradient(colors: [
          accent.withOpacity(
              _op(on ? 0.28 + 0.14 * glowPulse : (dark ? 0.10 : 0.06))),
          Colors.transparent,
        ]).createShader(Rect.fromCircle(center: center, radius: glowR)),
    );

    // 2. Outer rotating tick ring (twinkling).
    const ticks = 56;
    final tickR = r * 0.95;
    final tickPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (int i = 0; i < ticks; i++) {
      final a = t * 0.16 + i * (tau / ticks);
      final tw = 0.5 + 0.5 * math.sin(t * 2 + i * 0.7);
      final len = r * (0.014 + 0.02 * tw);
      final p1 = center +
          Offset(math.cos(a) * (tickR - len), math.sin(a) * (tickR - len));
      final p2 = center +
          Offset(math.cos(a) * (tickR + len), math.sin(a) * (tickR + len));
      tickPaint.color = accent.withOpacity(_op(
          (on ? 0.20 : (dark ? 0.09 : 0.06)) + 0.18 * tw * (on ? 1 : 0.5)));
      canvas.drawLine(p1, p2, tickPaint);
    }

    // 3. Two counter-rotating energy arcs.
    for (int k = 0; k < 2; k++) {
      final dir = k == 0 ? 1.0 : -1.0;
      final ar = r * (0.87 + k * 0.04);
      final start = t * (connecting ? 3.5 : 0.6) * dir + k * math.pi;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: ar),
        start,
        0.9 + 0.3 * k,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = on ? 3 : 1.6
          ..strokeCap = StrokeCap.round
          ..color = (k == 0 ? accent : kMint)
              .withOpacity(_op(on ? 0.5 : (dark ? 0.14 : 0.10))),
      );
    }

    // 4. Expanding pulse rings (connected).
    if (on) {
      for (int i = 0; i < 4; i++) {
        final ph = ((t / 3.2) + i / 4.0) % 1.0;
        final rr = _lerp(r * 0.60, r * 1.08, ph);
        canvas.drawCircle(
          center,
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6
            ..color = kGreen.withOpacity(_op((1 - ph) * 0.4)),
        );
      }
    }

    // 5. Rotating conic sheen ring.
    final ringR = r * 0.80;
    final sweepColors = on
        ? [
            Colors.transparent,
            kGreen.withOpacity(0.0),
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

    // 6. Connecting spinner (multi-arc).
    if (connecting) {
      for (int k = 0; k < 3; k++) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: r * (0.66 - k * 0.06)),
          t * (6 - k * 1.5) + k * 2,
          1.1 - k * 0.2,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4.0 - k
            ..strokeCap = StrokeCap.round
            ..color = (k.isEven ? kGreen : kMint).withOpacity(_op(0.9 - k * 0.2)),
        );
      }
    }

    // 7. Orbiting particles — two counter-rotating layers.
    if (on || connecting) {
      _particles(canvas, center, r,
          count: 12, orbit: 0.86, speed: 0.7, sizeBase: 1.6, color: kMint, glow: kGreen);
      _particles(canvas, center, r,
          count: 7, orbit: 0.72, speed: -1.1, sizeBase: 1.1, color: kGreen, glow: kGreen);
    }

    // 8. Core sphere.
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

    // 8b. Inner energy rings + moving hotspot (connected).
    if (on) {
      for (int i = 0; i < 3; i++) {
        final ph = ((t / 2.4) + i / 3.0) % 1.0;
        final rr = coreR * (0.2 + ph * 0.85);
        canvas.drawCircle(
          center,
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4
            ..color = Colors.white.withOpacity(_op((1 - ph) * 0.5)),
        );
      }
      final ha = t * 0.9;
      final hp = center +
          Offset(math.cos(ha) * coreR * 0.3, math.sin(ha) * coreR * 0.3);
      canvas.drawCircle(
        hp,
        coreR * 0.5,
        Paint()
          ..shader = RadialGradient(colors: [
            Colors.white.withOpacity(0.5),
            Colors.white.withOpacity(0.0),
          ]).createShader(Rect.fromCircle(center: hp, radius: coreR * 0.5)),
      );
    }

    // 9. Rim + top-left specular highlight.
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
    final hiCenter = center + Offset(-coreR * 0.35, -coreR * 0.4);
    canvas.drawCircle(
      hiCenter,
      coreR * 0.72,
      Paint()
        ..shader = RadialGradient(colors: [
          Colors.white.withOpacity(on ? 0.5 : 0.62),
          Colors.white.withOpacity(0.0),
        ]).createShader(Rect.fromCircle(center: hiCenter, radius: coreR * 0.72)),
    );
  }

  void _particles(Canvas canvas, Offset center, double r,
      {required int count,
      required double orbit,
      required double speed,
      required double sizeBase,
      required Color color,
      required Color glow}) {
    for (int i = 0; i < count; i++) {
      final a = t * speed + i * (tau / count);
      final orbitR = r * orbit + math.sin(t * 2 + i) * 5;
      final pos = center + Offset(math.cos(a) * orbitR, math.sin(a) * orbitR);
      final tw = (math.sin(t * 3 + i) + 1) / 2;
      final sz = sizeBase + tw * 1.6;
      canvas.drawCircle(pos, sz + 3, Paint()..color = glow.withOpacity(_op(0.16 * tw + 0.05)));
      canvas.drawCircle(pos, sz, Paint()..color = color.withOpacity(_op(0.6 + 0.4 * tw)));
    }
  }

  @override
  bool shouldRepaint(OrbPainter old) =>
      old.t != t || old.status != status || old.dark != dark;
}
