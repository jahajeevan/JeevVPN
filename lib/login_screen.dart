import 'package:flutter/material.dart';
import 'theme.dart';
import 'state.dart';
import 'widgets.dart';
import 'background.dart';
import 'otp_service.dart';

/// Full-screen account gate shown before the app when no session exists.
/// Create/verify your account with an email one-time code, then continue.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
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
      // Signing in flips the auth gate → the app appears.
      await AppScope.of(context).signIn(_email);
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
    final dark = c.dark;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(children: [
        Positioned.fill(child: AuroraBackground(active: false, dark: dark)),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  FadeSlideIn(
                    child: Column(children: [
                      Container(
                        width: 66,
                        height: 66,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [kMint, kGreenCore]),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                                color: kGreenCore.withOpacity(0.5),
                                blurRadius: 26,
                                offset: const Offset(0, 10))
                          ],
                        ),
                        child: const Icon(Icons.shield_rounded,
                            size: 34, color: Colors.white),
                      ),
                      const SizedBox(height: 16),
                      Text('JeevVPN',
                          style:
                              display(30, weight: FontWeight.w700, color: c.ink)),
                      const SizedBox(height: 6),
                      Text('private, fast, yours',
                          style: TextStyle(color: c.sub, fontSize: 13)),
                    ]),
                  ),
                  const SizedBox(height: 28),
                  FadeSlideIn(
                    delayMs: 80,
                    child: GlassCard(
                      blur: 16,
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_step == 0 ? 'Create your account' : 'Verify your email',
                              style: display(20,
                                  weight: FontWeight.w700, color: c.ink)),
                          const SizedBox(height: 6),
                          Text(
                              _step == 0
                                  ? "Sign in with your email. We'll send you a one-time code to get started."
                                  : 'Enter the 6-digit code sent to $_email.',
                              style: TextStyle(color: c.sub, fontSize: 13.5)),
                          const SizedBox(height: 20),
                          if (_step == 0) ...[
                            _EmailInput(controller: _emailCtrl, enabled: !_busy),
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
                                label: _busy ? 'Verifying…' : 'Verify & continue',
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
                                child: const Text('Change email'),
                              ),
                            ),
                          ],
                          if (_error != null) ...[
                            const SizedBox(height: 12),
                            Row(children: [
                              const Icon(Icons.error_outline_rounded,
                                  size: 16, color: Color(0xFFE5484D)),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(_error!,
                                    style: const TextStyle(
                                        color: Color(0xFFE5484D),
                                        fontSize: 12.5)),
                              ),
                            ]),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('Secured by JeevVPN · email OTP · code expires in 10 min',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11.5, color: c.faint)),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _EmailInput extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  const _EmailInput({required this.controller, this.enabled = true});
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: TextInputType.emailAddress,
      autofocus: true,
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
