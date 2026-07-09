import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme.dart';

/// Frosted glass surface. [blur] > 0 enables a real backdrop blur (use
/// sparingly — heavy in long lists). Optional [onTap] adds a clipped ripple.
class GlassCard extends StatelessWidget {
  final Widget child;
  final double radius;
  final double blur;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? tint;
  final Border? border;
  final List<BoxShadow>? shadow;
  const GlassCard({
    super.key,
    required this.child,
    this.radius = 22,
    this.blur = 0,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.tint,
    this.border,
    this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final br = BorderRadius.circular(radius);
    Widget inner = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: tint ?? c.glass,
        borderRadius: br,
        border: border ?? Border.all(color: c.glassBorder, width: 1),
        boxShadow: shadow ??
            [
              BoxShadow(
                color: Colors.black.withOpacity(c.dark ? 0.28 : 0.06),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
      ),
      child: child,
    );

    Widget card = blur > 0
        ? ClipRRect(
            borderRadius: br,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: inner,
            ),
          )
        : inner;

    if (onTap == null) return card;
    return Stack(children: [
      card,
      Positioned.fill(
        child: Material(
          color: Colors.transparent,
          borderRadius: br,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            splashColor: kGreenCore.withOpacity(0.12),
            highlightColor: kGreenCore.withOpacity(0.05),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    ]);
  }
}

/// Fades + slides its child in once, after an optional [delayMs] stagger.
class FadeSlideIn extends StatefulWidget {
  final Widget child;
  final int delayMs;
  final double offset;
  final Duration duration;
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delayMs = 0,
    this.offset = 18,
    this.duration = const Duration(milliseconds: 520),
  });
  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: widget.duration);

  @override
  void initState() {
    super.initState();
    if (widget.delayMs <= 0) {
      _c.forward();
    } else {
      Future<void>.delayed(Duration(milliseconds: widget.delayMs), () {
        if (mounted) _c.forward();
      });
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final v = Curves.easeOutCubic.transform(_c.value);
        return Opacity(
          opacity: v,
          child: Transform.translate(
              offset: Offset(0, (1 - v) * widget.offset), child: child),
        );
      },
    );
  }
}

/// Custom animated toggle switch.
class NeoSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const NeoSwitch({super.key, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOut,
        width: 52,
        height: 30,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient:
              value ? const LinearGradient(colors: [kGreen, kGreenCore]) : null,
          color: value ? null : c.track,
          boxShadow: value
              ? [
                  BoxShadow(
                      color: kGreenCore.withOpacity(0.45),
                      blurRadius: 12,
                      offset: const Offset(0, 3))
                ]
              : null,
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOutBack,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 1))
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Segmented control with an animated sliding highlight.
class SegPicker extends StatelessWidget {
  final List<String> items;
  final int index;
  final ValueChanged<int> onChanged;
  const SegPicker(
      {super.key,
      required this.items,
      required this.index,
      required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return LayoutBuilder(builder: (context, cons) {
      final seg = cons.maxWidth / items.length;
      return Container(
        height: 44,
        decoration: BoxDecoration(
            color: c.track.withOpacity(c.dark ? 0.5 : 0.7),
            borderRadius: BorderRadius.circular(14)),
        child: Stack(children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            left: seg * index + 4,
            top: 4,
            bottom: 4,
            width: seg - 8,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [kGreen, kGreenCore]),
                borderRadius: BorderRadius.circular(11),
                boxShadow: [
                  BoxShadow(color: kGreenCore.withOpacity(0.4), blurRadius: 12)
                ],
              ),
            ),
          ),
          Row(children: [
            for (int i = 0; i < items.length; i++)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(i),
                  child: Center(
                    child: Text(items[i],
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: i == index ? Colors.white : c.sub)),
                  ),
                ),
              ),
          ]),
        ]),
      );
    });
  }
}

