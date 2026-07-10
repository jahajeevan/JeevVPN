import 'package:flutter/material.dart';
import 'theme.dart';
import 'state.dart';
import 'vpn_service.dart';
import 'server_model.dart';
import 'widgets.dart';
import 'orb.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback onOpenServers;
  final VoidCallback onOpenProfile;
  const HomeScreen(
      {super.key, required this.onOpenServers, required this.onOpenProfile});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = AppColors.of(context);
    final vpn = app.vpn;
    final status = vpn.status;
    final statusText = switch (status) {
      VpnStatus.connected => 'Protected',
      VpnStatus.connecting => 'Securing your connection…',
      VpnStatus.disconnected => 'Not connected',
    };
    final statusColor = switch (status) {
      VpnStatus.connected => kGreenDeep,
      VpnStatus.connecting => const Color(0xFFEAA23B),
      VpnStatus.disconnected => c.sub,
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      children: [
        Row(children: [
          const _BrandMark(),
          const SizedBox(width: 10),
          Text('JeevVPN',
              style: display(20, weight: FontWeight.w700, color: c.ink)),
          const Spacer(),
          _CircleIconButton(
              icon: c.dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              onTap: () => app.toggleThemeQuick(c.dark)),
          const SizedBox(width: 8),
          _CircleIconButton(icon: Icons.person_rounded, onTap: onOpenProfile),
        ]),
        const SizedBox(height: 14),
        const Center(child: FadeSlideIn(child: ConnectOrb())),
        const SizedBox(height: 8),
        Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Text(statusText,
                key: ValueKey(statusText),
                textAlign: TextAlign.center,
                style:
                    display(24, weight: FontWeight.w700, color: statusColor)),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: Text(
              status == VpnStatus.connected
                  ? 'Tap the orb to disconnect'
                  : 'Tap the orb to connect',
              style: TextStyle(color: c.sub, fontSize: 13)),
        ),
        if (vpn.errorText != null && status == VpnStatus.disconnected)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: Text(vpn.errorText!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFFE5484D), fontSize: 12.5)),
            ),
          ),
        const SizedBox(height: 18),
        FadeSlideIn(
          delayMs: 60,
          child: _CurrentServerCard(
              server: app.servers.current, onChange: onOpenServers),
        ),
        const SizedBox(height: 14),
        FadeSlideIn(delayMs: 120, child: _LiveMetrics(vpn: vpn, c: c)),
        const SizedBox(height: 14),
        FadeSlideIn(
          delayMs: 180,
          child: Row(children: [
            Expanded(
                child: _StatTile(
                    label: 'VPN IP',
                    value: vpn.isConnected
                        ? (vpn.activeServer?.publicIp.isNotEmpty == true
                            ? vpn.activeServer!.publicIp
                            : app.servers.current.publicIp)
                        : '—')),
            const SizedBox(width: 12),
            Expanded(
                child: _StatTile(
                    label: 'Duration',
                    value: vpn.isConnected ? vpn.clock : '00:00:00',
                    monoFont: true)),
            const SizedBox(width: 12),
            Expanded(
                child: _StatTile(
                    label: 'Ping',
                    value: pingText(app.servers.pingFor(app.servers.current.id)))),
          ]),
        ),
        const SizedBox(height: 14),
        const FadeSlideIn(delayMs: 240, child: RecommendedUsageCard()),
      ],
    );
  }
}

/// Home "Current Server" card — flag, name, location, online status + Change.
class _CurrentServerCard extends StatelessWidget {
  final ServerModel server;
  final VoidCallback onChange;
  const _CurrentServerCard({required this.server, required this.onChange});
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GlassCard(
      blur: 14,
      radius: 18,
      onTap: onChange,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Text(server.flag, style: const TextStyle(fontSize: 26)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text('Current server',
                  style: TextStyle(fontSize: 11, color: c.faint)),
              const SizedBox(width: 8),
              Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                      color: kGreen, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text('Online',
                  style: TextStyle(
                      fontSize: 11,
                      color: kGreenDeep,
                      fontWeight: FontWeight.w600)),
            ]),
            const SizedBox(height: 3),
            Text('${server.name} · ${server.city}',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: c.ink, fontSize: 15)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
              color: kGreen.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('Change',
                style: TextStyle(
                    color: kGreenDeep,
                    fontWeight: FontWeight.w700,
                    fontSize: 12)),
            const SizedBox(width: 2),
            const Icon(Icons.chevron_right_rounded,
                color: kGreenDeep, size: 18),
          ]),
        ),
      ]),
    );
  }
}

