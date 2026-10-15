/// Swarm screen: connect local devices and sync datasets between them.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/formatters.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/sync/swarm.dart';
import '../../domain/providers/advanced_providers.dart';
import '../widgets/common.dart';

class SwarmScreen extends ConsumerStatefulWidget {
  const SwarmScreen({super.key});

  @override
  ConsumerState<SwarmScreen> createState() => _SwarmScreenState();
}

class _SwarmScreenState extends ConsumerState<SwarmScreen> {
  final _name = TextEditingController(text: 'My device');
  final _host = TextEditingController(text: '192.168.1.5');
  final _port = TextEditingController(text: '8080');
  List<RemoteDatasetInfo> _remote = const [];
  String? _peerHost;
  int? _peerPort;

  @override
  void dispose() {
    _name.dispose();
    _host.dispose();
    _port.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final node = ref.watch(swarmNodeProvider);
    final state = ref.watch(swarmControllerProvider);
    final ctrl = ref.read(swarmControllerProvider.notifier);

    return ListView(
      padding: const EdgeInsets.all(Spacing.lg),
      children: [
        const SectionHeader(
          title: 'Device Swarm',
          subtitle: 'Sync datasets between devices on the same local network — no cloud, no accounts.',
        ),
        const SizedBox(height: Spacing.md),

        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'This device', subtitle: 'Host a node so peers can pull your datasets'),
              const SizedBox(height: Spacing.sm),
              if (!node.supported)
                Text('Swarm sync is only available in the Android and Windows builds.', style: TextStyle(color: c.warning, fontSize: 12))
              else if (!state.running)
                Row(
                  children: [
                    Expanded(child: TextField(controller: _name, decoration: const InputDecoration(labelText: 'Device name'))),
                    const SizedBox(width: Spacing.sm),
                    FilledButton.icon(
                      onPressed: state.busy ? null : () => ctrl.start(_name.text.trim().isEmpty ? 'Quant RD node' : _name.text.trim()),
                      icon: const Icon(Icons.podcasts_rounded, size: 18),
                      label: const Text('Start node'),
                    ),
                  ],
                )
              else
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: Spacing.sm,
                      runSpacing: Spacing.sm,
                      children: [
                        MetricTile(label: 'Status', value: 'Online', accent: c.success),
                        MetricTile(label: 'Port', value: '${state.port}'),
                        MetricTile(label: 'Peers', value: '${state.peers.length} / ${node.maxPeers}'),
                        MetricTile(label: 'Node id', value: state.nodeId.split('-').last),
                      ],
                    ),
                    const SizedBox(height: Spacing.sm),
                    Text(
                      'Peers can reach this node at <your-device-ip>:${state.port}. Add that address on the other device.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: Spacing.sm),
                    OutlinedButton.icon(
                      onPressed: state.busy ? null : ctrl.stop,
                      icon: const Icon(Icons.stop_circle_outlined, size: 18),
                      label: const Text('Stop node'),
                    ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.md),

        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'Connect to a peer', subtitle: 'Enter the other device’s address and node port'),
              const SizedBox(height: Spacing.sm),
              Row(
                children: [
                  Expanded(flex: 3, child: TextField(controller: _host, decoration: const InputDecoration(labelText: 'Host / IP'))),
                  const SizedBox(width: Spacing.sm),
                  Expanded(flex: 2, child: TextField(controller: _port, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Port'))),
                  const SizedBox(width: Spacing.sm),
                  FilledButton.icon(
                    onPressed: state.busy ? null : _connect,
                    icon: const Icon(Icons.link_rounded, size: 18),
                    label: const Text('Connect'),
                  ),
                ],
              ),
              if (state.message != null) ...[
                const SizedBox(height: Spacing.xs),
                Text(state.message!, style: TextStyle(color: c.success, fontSize: 12)),
              ],
              if (state.error != null) ...[
                const SizedBox(height: Spacing.xs),
                Text(state.error!, style: TextStyle(color: c.danger, fontSize: 12)),
              ],
            ],
          ),
        ),
        const SizedBox(height: Spacing.md),

        if (state.peers.isNotEmpty)
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(title: 'Peers (${state.peers.length})', subtitle: 'Tracked devices, newest last'),
                const SizedBox(height: Spacing.sm),
                for (final p in state.peers)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.devices_rounded, color: c.accent),
                    title: Text(p.name),
                    subtitle: Text('${p.platform} · ${p.host}:${p.port}'),
                  ),
              ],
            ),
          ),
        const SizedBox(height: Spacing.md),

        if (_remote.isNotEmpty)
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(title: 'Datasets on the peer (${_remote.length})', subtitle: 'Pull one into your workspace'),
                const SizedBox(height: Spacing.sm),
                for (final d in _remote)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.table_chart_rounded, color: c.accentAlt),
                    title: Text('${d.symbol} · ${d.interval}'),
                    subtitle: Text('${Fmt.integer(d.bars)} bars · ${Fmt.date(d.start)} → ${Fmt.date(d.end)}'),
                    trailing: OutlinedButton(
                      onPressed: state.busy ? null : () => _pull(d),
                      child: const Text('Pull'),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: Spacing.md),

        GlassCard(
          tint: c.info.withValues(alpha: 0.06),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.hub_rounded, size: 18, color: c.info),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Text(
                  'Scope, stated plainly: this is a real LAN data-sync layer — peers advertise and exchange datasets. '
                  'It does not pool compute or schedule AI workloads across devices; that would require a task broker '
                  'and per-device model runtimes, which are not part of this build.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _connect() async {
    final host = _host.text.trim();
    final port = int.tryParse(_port.text.trim()) ?? 0;
    if (host.isEmpty || port == 0) return;
    final ctrl = ref.read(swarmControllerProvider.notifier);
    final info = await ctrl.probePeer(host, port);
    if (info == null) return;
    final list = await ctrl.listPeer(host, port);
    if (!mounted) return;
    setState(() {
      _remote = list;
      _peerHost = host;
      _peerPort = port;
    });
  }

  Future<void> _pull(RemoteDatasetInfo d) async {
    final host = _peerHost;
    final port = _peerPort;
    if (host == null || port == null) return;
    await ref.read(swarmControllerProvider.notifier).pullIntoWorkspace(host, port, d);
  }
}
