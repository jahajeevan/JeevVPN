import 'package:flutter/material.dart';
import 'theme.dart';
import 'state.dart';
import 'widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = AppColors.of(context);
    final modeIndex = switch (app.themeMode.value) {
      ThemeMode.system => 0,
      ThemeMode.light => 1,
      ThemeMode.dark => 2,
    };
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      children: [
        Text('Settings', style: display(28, weight: FontWeight.w700, color: c.ink)),
        const SizedBox(height: 18),
        _section(c, 'APPEARANCE'),
        FadeSlideIn(
          child: GlassCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Theme',
                  style: TextStyle(fontWeight: FontWeight.w700, color: c.ink)),
              const SizedBox(height: 12),
              SegPicker(
                items: const ['System', 'Light', 'Dark'],
                index: modeIndex,
                onChanged: (i) => app.setTheme(switch (i) {
                  0 => ThemeMode.system,
                  1 => ThemeMode.light,
                  _ => ThemeMode.dark,
                }),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 18),
        _section(c, 'CONNECTION'),
        FadeSlideIn(
          delayMs: 60,
          child: GlassCard(
            child: Column(children: [
              _toggle(c, Icons.gpp_good_rounded, 'Kill switch',
                  'Block traffic if the tunnel drops', app.killSwitch,
                  (v) => app.update(kill: v)),
              Divider(height: 20, color: c.track),
              _toggle(c, Icons.flash_on_rounded, 'Auto-connect',
                  'Secure on untrusted Wi-Fi', app.autoConnect,
                  (v) => app.update(auto: v)),
              Divider(height: 20, color: c.track),
              _toggle(c, Icons.block_rounded, 'Block QUIC / UDP',
                  'Beats DPI throttling on campus Wi-Fi', app.blockQuic,
                  (v) => app.update(quic: v)),
            ]),
          ),
        ),
        const SizedBox(height: 18),
        _section(c, 'NOTIFICATIONS'),
        FadeSlideIn(
          delayMs: 120,
          child: GlassCard(
            child: Column(children: [
              _toggle(c, Icons.notifications_active_rounded,
                  'Protected notification', 'Persistent status while connected',
                  app.protectedNotif, (v) => app.update(notif: v)),
              Divider(height: 20, color: c.track),
              _toggle(c, Icons.vibration_rounded, 'Haptics',
                  'Vibrate on connect / disconnect', app.haptics,
                  (v) => app.update(haptic: v)),
            ]),
          ),
        ),
        const SizedBox(height: 18),
        _section(c, 'ABOUT'),
        FadeSlideIn(
          delayMs: 180,
          child: GlassCard(
            child: Column(children: [
              _info(c, Icons.info_outline_rounded, 'Version', '1.1.0'),
              Divider(height: 20, color: c.track),
              _info(c, Icons.public_rounded, 'Website', 'jeevvpn.vercel.app'),
              Divider(height: 20, color: c.track),
              _info(c, Icons.favorite_rounded, 'Made for', 'The JeevVPN crew'),
            ]),
          ),
        ),
        const SizedBox(height: 20),
        Center(
            child: Text('JeevVPN · private, fast, yours',
                style: TextStyle(color: c.faint, fontSize: 12))),
      ],
    );
  }

  Widget _section(AppColors c, String s) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 10),
        child: Text(s,
            style: TextStyle(
                fontSize: 11.5,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
                color: c.faint)),
      );

  Widget _toggle(AppColors c, IconData icon, String title, String sub,
      bool value, ValueChanged<bool> onChanged) {
    return Row(children: [
      Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
            color: kGreen.withOpacity(0.12),
            borderRadius: BorderRadius.circular(11)),
        child: Icon(icon, size: 20, color: kGreenDeep),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.w600, color: c.ink, fontSize: 14.5)),
          const SizedBox(height: 2),
          Text(sub, style: TextStyle(color: c.sub, fontSize: 12)),
        ]),
      ),
      const SizedBox(width: 10),
      NeoSwitch(value: value, onChanged: onChanged),
    ]);
  }

  Widget _info(AppColors c, IconData icon, String k, String v) {
    return Row(children: [
      Icon(icon, size: 18, color: c.faint),
      const SizedBox(width: 12),
      Text(k, style: TextStyle(color: c.sub, fontSize: 13.5)),
      const Spacer(),
      Text(v,
          style: TextStyle(
              color: c.ink, fontWeight: FontWeight.w600, fontSize: 13)),
    ]);
  }
}
