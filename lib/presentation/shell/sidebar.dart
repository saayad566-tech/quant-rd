/// The multi-tab sidebar: Navigate, API Keys and Configs — kept out of the main
/// content area so the primary screen layout is never compromised.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/models/api_provider.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/dataset.dart';
import '../../data/models/workspace.dart';
import '../../domain/knowledge/market_region.dart';
import '../../domain/providers/knowledge_providers.dart';
import '../../domain/providers/core_providers.dart';
import '../../domain/providers/feature_providers.dart';
import '../../domain/providers/ui_providers.dart';
import '../widgets/common.dart';

class Sidebar extends ConsumerWidget {
  final bool compact;
  const Sidebar({super.key, this.compact = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final tab = ref.watch(sidebarTabProvider);

    return Container(
      color: c.surface.withValues(alpha: 0.55),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _BrandHeader(),
          const _WorkspaceSwitcher(),
          _TabBar(
            current: tab,
            onSelect: (t) => ref.read(sidebarTabProvider.notifier).go(t),
          ),
          const Divider(height: 1),
          Expanded(
            child: AnimatedSwitcher(
              duration: Motion.fast,
              child: KeyedSubtree(
                key: ValueKey(tab),
                child: switch (tab) {
                  SidebarTab.navigate => const _NavigatePanel(),
                  SidebarTab.apiKeys => const _ApiKeysPanel(),
                  SidebarTab.configs => const _ConfigsPanel(),
                },
              ),
            ),
          ),
          const _SidebarFooter(),
        ],
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.md, Spacing.md, Spacing.md, Spacing.sm),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [c.accent, c.accentAlt]),
              borderRadius: Radii.rSm,
              boxShadow: Elevation.glowCyan,
            ),
            child: const Icon(Icons.candlestick_chart_rounded, color: Color(0xFF04121A), size: 22),
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppInfo.name, style: Theme.of(context).textTheme.titleMedium),
                Text(AppInfo.tagline, style: Theme.of(context).textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  final SidebarTab current;
  final ValueChanged<SidebarTab> onSelect;

  const _TabBar({required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: Spacing.xs),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: c.glassFill,
          borderRadius: Radii.rSm,
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: SidebarTab.values.map((t) {
            final selected = t == current;
            return Expanded(
              child: GestureDetector(
                onTap: () => onSelect(t),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: Motion.fast,
                  curve: Motion.emphasized,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: selected ? c.accent.withValues(alpha: 0.16) : Colors.transparent,
                    borderRadius: Radii.rXs,
                    border: Border.all(color: selected ? c.accent.withValues(alpha: 0.4) : Colors.transparent),
                  ),
                  child: Text(
                    t.label,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: selected ? c.accent : c.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

// --- Navigate tab ---------------------------------------------------------

class _NavigatePanel extends ConsumerWidget {
  const _NavigatePanel();

  static const _icons = {
    NavDestination.dashboard: Icons.dashboard_rounded,
    NavDestination.data: Icons.storage_rounded,
    NavDestination.strategies: Icons.science_rounded,
    NavDestination.backtest: Icons.play_circle_fill_rounded,
    NavDestination.results: Icons.insights_rounded,
    NavDestination.research: Icons.travel_explore_rounded,
    NavDestination.knowledge: Icons.menu_book_rounded,
    NavDestination.models: Icons.memory_rounded,
    NavDestination.swarm: Icons.hub_rounded,
    NavDestination.activityLog: Icons.receipt_long_rounded,
  };

  static const _descriptions = {
    NavDestination.dashboard: 'Overview & quick start',
    NavDestination.data: 'Import, fetch & manage series',
    NavDestination.strategies: 'Build & pick strategies',
    NavDestination.backtest: 'Configure & run a test',
    NavDestination.results: 'Analyse performance',
    NavDestination.research: 'Sweep & rank strategies',
    NavDestination.knowledge: 'Book frameworks & screener',
    NavDestination.models: 'Download & manage models',
    NavDestination.swarm: 'Sync across devices',
    NavDestination.activityLog: 'Plain-English history',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final selected = ref.watch(navDestinationProvider);
    return ListView(
      padding: const EdgeInsets.all(Spacing.sm),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.xs, Spacing.xs, Spacing.xs, Spacing.xs),
          child: Text('WORKSPACE', style: Theme.of(context).textTheme.labelSmall),
        ),
        ...NavDestination.values.map((d) {
          final isSelected = d == selected;
          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                ref.read(navDestinationProvider.notifier).go(d);
                if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) Navigator.of(context).pop();
              },
              child: AnimatedContainer(
                duration: Motion.fast,
                curve: Motion.emphasized,
                padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: Spacing.sm),
                decoration: BoxDecoration(
                  color: isSelected ? c.accent.withValues(alpha: 0.12) : Colors.transparent,
                  borderRadius: Radii.rSm,
                  border: Border.all(color: isSelected ? c.accent.withValues(alpha: 0.35) : Colors.transparent),
                ),
                child: Row(
                  children: [
                    Icon(_icons[d], size: 19, color: isSelected ? c.accent : c.textSecondary),
                    const SizedBox(width: Spacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(d.label, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14)),
                          Text(_descriptions[d]!, style: Theme.of(context).textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    if (isSelected) Icon(Icons.chevron_right_rounded, size: 18, color: c.accent),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

// --- API keys tab ---------------------------------------------------------

class _ApiKeysPanel extends ConsumerWidget {
  const _ApiKeysPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keys = ref.watch(apiKeysProvider);
    return ListView(
      padding: const EdgeInsets.all(Spacing.sm),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.xs, Spacing.xs, Spacing.xs, Spacing.xxs),
          child: Text('BRING YOUR OWN KEYS', style: Theme.of(context).textTheme.labelSmall),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
          child: Text(
            'Yahoo Finance and Binance need no key. Add keys below only for extra providers. Keys stay in this device\u2019s secure store and are never uploaded.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: Spacing.sm),
        keys.when(
          loading: () => const Padding(padding: EdgeInsets.all(Spacing.md), child: LoadingView()),
          error: (e, _) => ErrorView(message: 'Could not read stored keys: $e', onRetry: () => ref.invalidate(apiKeysProvider)),
          data: (map) => Column(
            children: [
              const _FreeSourcesCard(),
              ...ApiProvider.keyed.map((p) => _ApiKeyRow(provider: p, savedKey: map[p])),
            ],
          ),
        ),
      ],
    );
  }
}

/// Explains the keyless free sources so users know they can start immediately.
class _FreeSourcesCard extends StatelessWidget {
  const _FreeSourcesCard();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GlassCard(
      margin: const EdgeInsets.only(bottom: Spacing.sm),
      padding: const EdgeInsets.all(Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_rounded, size: 16, color: c.success),
              const SizedBox(width: Spacing.xs),
              Expanded(child: Text('Free — no key needed', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14))),
            ],
          ),
          const SizedBox(height: 2),
          Text('Used automatically when you fetch a symbol.', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: Spacing.xs),
          ...ApiProvider.keyless.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_rounded, size: 14, color: c.success),
                    const SizedBox(width: 6),
                    Expanded(child: Text('${p.label} — ${p.blurb}', style: Theme.of(context).textTheme.bodySmall)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _ApiKeyRow extends ConsumerStatefulWidget {
  final ApiProvider provider;
  final String? savedKey;
  const _ApiKeyRow({required this.provider, this.savedKey});

  @override
  ConsumerState<_ApiKeyRow> createState() => _ApiKeyRowState();
}

class _ApiKeyRowState extends ConsumerState<_ApiKeyRow> {
  late final TextEditingController _controller;
  bool _obscure = true;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.savedKey ?? '');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _ApiKeyRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.savedKey != oldWidget.savedKey && (widget.savedKey ?? '') != _controller.text) {
      _controller.text = widget.savedKey ?? '';
    }
  }

  Future<void> _save() async {
    await ref.read(secretStoreProvider).write('apikey.${widget.provider.id}', _controller.text.trim());
    ref.invalidate(apiKeysProvider);
    if (mounted) {
      _snack(_controller.text.trim().isEmpty ? '${widget.provider.label} key cleared.' : '${widget.provider.label} key saved.');
    }
  }

  Future<void> _test() async {
    setState(() => _testing = true);
    try {
      final symbol = widget.provider == ApiProvider.alphaVantage ? 'IBM' : 'AAPL';
      await ref.read(marketDataClientProvider).fetch(
            provider: widget.provider,
            apiKey: _controller.text.trim(),
            symbol: symbol,
            interval: BarInterval.d1,
            outputSize: 100,
            customUrl: widget.provider == ApiProvider.custom ? _controller.text.trim() : null,
          );
      if (mounted) _snack('${widget.provider.label} connection OK.');
    } catch (e) {
      if (mounted) _snack('Test failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  void _snack(String message, {bool error = false}) {
    final c = context.colors;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? c.danger.withValues(alpha: 0.9) : c.surfaceAlt,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.provider;
    final c = context.colors;
    return GlassCard(
      margin: const EdgeInsets.only(bottom: Spacing.sm),
      padding: const EdgeInsets.all(Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(p.label, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14))),
              if (widget.savedKey != null && widget.savedKey!.isNotEmpty)
                Pill(label: 'Saved', color: c.success, icon: Icons.check_circle_rounded),
            ],
          ),
          const SizedBox(height: 2),
          Text(p.keyHelp, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: Spacing.xs),
          TextField(
            controller: _controller,
            obscureText: _obscure && p != ApiProvider.custom,
            decoration: InputDecoration(
              hintText: p == ApiProvider.custom ? 'https://example.com/ohlcv' : 'Paste key',
              prefixIcon: Icon(p == ApiProvider.custom ? Icons.link_rounded : Icons.key_rounded, size: 18),
              suffixIcon: p == ApiProvider.custom
                  ? null
                  : IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 18),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
            ),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: Spacing.xs),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: _save,
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 38)),
                  child: const Text('Save'),
                ),
              ),
              const SizedBox(width: Spacing.xs),
              Expanded(
                child: OutlinedButton(
                  onPressed: _testing ? null : _test,
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 38)),
                  child: _testing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Test'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// --- Configs tab ----------------------------------------------------------

class _ConfigsPanel extends ConsumerStatefulWidget {
  const _ConfigsPanel();

  @override
  ConsumerState<_ConfigsPanel> createState() => _ConfigsPanelState();
}

class _ConfigsPanelState extends ConsumerState<_ConfigsPanel> {
  final _capital = TextEditingController();
  final _fee = TextEditingController();
  final _slip = TextEditingController();
  final _rf = TextEditingController();
  final _bars = TextEditingController();
  final _currency = TextEditingController();
  final _assetBase = TextEditingController();
  bool _initialised = false;

  @override
  void dispose() {
    for (final c in [_capital, _fee, _slip, _rf, _bars, _currency, _assetBase]) {
      c.dispose();
    }
    super.dispose();
  }

  void _hydrate(AppSettings s) {
    if (_initialised) return;
    _capital.text = s.defaultConfig.initialCapital.toStringAsFixed(0);
    _fee.text = s.defaultConfig.feeBps.toStringAsFixed(1);
    _slip.text = s.defaultConfig.slippageBps.toStringAsFixed(1);
    _rf.text = s.defaultConfig.riskFreeRatePct.toStringAsFixed(1);
    _bars.text = s.defaultConfig.barsPerYear.toString();
    _currency.text = s.currencySymbol;
    _assetBase.text = s.assetPackBaseUrl;
    _initialised = true;
  }

  Future<void> _persist() async {
    await ref.read(settingsControllerProvider).update((s) => s.copyWith(
          defaultConfig: s.defaultConfig.copyWith(
            initialCapital: double.tryParse(_capital.text) ?? s.defaultConfig.initialCapital,
            feeBps: double.tryParse(_fee.text) ?? s.defaultConfig.feeBps,
            slippageBps: double.tryParse(_slip.text) ?? s.defaultConfig.slippageBps,
            riskFreeRatePct: double.tryParse(_rf.text) ?? s.defaultConfig.riskFreeRatePct,
            barsPerYear: int.tryParse(_bars.text) ?? s.defaultConfig.barsPerYear,
          ),
          currencySymbol: _currency.text.trim().isEmpty ? s.currencySymbol : _currency.text.trim(),
          assetPackBaseUrl: _assetBase.text.trim(),
        ));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Configuration saved.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final settingsAsync = ref.watch(settingsProvider);
    return settingsAsync.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: 'Could not load settings: $e', onRetry: () => ref.invalidate(settingsProvider)),
      data: (s) {
        _hydrate(s);
        return ListView(
          padding: const EdgeInsets.all(Spacing.sm),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Spacing.xs, Spacing.xs, Spacing.xs, Spacing.xs),
              child: Text('APPEARANCE', style: Theme.of(context).textTheme.labelSmall),
            ),
            _Segmented<ThemeMode>(
              current: s.themeMode,
              options: const {
                ThemeMode.system: 'System',
                ThemeMode.dark: 'Dark',
                ThemeMode.light: 'Light',
              },
              onSelect: (m) => ref.read(settingsControllerProvider).update((cur) => cur.copyWith(themeMode: m)),
            ),
            const SizedBox(height: Spacing.md),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
              child: Text('BACKTEST DEFAULTS', style: Theme.of(context).textTheme.labelSmall),
            ),
            const SizedBox(height: Spacing.xs),
            _num(context, 'Initial capital', _capital),
            _num(context, 'Fee (bps/side)', _fee),
            _num(context, 'Slippage (bps/side)', _slip),
            _num(context, 'Risk-free rate (%)', _rf),
            _num(context, 'Bars per year', _bars),
            _text(context, 'Currency symbol', _currency),
            const SizedBox(height: Spacing.sm),
            FilledButton.icon(
              onPressed: _persist,
              icon: const Icon(Icons.save_rounded, size: 18),
              label: const Text('Save configuration'),
            ),
            const SizedBox(height: Spacing.lg),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
              child: Text('OFFLINE ASSET PACKS', style: Theme.of(context).textTheme.labelSmall),
            ),
            const SizedBox(height: Spacing.xxs),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
              child: Text(
                'Point to the assets repository (separate repo) to download extra datasets at runtime.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: Spacing.xs),
            Text('MARKET REGION', style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: Spacing.xxs),
            DropdownButtonFormField<MarketRegion>(
              initialValue: ref.watch(marketRegionProvider),
              isExpanded: true,
              items: MarketRegion.values
                  .map((r) => DropdownMenuItem(value: r, child: Text('${r.label} · ${r.exchanges}')))
                  .toList(),
              onChanged: (v) async {
                if (v == null) return;
                await ref.read(settingsControllerProvider).update((s) => s.copyWith(marketRegion: v));
                ref.read(activityLogProvider).info('Market region set to ${v.label} — listings are now filtered to it.');
              },
            ),
            const SizedBox(height: Spacing.xxs),
            Text(
              'All listings, screens and charts are filtered to this region. A US ticker cannot appear in the India view.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10.5),
            ),
            const SizedBox(height: Spacing.md),
            _text(context, 'Assets base URL', _assetBase),
            const SizedBox(height: Spacing.xs),
            const _AssetPackControls(),
            const SizedBox(height: Spacing.lg),
            const _ProjectsSection(),
            const SizedBox(height: Spacing.md),
            TextButton.icon(
              onPressed: () => ref.read(settingsControllerProvider).reset().then((_) {
                    _initialised = false;
                    setState(() {});
                  }),
              icon: Icon(Icons.restart_alt_rounded, size: 18, color: c.textSecondary),
              label: Text('Reset to defaults', style: TextStyle(color: c.textSecondary)),
            ),
          ],
        );
      },
    );
  }

  Widget _num(BuildContext context, String label, TextEditingController controller) => Padding(
        padding: const EdgeInsets.only(bottom: Spacing.sm),
        child: FieldLabel(
          label: label,
          child: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 13),
          ),
        ),
      );

  Widget _text(BuildContext context, String label, TextEditingController controller) => Padding(
        padding: const EdgeInsets.only(bottom: Spacing.sm),
        child: FieldLabel(
          label: label,
          child: TextField(controller: controller, style: const TextStyle(fontSize: 13)),
        ),
      );
}

