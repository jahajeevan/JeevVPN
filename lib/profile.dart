import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'theme.dart';
import 'state.dart';
import 'widgets.dart';
import 'otp_service.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = AppColors.of(context);
    final signedIn = app.isSignedIn;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      children: [
        Text('Account', style: display(28, weight: FontWeight.w700, color: c.ink)),
        const SizedBox(height: 18),
        FadeSlideIn(
          child: GlassCard(
            blur: 14,
            child: Row(children: [
              const _Avatar(),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          signedIn
                              ? (app.signedInName?.isNotEmpty == true
                                  ? app.signedInName!
                                  : 'Signed in')
                              : 'Guest device',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: c.ink)),
                      const SizedBox(height: 3),
                      Text(
                          signedIn
                              ? [
                                  app.signedInEmail!,
                                  if (app.signedInAge != null)
                                    'Age ${app.signedInAge}',
                                ].join('  ·  ')
                              : 'Not signed in',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: c.sub, fontSize: 13)),
                    ]),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                    color: kGreen.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(999)),
                child: Text(signedIn ? 'MEMBER' : 'FREE',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: kGreenDeep)),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 14),
        if (!signedIn)
          FadeSlideIn(
            delayMs: 60,
            child: GlassCard(
              blur: 14,
              onTap: () => _showSignIn(context),
              tint: kGreen.withOpacity(c.dark ? 0.10 : 0.12),
              child: Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      gradient:
                          const LinearGradient(colors: [kMint, kGreenCore]),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.mark_email_read_rounded,
                      color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sign in to JeevVPN',
                            style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: c.ink,
                                fontSize: 15)),
                        const SizedBox(height: 2),
                        Text('Email OTP verified · your web account',
                            style: TextStyle(color: c.sub, fontSize: 12.5)),
                      ]),
                ),
                const Icon(Icons.chevron_right_rounded, color: kGreenDeep),
              ]),
            ),
          )
        else
          FadeSlideIn(
            delayMs: 60,
            child: GlassCard(
              onTap: () => app.signOut(),
              child: Row(children: [
                Icon(Icons.logout_rounded, size: 20, color: c.sub),
                const SizedBox(width: 14),
                Text('Sign out',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: c.ink, fontSize: 14.5)),
                const Spacer(),
                const Icon(Icons.chevron_right_rounded, color: kGreenDeep),
              ]),
            ),
          ),
        const SizedBox(height: 14),
        FadeSlideIn(delayMs: 120, child: _UsageCard(app: app, c: c)),
        const SizedBox(height: 14),
        FadeSlideIn(
          delayMs: 180,
          child: GlassCard(
            child: Column(children: [
              _infoRow(c, Icons.dns_rounded, 'Server',
                  '${app.servers.current.name} · ${app.servers.current.city}'),
              Divider(height: 22, color: c.track),
              _infoRow(c, Icons.lock_rounded, 'Protocol', 'HTTP over TLS · 443'),
              Divider(height: 22, color: c.track),
              _infoRow(c, Icons.verified_user_rounded, 'Status',
                  app.vpn.isConnected ? 'Protected' : 'Idle'),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(AppColors c, IconData icon, String k, String v) {
    return Row(children: [
      Icon(icon, size: 18, color: c.faint),
      const SizedBox(width: 12),
      Text(k, style: TextStyle(color: c.sub, fontSize: 13.5)),
      const Spacer(),
      Flexible(
        child: Text(v,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: TextStyle(
                color: c.ink, fontWeight: FontWeight.w600, fontSize: 13)),
      ),
    ]);
  }

  void _showSignIn(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const SignInSheet(),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      padding: const EdgeInsets.all(2.5),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(colors: [kGreen, kAqua, kMint, kGreen]),
      ),
      child: const DecoratedBox(
        decoration:
            BoxDecoration(shape: BoxShape.circle, color: Color(0xFF0B0F17)),
        child: Icon(Icons.person_rounded, color: Colors.white, size: 28),
      ),
    );
  }
}

class _UsageCard extends StatelessWidget {
  final AppState app;
  final AppColors c;
  const _UsageCard({required this.app, required this.c});
  @override
  Widget build(BuildContext context) {
    final total = app.vpn.downMb + app.vpn.upMb;
    return GlassCard(
      blur: 14,
      child: Row(children: [
        SizedBox(
            width: 96,
            height: 96,
            child: _Donut(down: app.vpn.downMb, up: app.vpn.upMb)),
        const SizedBox(width: 18),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('This session',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: c.ink, fontSize: 15)),
            const SizedBox(height: 10),
            _legend(kGreen, 'Download', '${app.vpn.downMb.toStringAsFixed(1)} MB'),
            const SizedBox(height: 6),
            _legend(kAqua, 'Upload', '${app.vpn.upMb.toStringAsFixed(1)} MB'),
            const SizedBox(height: 8),
            Text(
                total <= 0
                    ? 'Connect to start counting'
                    : 'Total ${total.toStringAsFixed(1)} MB',
                style: TextStyle(color: c.sub, fontSize: 12)),
          ]),
        ),
      ]),
    );
  }

  Widget _legend(Color color, String k, String v) {
    return Row(children: [
      Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(
              color: color, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 8),
      Text(k, style: TextStyle(color: c.sub, fontSize: 12.5)),
      const Spacer(),
      Text(v,
          style: TextStyle(
              color: c.ink, fontWeight: FontWeight.w600, fontSize: 12.5)),
    ]);
  }
}