class _LiveMetrics extends StatelessWidget {
  final VpnService vpn;
  final AppColors c;
  const _LiveMetrics({required this.vpn, required this.c});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      blur: 14,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: vpn.isConnected ? _connected(context) : _idle(context),
      ),
    );
  }

  Widget _idle(BuildContext context) {
    return Row(children: [
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
            color: kGreen.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.shield_moon_rounded, color: kGreenDeep),
      ),
      const SizedBox(width: 14),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Stealth tunnel ready',
              style: TextStyle(fontWeight: FontWeight.w700, color: c.ink)),
          const SizedBox(height: 3),
          Text('TLS-on-443 · beats DPI throttling',
              style: TextStyle(color: c.sub, fontSize: 12.5)),
        ]),
      ),
    ]);
  }

  Widget _connected(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        _rate(Icons.south_rounded, 'Download', vpn.downRate, kGreen),
        const SizedBox(width: 10),
        _rate(Icons.north_rounded, 'Upload', vpn.upRate, kAqua),
      ]),
      const SizedBox(height: 14),
      Sparkline(data: vpn.spark, color: kGreen, height: 58),
      const SizedBox(height: 10),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(
            '${vpn.downMb.toStringAsFixed(1)} MB down · ${vpn.upMb.toStringAsFixed(1)} MB up',
            style: TextStyle(color: c.sub, fontSize: 12)),
        Row(children: [
          Container(
              width: 7,
              height: 7,
              decoration:
                  const BoxDecoration(color: kGreen, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text('Live',
              style: TextStyle(
                  color: kGreenDeep,
                  fontWeight: FontWeight.w600,
                  fontSize: 12)),
        ]),
      ]),
    ]);
  }

  Widget _rate(IconData icon, String label, double v, Color color) {
    return Expanded(
      child: Row(children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 18, color: color),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 11, color: c.faint)),
          Text('${v.toStringAsFixed(1)} Mbps', style: mono(13, color: c.ink)),
        ]),
      ]),
    );
  }
}

/// Friendly "Recommended Usage" guidance card.
class RecommendedUsageCard extends StatelessWidget {
  const RecommendedUsageCard({super.key});
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GlassCard(
      tint: kAqua.withOpacity(c.dark ? 0.08 : 0.10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
              color: kAqua.withOpacity(0.16),
              borderRadius: BorderRadius.circular(11)),
          child: const Icon(Icons.tips_and_updates_rounded,
              color: kGreenDeep, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Recommended usage',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: c.ink, fontSize: 14.5)),
            const SizedBox(height: 4),
            Text(
              'JeevVPN is tuned for secure browsing, social media, messaging and '
              'everyday use. For the best experience, go easy on heavy-bandwidth '
              'activities like large downloads or competitive gaming.',
              style: TextStyle(color: c.sub, fontSize: 12.5, height: 1.4),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final bool monoFont;
  const _StatTile(
      {required this.label, required this.value, this.monoFont = false});
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GlassCard(
      radius: 16,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 11, color: c.faint)),
        const SizedBox(height: 6),
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: monoFont
                ? mono(13, color: c.ink)
                : TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: c.ink)),
      ]),
    );
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [kMint, kGreenCore]),
        borderRadius: BorderRadius.circular(11),
        boxShadow: [
          BoxShadow(
              color: kGreenCore.withOpacity(0.5),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: const Icon(Icons.shield_rounded, size: 19, color: Colors.white),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _CircleIconButton({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GlassCard(
      radius: 12,
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: SizedBox(
          width: 40, height: 40, child: Icon(icon, size: 19, color: c.sub)),
    );
  }
}
