import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const kGreen = Color(0xFF00B866);
const kGreenDeep = Color(0xFF00A15A);
const kInk = Color(0xFF0B1220);

void main() => runApp(const JeevVPNApp());

class JeevVPNApp extends StatefulWidget {
  const JeevVPNApp({super.key});
  @override
  State<JeevVPNApp> createState() => _JeevVPNAppState();
}

class _JeevVPNAppState extends State<JeevVPNApp> {
  ThemeMode _mode = ThemeMode.system; // system default (light), user can flip

  void _cycleTheme() {
    setState(() {
      _mode = _mode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  ThemeData _theme(Brightness b) {
    final scheme = ColorScheme.fromSeed(seedColor: kGreen, brightness: b);
    final baseText = b == Brightness.dark
        ? ThemeData.dark().textTheme
        : ThemeData.light().textTheme;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: GoogleFonts.interTextTheme(baseText),
      scaffoldBackgroundColor:
          b == Brightness.light ? const Color(0xFFEDF1F8) : const Color(0xFF06080B),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'JeevVPN',
      debugShowCheckedModeBanner: false,
      themeMode: _mode,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: HomeScreen(onToggleTheme: _cycleTheme),
    );
  }
}

enum VpnState { off, connecting, on }

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onToggleTheme});
  final VoidCallback onToggleTheme;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  VpnState _state = VpnState.off;
  late final AnimationController _pulse;
  Timer? _timer;
  int _seconds = 0;

  bool get _on => _state == VpnState.on;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_on) {
      _timer?.cancel();
      setState(() {
        _state = VpnState.off;
        _seconds = 0;
      });
      return;
    }
    setState(() => _state = VpnState.connecting);
    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;
    setState(() => _state = VpnState.on);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  String get _clock {
    final h = (_seconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((_seconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (_seconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? Colors.white : kInk;
    final sub = dark ? Colors.white70 : const Color(0xFF55607A);

    final statusText = switch (_state) {
      VpnState.on => 'Protected',
      VpnState.connecting => 'Connecting…',
      VpnState.off => 'Not connected',
    };
    final statusColor = switch (_state) {
      VpnState.on => kGreenDeep,
      VpnState.connecting => const Color(0xFFF5A524),
      VpnState.off => sub,
    };

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(-0.8, -1),
            radius: 1.4,
            colors: [
              kGreen.withOpacity(dark ? 0.16 : 0.14),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Column(
              children: [
                // top bar
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 4),
                  child: Row(
                    children: [
                      const _Logo(),
                      const SizedBox(width: 10),
                      Text('JeevVPN',
                          style: GoogleFonts.spaceGrotesk(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: ink)),
                      const Spacer(),
                      IconButton(
                        onPressed: widget.onToggleTheme,
                        icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                            color: sub),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                // the orb
                GestureDetector(
                  onTap: _state == VpnState.connecting ? null : _toggle,
                  child: AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, _) {
                      final t = _pulse.value;
                      return SizedBox(
                        width: 260,
                        height: 260,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (_on)
                              Container(
                                width: 220 + t * 40,
                                height: 220 + t * 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: kGreen.withOpacity(0.35 * (1 - t))),
                                ),
                              ),
                            Container(
                              width: 200,
                              height: 200,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: _on
                                      ? [const Color(0xFF22E58F), kGreenDeep]
                                      : (dark
                                          ? [const Color(0xFF1B2130), const Color(0xFF11151F)]
                                          : [Colors.white, const Color(0xFFE6ECF5)]),
                                  center: const Alignment(-0.3, -0.4),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _on
                                        ? kGreen.withOpacity(0.55)
                                        : Colors.black.withOpacity(dark ? 0.5 : 0.18),
                                    blurRadius: 40,
                                    spreadRadius: _on ? 4 : 0,
                                  ),
                                ],
                              ),
                              child: _state == VpnState.connecting
                                  ? const Padding(
                                      padding: EdgeInsets.all(70),
                                      child: CircularProgressIndicator(
                                          strokeWidth: 3, color: kGreenDeep),
                                    )
                                  : Icon(Icons.power_settings_new_rounded,
                                      size: 76,
                                      color: _on ? Colors.white : ink),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 26),
                Text(statusText,
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: statusColor)),
                const SizedBox(height: 4),
                Text(_on ? 'Tap to disconnect' : 'Tap the button to connect',
                    style: TextStyle(color: sub, fontSize: 13)),
                const SizedBox(height: 20),
                // server pill
                _Glass(
                  dark: dark,
                  radius: 999,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🇮🇳', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Text('India Node',
                          style: TextStyle(fontWeight: FontWeight.w600, color: ink)),
                      const SizedBox(width: 6),
                      Text('Mumbai', style: TextStyle(color: sub, fontSize: 12)),
                    ],
                  ),
                ),
                const Spacer(),
                // stat row
                Row(
                  children: [
                    _Stat(dark: dark, label: 'VPN IP', value: _on ? '52.140.121.205' : '—'),
                    const SizedBox(width: 12),
                    _Stat(dark: dark, label: 'Session', value: _on ? _clock : '00:00:00', mono: true),
                    const SizedBox(width: 12),
                    _Stat(dark: dark, label: 'Ping', value: _on ? '16 ms' : '—'),
                  ],
                ),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF16DB83), kGreenDeep]),
        borderRadius: BorderRadius.circular(9),
      ),
      child: const Icon(Icons.shield_rounded, size: 18, color: Colors.white),
    );
  }
}

class _Glass extends StatelessWidget {
  const _Glass({
    required this.child,
    required this.dark,
    this.radius = 20,
    this.padding = const EdgeInsets.all(16),
  });
  final Widget child;
  final bool dark;
  final double radius;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: dark ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(
            color: dark ? Colors.white.withOpacity(0.08) : Colors.white),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(dark ? 0.3 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.dark,
    required this.label,
    required this.value,
    this.mono = false,
  });
  final bool dark;
  final String label;
  final String value;
  final bool mono;
  @override
  Widget build(BuildContext context) {
    final ink = dark ? Colors.white : kInk;
    final sub = dark ? Colors.white60 : const Color(0xFF8A94A6);
    return Expanded(
      child: _Glass(
        dark: dark,
        radius: 18,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: sub, fontSize: 11)),
            const SizedBox(height: 6),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: (mono
                      ? GoogleFonts.robotoMono(
                          fontSize: 13, fontWeight: FontWeight.w600)
                      : const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))
                  .copyWith(color: ink),
            ),
          ],
        ),
      ),
    );
  }
}