class _AssetPackControls extends ConsumerStatefulWidget {
  const _AssetPackControls();

  @override
  ConsumerState<_AssetPackControls> createState() => _AssetPackControlsState();
}

class _AssetPackControlsState extends ConsumerState<_AssetPackControls> {
  bool _syncing = false;

  Future<void> _sync() async {
    final manager = ref.read(assetPackManagerProvider);
    if (!manager.supported) {
      _snack('Asset packs are only available in the Android and Windows builds.', error: true);
      return;
    }
    setState(() => _syncing = true);
    try {
      final manifest = await ref.refresh(assetPackManifestProvider.future);
      if (manifest == null || manifest.packs.isEmpty) {
        _snack('No manifest found. Set a valid assets base URL.', error: true);
        return;
      }
      await manager.sync(manifest);
      ref.invalidate(installedPacksProvider);
      _snack('Asset packs are up to date.');
    } catch (e) {
      _snack('Sync failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  void _snack(String message, {bool error = false}) {
    final c = context.colors;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? c.danger.withValues(alpha: 0.9) : c.surfaceAlt,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final installed = ref.watch(installedPacksProvider);
    final manifest = ref.watch(assetPackManifestProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _syncing ? null : _sync,
          icon: _syncing
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.cloud_download_rounded, size: 18),
          label: const Text('Check & download packs'),
        ),
        const SizedBox(height: Spacing.xs),
        manifest.maybeWhen(
          data: (m) => Text(
            m == null ? 'No remote packs configured.' : '${m.packs.length} pack(s) available, manifest v${m.version}.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          orElse: () => const SizedBox.shrink(),
        ),
        installed.maybeWhen(
          data: (map) => map.isEmpty
              ? Padding(
                  padding: const EdgeInsets.only(top: Spacing.xxs),
                  child: Text('No packs installed yet.', style: Theme.of(context).textTheme.bodySmall),
                )
              : Padding(
                  padding: const EdgeInsets.only(top: Spacing.xs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: map.entries
                        .map((e) => Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  Icon(Icons.inventory_2_rounded, size: 14, color: c.success),
                                  const SizedBox(width: 6),
                                  Expanded(child: Text('${e.key}  v${e.value}', style: Theme.of(context).textTheme.bodySmall)),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                ),
          orElse: () => const SizedBox.shrink(),
        ),
      ],
    );
  }
}

/// Prompts for a project name. Returns null if cancelled.
Future<String?> _promptProjectName(BuildContext context, String title, String hint, String confirmLabel) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, controller.text.trim()), child: Text(confirmLabel)),
      ],
    ),
  ).whenComplete(controller.dispose);
}