class _Donut extends StatelessWidget {
  final double down, up;
  const _Donut({required this.down, required this.up});
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final total = down + up;
    final frac = total <= 0 ? 0.0 : (down / total);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: total <= 0 ? 0.0 : 1.0),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOut,
      builder: (context, a, _) => CustomPaint(
          painter: _DonutPainter(frac: frac, anim: a, track: c.track)),
    );
  }
}

class _DonutPainter extends CustomPainter {
  final double frac, anim;
  final Color track;
  _DonutPainter({required this.frac, required this.anim, required this.track});
  @override
  void paint(Canvas canvas, Size size) {
    const sw = 12.0;
    final rect = Rect.fromCircle(
        center: size.center(Offset.zero), radius: size.width / 2 - 7);
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw
        ..color = track,
    );
    const start = -math.pi / 2;
    canvas.drawArc(
      rect,
      start + math.pi * 2 * frac,
      math.pi * 2 * (1 - frac) * anim,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw
        ..strokeCap = StrokeCap.round
        ..color = kAqua,
    );
    canvas.drawArc(
      rect,
      start,
      math.pi * 2 * frac * anim,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = sw
        ..strokeCap = StrokeCap.round
        ..color = kGreen,
    );
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.frac != frac || old.anim != anim || old.track != track;
}

/// Email → OTP sign-in. Calls the JeevVPN backend (real email OTP).
class SignInSheet extends StatefulWidget {
  const SignInSheet({super.key});
  @override
  State<SignInSheet> createState() => _SignInSheetState();
}

class _SignInSheetState extends State<SignInSheet> {
  int _step = 0;
  String _email = '';
  String _code = '';
  String _token = '';
  bool _busy = false;
  String? _error;
  final _emailCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final e = _emailCtrl.text.trim();
    if (e.isEmpty || !e.contains('@')) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final token = await OtpService.sendCode(e);
      if (!mounted) return;
      setState(() {
        _email = e;
        _token = token;
        _step = 1;
        _busy = false;
      });
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = err.toString();
      });
    }
  }

  Future<void> _verify() async {
    if (_code.length < 6) {
      setState(() => _error = 'Enter the 6-digit code.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await OtpService.verifyCode(email: _email, code: _code, token: _token);
      if (!mounted) return;
      final app = AppScope.of(context);
      final messenger = ScaffoldMessenger.of(context);
      app.signIn(_email);
      Navigator.pop(context);
      messenger.showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        content: Text('Signed in as $_email'),
      ));
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = err.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        decoration: BoxDecoration(
          color: c.dark ? const Color(0xFF0C1119) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: c.track, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                    gradient:
                        const LinearGradient(colors: [kMint, kGreenCore]),
                    borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.shield_rounded, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Text(_step == 0 ? 'Sign in' : 'Verify email',
                  style: display(20, weight: FontWeight.w700, color: c.ink)),
            ]),
            const SizedBox(height: 10),
            Text(
                _step == 0
                    ? "Use your JeevVPN web account. We'll email you a one-time code."
                    : 'Enter the 6-digit code sent to $_email.',
                style: TextStyle(color: c.sub, fontSize: 13.5)),
            const SizedBox(height: 20),
            if (_step == 0) ...[
              _EmailField(controller: _emailCtrl, enabled: !_busy),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: _busy ? 'Sending…' : 'Send code',
                  icon: _busy ? null : Icons.arrow_forward_rounded,
                  onTap: _busy ? null : _send,
                ),
              ),
            ] else ...[
              OtpBoxes(onChanged: (v) => _code = v),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: _busy ? 'Verifying…' : 'Verify & sign in',
                  icon: _busy ? null : Icons.check_rounded,
                  onTap: _busy ? null : _verify,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() {
                              _step = 0;
                              _error = null;
                            }),
                    child: const Text('Change email')),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 10),
              Row(children: [
                const Icon(Icons.error_outline_rounded,
                    size: 16, color: Color(0xFFE5484D)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(_error!,
                      style: const TextStyle(
                          color: Color(0xFFE5484D), fontSize: 12.5)),
                ),
              ]),
            ],
            const SizedBox(height: 12),
            Center(
              child: Text('Secured by JeevVPN · code expires in 10 min',
                  style: TextStyle(fontSize: 11.5, color: c.faint)),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmailField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  const _EmailField({required this.controller, this.enabled = true});
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.emailAddress,
      style: TextStyle(color: c.ink),
      decoration: InputDecoration(
        hintText: 'you@example.com',
        hintStyle: TextStyle(color: c.faint),
        prefixIcon: Icon(Icons.mail_outline_rounded, color: c.faint),
        filled: true,
        fillColor: c.glass,
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: c.glassBorder)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: kGreen, width: 1.6)),
        disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: c.glassBorder)),
      ),
    );
  }
}
