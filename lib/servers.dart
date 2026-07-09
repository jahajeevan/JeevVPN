import 'package:flutter/material.dart';
import 'theme.dart';
import 'state.dart';
import 'widgets.dart';

class ServersScreen extends StatelessWidget {
  final VoidCallback onDone;
  const ServersScreen({super.key, required this.onDone});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final c = AppColors.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
      children: [
        Text('Locations', style: display(28, weight: FontWeight.w700, color: c.ink)),
        const SizedBox(height: 4),
        Text('Pick a node. Stealth TLS on 443 everywhere.',
            style: TextStyle(color: c.sub)),
        const SizedBox(height: 18),
        FadeSlideIn(
          child: GlassCard(
            blur: 14,
            onTap: () {
              app.selectServer(kServers.first);
              onDone();
            },
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
                      Text('Fastest node for you — India',
                          style: TextStyle(color: c.sub, fontSize: 12.5)),
                    ]),
              ),
              const Icon(Icons.chevron_right_rounded, color: kGreenDeep),
            ]),
          ),
        ),
        const SizedBox(height: 18),
        Text('ALL NODES',
            style: TextStyle(
                fontSize: 11.5,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w700,
                color: c.faint)),
        const SizedBox(height: 10),
        for (int i = 0; i < kServers.length; i++)
          FadeSlideIn(
            delayMs: 50 * i,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ServerRow(
                node: kServers[i],
                selected:
                    app.server.id == kServers[i].id && kServers[i].available,
                onTap: () {
                  if (kServers[i].available) {
                    app.selectServer(kServers[i]);
                    onDone();
                  }
                },
              ),
            ),
          ),
      ],
    );
  }
}

class _ServerRow extends StatelessWidget {
  final ServerNode node;
  final bool selected;
  final VoidCallback onTap;
  const _ServerRow(
      {required this.node, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final barColor = node.load < 0.4
        ? kGreen
        : (node.load < 0.7 ? const Color(0xFFEAA23B) : const Color(0xFFE5484D));
    return GlassCard(
      onTap: node.available ? onTap : null,
      tint: selected ? kGreen.withOpacity(c.dark ? 0.12 : 0.14) : null,
      border:
          selected ? Border.all(color: kGreen.withOpacity(0.5), width: 1.4) : null,
      child: Opacity(
        opacity: node.available ? 1.0 : 0.55,
        child: Row(children: [
          Text(node.flag, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(node.city,
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: c.ink,
                            fontSize: 15)),
                    const SizedBox(width: 8),
                    if (!node.available) _pill('SOON', c),
                    if (selected)
                      const Icon(Icons.check_circle_rounded,
                          color: kGreenDeep, size: 18),
                  ]),
                  const SizedBox(height: 2),
                  Text(node.country,
                      style: TextStyle(color: c.sub, fontSize: 12.5)),
                  const SizedBox(height: 8),
                  Row(children: [
                    SizedBox(
                        width: 80,
                        child: MiniBar(value: node.load, color: barColor)),
                    const SizedBox(width: 8),
                    Text('${(node.load * 100).round()}% load',
                        style: TextStyle(fontSize: 11, color: c.faint)),
                  ]),
                ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('${node.ping}',
                style: mono(15, color: node.available ? c.ink : c.faint)),
            Text('ms', style: TextStyle(fontSize: 10, color: c.faint)),
          ]),
        ]),
      ),
    );
  }

  Widget _pill(String s, AppColors c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
            color: c.track, borderRadius: BorderRadius.circular(6)),
        child: Text(s,
            style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: c.sub)),
      );
}