/// Compact project switcher shown under the brand header.
class _WorkspaceSwitcher extends ConsumerWidget {
  const _WorkspaceSwitcher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final list = ref.watch(workspacesProvider).value ?? const <Workspace>[];
    final activeId = ref.watch(activeWorkspaceIdProvider).value;
    String activeName = 'Default project';
    for (final w in list) {
      if (w.id == activeId) activeName = w.name;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(Spacing.sm, 0, Spacing.sm, Spacing.xs),
      child: PopupMenuButton<String>(
        tooltip: 'Switch project',
        position: PopupMenuPosition.under,
        onSelected: (value) async {
          if (value == '__new__') {
            final name = await _promptProjectName(context, 'New project', 'e.g. Momentum research', 'Create');
            if (name != null && name.isNotEmpty) {
              await ref.read(workspaceControllerProvider).create(name);
            }
          } else {
            await ref.read(workspaceControllerProvider).switchTo(value);
          }
        },
        itemBuilder: (context) => [
          ...list.map((w) => PopupMenuItem(
                value: w.id,
                child: Row(
                  children: [
                    Icon(
                      w.id == activeId ? Icons.radio_button_checked_rounded : Icons.radio_button_unchecked_rounded,
                      size: 15,
                      color: w.id == activeId ? c.accent : c.textMuted,
                    ),
                    const SizedBox(width: Spacing.xs),
                    Expanded(child: Text(w.name, overflow: TextOverflow.ellipsis)),
                  ],
                ),
              )),
          const PopupMenuDivider(),
          const PopupMenuItem(
            value: '__new__',
            child: Row(children: [Icon(Icons.add_rounded, size: 16), SizedBox(width: Spacing.xs), Text('New project')]),
          ),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: Spacing.xs),
          decoration: BoxDecoration(color: c.glassFill, borderRadius: Radii.rSm, border: Border.all(color: c.border)),
          child: Row(
            children: [
              Icon(Icons.workspaces_rounded, size: 15, color: c.accent),
              const SizedBox(width: Spacing.xs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PROJECT', style: Theme.of(context).textTheme.labelSmall),
                    Text(activeName, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: c.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Icon(Icons.unfold_more_rounded, size: 15, color: c.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Project management (create / rename / clear / delete) shown in the Configs tab.
class _ProjectsSection extends ConsumerWidget {
  const _ProjectsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final list = ref.watch(workspacesProvider).value ?? const <Workspace>[];
    final activeId = ref.watch(activeWorkspaceIdProvider).value;
    final controller = ref.read(workspaceControllerProvider);

    Future<void> confirmThen(String title, String message, Future<void> Function() action) async {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
          ],
        ),
      );
      if (ok == true) await action();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
          child: Text('PROJECTS', style: Theme.of(context).textTheme.labelSmall),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.xs),
          child: Text(
            'Each project keeps its own datasets, strategies and results. Nothing is shared between projects.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: Spacing.xs),
        ...list.map((w) {
          final isActive = w.id == activeId;
          return GlassCard(
            margin: const EdgeInsets.only(bottom: Spacing.xs),
            padding: const EdgeInsets.all(Spacing.sm),
            border: isActive ? Border.all(color: c.accent, width: 1.2) : null,
            child: Row(
              children: [
                Icon(Icons.folder_rounded, size: 16, color: isActive ? c.accent : c.textSecondary),
                const SizedBox(width: Spacing.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(w.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                      if (isActive) Text('Active', style: Theme.of(context).textTheme.labelSmall?.copyWith(color: c.accent)),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Project actions',
                  icon: Icon(Icons.more_vert_rounded, size: 18, color: c.textMuted),
                  onSelected: (action) async {
                    switch (action) {
                      case 'switch':
                        await controller.switchTo(w.id);
                      case 'rename':
                        final name = await _promptProjectName(context, 'Rename project', w.name, 'Rename');
                        if (name != null && name.isNotEmpty) await controller.rename(w.id, name);
                      case 'clear':
                        await confirmThen('Clear project data?', 'All datasets, custom strategies and results in “${w.name}” will be deleted.', () => controller.clear(w.id));
                      case 'delete':
                        await confirmThen('Delete project?', '“${w.name}” and everything in it will be permanently removed.', () => controller.delete(w.id));
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'switch', child: Text('Switch to')),
                    PopupMenuItem(value: 'rename', child: Text('Rename')),
                    PopupMenuItem(value: 'clear', child: Text('Clear data')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
                  ],
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: Spacing.xs),
        OutlinedButton.icon(
          onPressed: () async {
            final name = await _promptProjectName(context, 'New project', 'e.g. Momentum research', 'Create');
            if (name != null && name.isNotEmpty) {
              await controller.create(name);
            }
          },
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('New project'),
        ),
      ],
    );
  }
}

class _Segmented<T> extends StatelessWidget {
  final T current;
  final Map<T, String> options;
  final ValueChanged<T> onSelect;

  const _Segmented({required this.current, required this.options, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: c.glassFill, borderRadius: Radii.rSm, border: Border.all(color: c.border)),
      child: Row(
        children: options.entries.map((e) {
          final selected = e.key == current;
          return Expanded(
            child: GestureDetector(
              onTap: () => onSelect(e.key),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: Motion.fast,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? c.accent.withValues(alpha: 0.16) : Colors.transparent,
                  borderRadius: Radii.rXs,
                ),
                child: Text(
                  e.value,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: selected ? c.accent : c.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SidebarFooter extends StatelessWidget {
  const _SidebarFooter();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(Spacing.sm),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: c.border))),
      child: Row(
        children: [
          Icon(Icons.offline_bolt_rounded, size: 14, color: c.success),
          const SizedBox(width: 6),
          Expanded(child: Text('Offline-first', style: Theme.of(context).textTheme.bodySmall)),
          Text('v${AppInfo.version}', style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }
}