/// A thin animated progress bar (load / signal).
class MiniBar extends StatelessWidget {
  final double value;
  final Color color;
  final double height;
  const MiniBar(
      {super.key, required this.value, required this.color, this.height = 6});
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SizedBox(
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: Stack(children: [
          Positioned.fill(child: Container(color: c.track)),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: value.clamp(0.0, 1.0)),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: v,
                child: Container(
                  decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [color.withOpacity(0.7), color])),
                ),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Gradient primary button.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  const PrimaryButton(
      {super.key, required this.label, required this.onTap, this.icon});
  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [kGreen, kGreenCore]),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: kGreenCore.withOpacity(0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6))
              ],
            ),
            child: Container(
              height: 52,
              alignment: Alignment.center,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (icon != null) ...[
                  Icon(icon, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                ],
                Text(label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// Live throughput sparkline (smoothed area chart).
class Sparkline extends StatelessWidget {
  final List<double> data;
  final Color color;
  final double height;
  const Sparkline(
      {super.key, required this.data, required this.color, this.height = 64});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _SparkPainter(List<double>.from(data), color)),
    );
  }
}

class _SparkPainter extends CustomPainter {
  final List<double> d;
  final Color color;
  _SparkPainter(this.d, this.color);
  double _y(Size s, int i) => s.height * (1 - d[i].clamp(0.0, 1.0) * 0.9) - 2;
  @override
  void paint(Canvas canvas, Size size) {
    final n = d.length;
    if (n < 2) return;
    final dx = size.width / (n - 1);
    final path = Path();
    final fill = Path();
    for (int i = 0; i < n; i++) {
      final x = dx * i;
      final y = _y(size, i);
      if (i == 0) {
        path.moveTo(x, y);
        fill.moveTo(x, size.height);
        fill.lineTo(x, y);
      } else {
        final px = dx * (i - 1);
        final py = _y(size, i - 1);
        final mx = (px + x) / 2;
        path.cubicTo(mx, py, mx, y, x, y);
        fill.cubicTo(mx, py, mx, y, x, y);
      }
    }
    fill.lineTo(size.width, size.height);
    fill.close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withOpacity(0.30), color.withOpacity(0.0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = color
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    final lx = dx * (n - 1);
    final ly = _y(size, n - 1);
    canvas.drawCircle(Offset(lx, ly), 7, Paint()..color = color.withOpacity(0.25));
    canvas.drawCircle(Offset(lx, ly), 3.5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparkPainter old) => true;
}

/// A 6-box OTP entry with focus glow (visual — wired to Supabase in v2).
class OtpBoxes extends StatefulWidget {
  final ValueChanged<String> onChanged;
  final int length;
  const OtpBoxes({super.key, required this.onChanged, this.length = 6});
  @override
  State<OtpBoxes> createState() => _OtpBoxesState();
}

class _OtpBoxesState extends State<OtpBoxes> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final text = _ctrl.text;
    return GestureDetector(
      onTap: () => _focus.requestFocus(),
      child: Stack(children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (int i = 0; i < widget.length; i++)
              _box(c, i < text.length ? text[i] : '', i == text.length),
          ],
        ),
        Positioned.fill(
          child: Opacity(
            opacity: 0,
            child: TextField(
              controller: _ctrl,
              focusNode: _focus,
              autofocus: false,
              keyboardType: TextInputType.number,
              maxLength: widget.length,
              showCursor: false,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                  counterText: '', border: InputBorder.none),
              onChanged: (v) {
                setState(() {});
                widget.onChanged(v);
              },
            ),
          ),
        ),
      ]),
    );
  }

  Widget _box(AppColors c, String ch, bool active) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: 46,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.glass,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: active ? kGreen : c.glassBorder, width: active ? 1.8 : 1.2),
        boxShadow: active
            ? [BoxShadow(color: kGreenCore.withOpacity(0.3), blurRadius: 12)]
            : null,
      ),
      child: Text(ch, style: display(22, weight: FontWeight.w700, color: c.ink)),
    );
  }
}
