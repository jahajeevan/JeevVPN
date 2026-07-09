import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme.dart';
import 'state.dart';
import 'background.dart';
import 'home.dart';
import 'servers.dart';
import 'profile.dart';
import 'settings.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(statusBarColor: Colors.transparent));
  runApp(const JeevVPNApp());
}

class JeevVPNApp extends StatefulWidget {
  const JeevVPNApp({super.key});
  @override
  State<JeevVPNApp> createState() => _JeevVPNAppState();
}

class _JeevVPNAppState extends State<JeevVPNApp> {
  final AppState _state = AppState();

  @override
  void dispose() {
    _state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      notifier: _state,
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: _state.themeMode,
        builder: (context, mode, _) => MaterialApp(
          title: 'JeevVPN',
          debugShowCheckedModeBanner: false,
          themeMode: mode,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          home: const RootShell(),
        ),
      ),
    );
  }
}

class RootShell extends StatefulWidget {
  const RootShell({super.key});
  @override
  State<RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<RootShell> {
  int _tab = 0;
  void _go(int i) => setState(() => _tab = i);

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final screens = [
      HomeScreen(onOpenServers: () => _go(1), onOpenProfile: () => _go(2)),
      ServersScreen(onDone: () => _go(0)),
      const ProfileScreen(),
      const SettingsScreen(),
    ];
    return Scaffold(
      extendBody: true,
      body: Stack(children: [
        Positioned.fill(
            child: AuroraBackground(active: app.isConnected, dark: dark)),
        Positioned.fill(child: IndexedStack(index: _tab, children: screens)),
      ]),
      bottomNavigationBar: GlassNavBar(index: _tab, onTap: _go),
    );
  }
}

class GlassNavBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const GlassNavBar({super.key, required this.index, required this.onTap});

  static const _items = [
    (Icons.shield_rounded, 'Home'),
    (Icons.public_rounded, 'Servers'),
    (Icons.person_rounded, 'Profile'),
    (Icons.tune_rounded, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              height: 66,
              decoration: BoxDecoration(
                color: c.dark
                    ? Colors.white.withOpacity(0.06)
                    : Colors.white.withOpacity(0.72),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: c.glassBorder),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(c.dark ? 0.4 : 0.10),
                      blurRadius: 24,
                      offset: const Offset(0, 10))
                ],
              ),
              child: LayoutBuilder(builder: (context, cons) {
                final seg = cons.maxWidth / _items.length;
                return Stack(children: [
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    left: seg * index,
                    top: 0,
                    bottom: 0,
                    width: seg,
                    child: Center(
                      child: Container(
                        width: seg - 24,
                        height: 44,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            kGreen.withOpacity(0.22),
                            kGreenCore.withOpacity(0.16)
                          ]),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: kGreen.withOpacity(0.35)),
                        ),
                      ),
                    ),
                  ),
                  Row(children: [
                    for (int i = 0; i < _items.length; i++)
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => onTap(i),
                          child: _NavItem(
                            icon: _items[i].$1,
                            label: _items[i].$2,
                            active: i == index,
                            c: c,
                          ),
                        ),
                      ),
                  ]),
                ]);
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final AppColors c;
  const _NavItem(
      {required this.icon,
      required this.label,
      required this.active,
      required this.c});
  @override
  Widget build(BuildContext context) {
    final color = active ? (c.dark ? kMint : kGreenDeep) : c.faint;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedScale(
          duration: const Duration(milliseconds: 260),
          scale: active ? 1.12 : 1.0,
          curve: Curves.easeOutBack,
          child: Icon(icon, size: 22, color: color),
        ),
        const SizedBox(height: 3),
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 220),
          style: TextStyle(
              fontSize: 10.5,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: color),
          child: Text(label),
        ),
      ],
    );
  }
}
