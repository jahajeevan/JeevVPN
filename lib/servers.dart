import 'package:flutter/material.dart';
import 'theme.dart';
import 'state.dart';
import 'server_model.dart';
import 'server_manager.dart';
import 'widgets.dart';

class ServersScreen extends StatelessWidget {
  final VoidCallback onDone;
  const ServersScreen({super.key, required this.onDone});

  void _choose(BuildContext context, AppState app, ServerModel node) {
    final result = app.servers.selectServer(node);
    switch (result) {
      case SwitchResult.locked:
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF1B2130),
          content: Text(
              'Server switching locked. Wait ${app.servers.cooldownLabel} before changing again.',
              style: const TextStyle(color: Colors.white)),
        ));
        return;
      case SwitchResult.switched:
        if (app.vpn.isConnected) app.vpn.switchTo(node);
        onDone();
        return;
      case SwitchResult.unchanged:
        onDone();
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = AppColors.of(context);
    final sm = app.servers;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      children: [
        Text('Locations',
            style: display(28, weight: FontWeight.w700, color: c.ink)),
        const SizedBox(height: 4),
        Text('Pick a node. Stealth TLS on 443 everywhere.',
            style: TextStyle(color: c.sub)),
        const SizedBox(height: 18),

        // Cooldown lock banner (anti-spam switching).
        if (sm.locked)
          FadeSlideIn(child: _CooldownBanner(sm: sm)),
        if (sm.locked) const SizedBox(height: 16),

        // Smart connect → the recommended (fastest) node.
        FadeSlideIn(
          child: GlassCard(
            blur: 14,
            onTap: () => _choose(context, app, _recommended()),
            child: Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                    gradient:
                        const LinearGradient(colors: [kMint, kGreenCore]),
                    borderRadius: BorderRadius.circular(13)),
                child: const Icon(Icons.bolt_rounded, color: Colors.white),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Smart Connect',
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: c.ink,
                              fontSize: 15)),
                      const SizedBox(height: 2),
                      Text('Fastest node for you — ${_recommended().name}',
                          style: TextStyle(color: c.sub, fontSize: 12.5)),
                    ]),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: sm.locked ? c.faint : kGreenDeep),
            ]),
          ),
        ),
        const SizedBox(height: 18),
        Text('ALL LOCATIONS',
            style: TextStyle(
                fontSize: 11.5,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
                color: c.faint)),
        const SizedBox(height: 10),
        for (int i = 0; i < sm.servers.length; i++)
          FadeSlideIn(
            delayMs: 60 * i,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ServerRow(
                node: sm.servers[i],
                selected: sm.current.id == sm.servers[i].id,
                locked: sm.locked,
                ping: sm.pingFor(sm.servers[i].id),
                onTap: () => _choose(context, app, sm.servers[i]),
              ),
            ),
          ),
      ],
    );
  }

  ServerModel _recommended() =>
      kServers.firstWhere((s) => s.recommended, orElse: () => kServers.first);
}

class _CooldownBanner extends StatelessWidget {
  final ServerManager sm;
  const _CooldownBanner({required this.sm});
  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return GlassCard(
      tint: const Color(0xFFEAA23B).withOpacity(c.dark ? 0.12 : 0.14),
      border: Border.all(color: const Color(0xFFEAA23B).withOpacity(0.5)),
      child: Row(children: [
        SizedBox(
          width: 52,
          height: 52,
          child: Stack(alignment: Alignment.center, children: [
            SizedBox(
              width: 52,
              height: 52,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: sm.cooldownProgress),
                duration: const Duration(milliseconds: 500),
                builder: (context, v, _) => CircularProgressIndicator(
                  value: v,
                  strokeWidth: 4,
                  backgroundColor: c.track,
                  valueColor:
                      const AlwaysStoppedAnimation(Color(0xFFEAA23B)),
                ),
              ),
            ),
            Text(sm.cooldownLabel,
                style: mono(14, weight: FontWeight.w700, color: c.ink)),
          ]),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Icon(Icons.lock_clock_rounded,
                  size: 16, color: Color(0xFFEAA23B)),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Server switching temporarily locked',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: c.ink,
                        fontSize: 14)),
              ),
            ]),
            const SizedBox(height: 4),
            Text(
                'Please wait ${sm.cooldownLabel} before changing location again.',
                style: TextStyle(color: c.sub, fontSize: 12.5)),
          ]),
        ),
      ]),
    );
  }
}

class _ServerRow extends StatelessWidget {
  final ServerModel node;
  final bool selected;
  final bool locked;
  final int? ping;
  final VoidCallback onTap;
  const _ServerRow(
      {required this.node,
      required this.selected,
      required this.locked,
      required this.ping,
      required this.onTap});

  // Real-latency → signal fraction + colour + label.
  double get _signal {
    if (ping == null || ping! < 0) return 0.0;
    return (1 - (ping! / 300.0)).clamp(0.12, 1.0);
  }

  Color get _signalColor {
    if (ping == null || ping! < 0) return const Color(0xFFE5484D);
    if (ping! < 90) return kGreen;
    if (ping! < 200) return const Color(0xFFEAA23B);
    return const Color(0xFFE5484D);
  }

  String get _signalLabel {
    if (ping == null) return 'measuring…';
    if (ping! < 0) return 'unreachable';
    if (ping! < 90) return 'Excellent';
    if (ping! < 200) return 'Good';
    return 'Fair';
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final barColor = _signalColor;
    return GlassCard(
      onTap: onTap,
      tint: selected ? kGreen.withOpacity(c.dark ? 0.12 : 0.14) : null,
      border: selected
          ? Border.all(color: kGreen.withOpacity(0.5), width: 1.4)
          : null,
      child: Opacity(
        opacity: locked && !selected ? 0.55 : 1.0,
        child: Row(children: [
          Text(node.flag, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(node.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: c.ink,
                              fontSize: 15)),
                    ),
                    const SizedBox(width: 8),
                    node.recommended
                        ? _pill('RECOMMENDED', kGreenDeep,
                            kGreen.withOpacity(0.16))
                        : _pill('FAST', const Color(0xFF2B8CFF),
                            const Color(0xFF2B8CFF).withOpacity(0.14)),
                    if (selected) ...[
                      const SizedBox(width: 6),
                      const Icon(Icons.check_circle_rounded,
                          color: kGreenDeep, size: 18),
                    ],
                  ]),
                  const SizedBox(height: 3),
                  Row(children: [
                    Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                            color: node.online ? kGreen : c.faint,
                            shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Text(node.online ? 'Online' : 'Offline',
                        style: TextStyle(
                            color: node.online ? kGreenDeep : c.faint,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600)),
                    Text('  ·  ${node.location}',
                        style: TextStyle(color: c.sub, fontSize: 12)),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    SizedBox(
                        width: 80,
                        child: MiniBar(value: _signal, color: barColor)),
                    const SizedBox(width: 8),
                    Text(_signalLabel,
                        style: TextStyle(fontSize: 11, color: c.faint)),
                  ]),
                ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(ping == null ? '…' : (ping! < 0 ? '—' : '$ping'),
                style: mono(15, color: c.ink)),
            Text('ms', style: TextStyle(fontSize: 10, color: c.faint)),
          ]),
        ]),
      ),
    );
  }

  Widget _pill(String s, Color fg, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
        child: Text(s,
            style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
                color: fg)),
      );
}
