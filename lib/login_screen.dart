import 'package:flutter/material.dart';
import 'theme.dart';
import 'state.dart';
import 'widgets.dart';
import 'background.dart';
import 'otp_service.dart';
import 'auth_service.dart';

/// Full-screen account gate: existing users sign in with email + password;
/// new users create an account (email → one-time code → password + name/age).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

enum _Mode { signIn, signUp }

class _LoginScreenState extends State<LoginScreen> {
  _Mode _mode = _Mode.signIn;
  int _step = 0; // sign-up: 0 = email, 1 = code, 2 = password + profile

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();

  String _email = '';
  String _code = '';
  String _token = '';
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  void _switchMode(_Mode m) {
    if (_busy) return;
    setState(() {
      _mode = m;
      _step = 0;
      _error = null;
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (err) {
      if (mounted) setState(() => _error = err.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── sign in ──
  Future<void> _signIn() => _run(() async {
        final email = _emailCtrl.text.trim();
        final pass = _passCtrl.text;
        if (!email.contains('@') || pass.isEmpty) {
          throw AuthException('Enter your email and password.');
        }
        final acc = await AuthService.login(email: email, password: pass);
        if (!mounted) return;
        await AppScope.of(context).signIn(acc.email, name: acc.name, age: acc.age);
      });

  // ── sign up: send code ──
  Future<void> _sendCode() => _run(() async {
        final email = _emailCtrl.text.trim();
        if (!email.contains('@')) throw AuthException('Enter a valid email address.');
        final token = await OtpService.sendCode(email);
        if (!mounted) return;
        setState(() {
          _email = email;
          _token = token;
          _step = 1;
        });
      });

  // ── sign up: verify code ──
  Future<void> _verifyCode() => _run(() async {
        if (_code.length < 6) throw OtpException('Enter the 6-digit code.');
        await OtpService.verifyCode(email: _email, code: _code, token: _token);
        if (!mounted) return;
        setState(() => _step = 2);
      });

  // ── sign up: create account ──
  Future<void> _register() => _run(() async {
        final pass = _passCtrl.text;
        final pass2 = _pass2Ctrl.text;
        final name = _nameCtrl.text.trim();
        final ageText = _ageCtrl.text.trim();
        if (name.isEmpty) throw AuthException('Enter your name.');
        if (pass.length < 6) {
          throw AuthException('Password must be at least 6 characters.');
        }
        if (pass != pass2) throw AuthException('Passwords do not match.');
        final age = ageText.isEmpty ? null : int.tryParse(ageText);
        final acc = await AuthService.register(
          email: _email,
          code: _code,
          token: _token,
          password: pass,
          name: name,
          age: age,
        );
        if (!mounted) return;
        await AppScope.of(context).signIn(acc.email, name: acc.name, age: acc.age);
      });

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: Stack(children: [
        Positioned.fill(child: AuroraBackground(active: false, dark: c.dark)),
        SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  FadeSlideIn(child: _brand(c)),
                  const SizedBox(height: 26),
                  FadeSlideIn(
                    delayMs: 80,
                    child: GlassCard(
                      blur: 16,
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SegPicker(
                            items: const ['Sign in', 'Create account'],
                            index: _mode == _Mode.signIn ? 0 : 1,
                            onChanged: (i) =>
                                _switchMode(i == 0 ? _Mode.signIn : _Mode.signUp),
                          ),
                          const SizedBox(height: 20),
                          if (_mode == _Mode.signIn)
                            ..._signInBody(c)
                          else
                            ..._signUpBody(c),
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
                  const SizedBox(height: 16),
                  Text('Secured by JeevVPN · your Amrita crew',
                      style: TextStyle(fontSize: 11.5, color: c.faint)),
                ]),
              ),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _brand(AppColors c) => Column(children: [
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
          child: const Icon(Icons.shield_rounded, size: 34, color: Colors.white),
        ),
        const SizedBox(height: 14),
        Text('JeevVPN',
            style: display(30, weight: FontWeight.w700, color: c.ink)),
        const SizedBox(height: 6),
        Text('private, fast, yours', style: TextStyle(color: c.sub, fontSize: 13)),
      ]);

  List<Widget> _signInBody(AppColors c) => [
        Text('Welcome back',
            style: display(19, weight: FontWeight.w700, color: c.ink)),
        const SizedBox(height: 6),
        Text('Sign in with your email and password.',
            style: TextStyle(color: c.sub, fontSize: 13.5)),
        const SizedBox(height: 18),
        _field(c, _emailCtrl, 'Email', Icons.mail_outline_rounded,
            keyboard: TextInputType.emailAddress),
        const SizedBox(height: 12),
        _passwordField(c, _passCtrl, 'Password'),
        const SizedBox(height: 18),
        _primary(_busy ? 'Signing in…' : 'Sign in',
            _busy ? null : _signIn, Icons.login_rounded),
      ];

  List<Widget> _signUpBody(AppColors c) {
    if (_step == 0) {
      return [
        Text('Create your account',
            style: display(19, weight: FontWeight.w700, color: c.ink)),
        const SizedBox(height: 6),
        Text("Enter your email — we'll send a one-time code to verify it.",
            style: TextStyle(color: c.sub, fontSize: 13.5)),
        const SizedBox(height: 18),
        _field(c, _emailCtrl, 'Email', Icons.mail_outline_rounded,
            keyboard: TextInputType.emailAddress),
        const SizedBox(height: 18),
        _primary(_busy ? 'Sending…' : 'Send code',
            _busy ? null : _sendCode, Icons.arrow_forward_rounded),
      ];
    }
    if (_step == 1) {
      return [
        Text('Verify your email',
            style: display(19, weight: FontWeight.w700, color: c.ink)),
        const SizedBox(height: 6),
        Text('Enter the 6-digit code sent to $_email.',
            style: TextStyle(color: c.sub, fontSize: 13.5)),
        const SizedBox(height: 18),
        OtpBoxes(onChanged: (v) => _code = v),
        const SizedBox(height: 18),
        _primary(_busy ? 'Verifying…' : 'Verify',
            _busy ? null : _verifyCode, Icons.check_rounded),
        const SizedBox(height: 6),
        Center(
          child: TextButton(
            onPressed: _busy ? null : () => setState(() => _step = 0),
            child: const Text('Change email'),
          ),
        ),
      ];
    }
    // step 2 — password + profile
    return [
      Text('Almost there',
          style: display(19, weight: FontWeight.w700, color: c.ink)),
      const SizedBox(height: 6),
      Text('Set a password and tell us a bit about you.',
          style: TextStyle(color: c.sub, fontSize: 13.5)),
      const SizedBox(height: 18),
      _passwordField(c, _passCtrl, 'Password'),
      const SizedBox(height: 12),
      _passwordField(c, _pass2Ctrl, 'Confirm password', toggle: false),
      const SizedBox(height: 12),
      _field(c, _nameCtrl, 'Name', Icons.person_outline_rounded,
          keyboard: TextInputType.name),
      const SizedBox(height: 12),
      _field(c, _ageCtrl, 'Age (optional)', Icons.cake_outlined,
          keyboard: TextInputType.number),
      const SizedBox(height: 18),
      _primary(_busy ? 'Creating…' : 'Create account',
          _busy ? null : _register, Icons.check_rounded),
    ];
  }

  Widget _primary(String label, VoidCallback? onTap, IconData icon) => SizedBox(
        width: double.infinity,
        child: PrimaryButton(
            label: label, onTap: onTap, icon: onTap == null ? null : icon),
      );

  Widget _field(AppColors c, TextEditingController ctrl, String hint,
      IconData icon,
      {TextInputType? keyboard}) {
    return TextField(
      controller: ctrl,
      enabled: !_busy,
      keyboardType: keyboard,
      style: TextStyle(color: c.ink),
      decoration: _decoration(c, hint, icon),
    );
  }

  Widget _passwordField(AppColors c, TextEditingController ctrl, String hint,
      {bool toggle = true}) {
    return TextField(
      controller: ctrl,
      enabled: !_busy,
      obscureText: _obscure,
      style: TextStyle(color: c.ink),
      decoration: _decoration(c, hint, Icons.lock_outline_rounded).copyWith(
        suffixIcon: toggle
            ? IconButton(
                icon: Icon(
                    _obscure
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                    color: c.faint,
                    size: 20),
                onPressed: () => setState(() => _obscure = !_obscure),
              )
            : null,
      ),
    );
  }

  InputDecoration _decoration(AppColors c, String hint, IconData icon) =>
      InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: c.faint),
        prefixIcon: Icon(icon, color: c.faint),
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
      );
}
