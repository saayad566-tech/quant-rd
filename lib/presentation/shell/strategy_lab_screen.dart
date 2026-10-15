/// Strategy Lab: browse built-in strategies, inspect their rules, and build,
/// edit and save custom strategies.
library;

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/export/export_service.dart';
import '../widgets/export_helper.dart';
import '../../core/formatters.dart';
import '../../core/ids.dart';
import '../../core/constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/models/strategy_spec.dart';
import '../../domain/providers/core_providers.dart';
import '../../domain/providers/feature_providers.dart';
import '../widgets/common.dart';

class StrategyLabScreen extends ConsumerStatefulWidget {
  const StrategyLabScreen({super.key});

  @override
  ConsumerState<StrategyLabScreen> createState() => _StrategyLabScreenState();
}

class _StrategyLabScreenState extends ConsumerState<StrategyLabScreen> {
  @override
  Widget build(BuildContext context) {
    final strategies = ref.watch(strategiesProvider);
    final selectedId = ref.watch(selectedStrategyIdProvider);
    final c = context.colors;

    return Padding(
      padding: const EdgeInsets.all(Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Strategy Lab',
            subtitle: 'Start from a built-in strategy or compose your own rule set.',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  onPressed: _importStrategy,
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Install / Import'),
                ),
                const SizedBox(width: Spacing.sm),
                FilledButton.icon(
                  onPressed: () => _openBuilder(null),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('New strategy'),
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.md),
          Expanded(
            child: strategies.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(message: 'Could not load strategies: $e', onRetry: () => ref.invalidate(strategiesProvider)),
              data: (list) {
                StrategySpec? findSelected() {
                  for (final s in list) {
                    if (s.id == selectedId) return s;
                  }
                  return null;
                }

                final selected = findSelected();
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (context, i) {
                          final s = list[i];
                          final isSel = s.id == selectedId;
                          return GlassCard(
                            margin: const EdgeInsets.only(bottom: Spacing.sm),
                            onTap: () => ref.read(selectedStrategyIdProvider.notifier).select(s.id),
                            border: isSel ? Border.all(color: c.accent, width: 1.4) : null,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(child: Text(s.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14))),
                                    if (!s.enabled) ...[
                                      Pill(label: 'Disabled', color: c.textMuted),
                                      const SizedBox(width: Spacing.xxs),
                                    ],
                                    if (s.isBuiltIn) Pill(label: 'Built-in', color: c.info) else Pill(label: 'Custom', color: c.accentAlt),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(s.description, style: Theme.of(context).textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: Spacing.xxs),
                                Text(
                                  '${s.entry.length} entry \u00b7 ${s.exit.length} exit \u00b7 ${s.sizing.label}',
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: Spacing.md),
                    Expanded(
                      flex: 3,
                      child: selected == null
                          ? GlassCard(
                              child: SizedBox(
                                height: 320,
                                child: EmptyState(
                                  icon: Icons.science_rounded,
                                  title: 'No strategy selected',
                                  message: 'Pick a strategy on the left to see its rules, or create a new one.',
                                ),
                              ),
                            )
                          : _StrategyDetail(
                              strategy: selected,
                              onEdit: () => _openBuilder(selected),
                              onDelete: () => _delete(selected),
                              onDuplicate: () => _duplicate(selected),
                              onToggleEnabled: () => _toggleEnabled(selected),
                              onExport: () => _exportStrategy(selected),
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openBuilder(StrategySpec? existing) async {
    final result = await showDialog<StrategySpec>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _StrategyBuilderDialog(existing: existing),
    );
    if (result == null) return;
    final wsId = ref.read(activeWorkspaceIdProvider).value ?? StorageKeys.defaultWorkspaceId;
    final scoped = result.workspaceId.isEmpty ? result.copyWith(workspaceId: wsId) : result;
    await ref.read(strategyRepositoryProvider).save(scoped);
    ref.invalidate(strategiesProvider);
    ref.read(selectedStrategyIdProvider.notifier).select(scoped.id);
    ref.read(activityLogProvider).success('Saved strategy “${scoped.name}”.');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Saved “${scoped.name}”.')));
    }
  }

  Future<void> _duplicate(StrategySpec s) async {
    final wsId = ref.read(activeWorkspaceIdProvider).value ?? StorageKeys.defaultWorkspaceId;
    final copy = StrategySpec(
      id: Ids.newId('strat'),
      workspaceId: wsId,
      name: '${s.name} (copy)',
      description: s.description,
      entry: s.entry,
      exit: s.exit,
      stopLossPct: s.stopLossPct,
      takeProfitPct: s.takeProfitPct,
      sizing: s.sizing,
      sizingValue: s.sizingValue,
      allowShort: s.allowShort,
      updatedAt: DateTime.now(),
    );
    await ref.read(strategyRepositoryProvider).save(copy);
    ref.invalidate(strategiesProvider);
    ref.read(selectedStrategyIdProvider.notifier).select(copy.id);
    ref.read(activityLogProvider).success('Duplicated “${s.name}” as “${copy.name}”.');
  }

  Future<void> _delete(StrategySpec s) async {
    if (s.isBuiltIn) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Built-in strategies cannot be deleted.')));
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete strategy?'),
        content: Text('“${s.name}” will be removed permanently.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    final wsId = ref.read(activeWorkspaceIdProvider).value ?? StorageKeys.defaultWorkspaceId;
    await ref.read(strategyRepositoryProvider).delete(wsId, s.id);
    ref.invalidate(strategiesProvider);
    ref.read(selectedStrategyIdProvider.notifier).clear();
    ref.read(activityLogProvider).warn('Deleted strategy “${s.name}”.');
  }

  Future<void> _toggleEnabled(StrategySpec s) async {
    final updated = s.copyWith(enabled: !s.enabled, updatedAt: DateTime.now());
    await ref.read(strategyRepositoryProvider).save(updated);
    ref.invalidate(strategiesProvider);
    ref.read(activityLogProvider).info('${updated.enabled ? 'Enabled' : 'Disabled'} strategy “${s.name}”.');
  }

  Future<void> _exportStrategy(StrategySpec s) async {
    final json = const JsonEncoder.withIndent('  ').convert(s.toMap());
    if (!mounted) return;
    await exportText(
      context,
      fileName: 'strategy_${ExportService.safeName(s.name)}.json',
      content: json,
      log: ref.read(activityLogProvider),
    );
  }

  Future<void> _importStrategy() async {
    final imported = await showDialog<StrategySpec>(
      context: context,
      builder: (ctx) => const _StrategyImportDialog(),
    );
    if (imported == null) return;
    final wsId = ref.read(activeWorkspaceIdProvider).value ?? StorageKeys.defaultWorkspaceId;
    // A fresh id so importing never overwrites an existing strategy.
    final fresh = StrategySpec(
      id: Ids.newId('strat'),
      workspaceId: wsId,
      name: imported.name,
      description: imported.description,
      entry: imported.entry,
      exit: imported.exit,
      stopLossPct: imported.stopLossPct,
      takeProfitPct: imported.takeProfitPct,
      sizing: imported.sizing,
      sizingValue: imported.sizingValue,
      allowShort: imported.allowShort,
      enabled: imported.enabled,
      updatedAt: DateTime.now(),
    );
    await ref.read(strategyRepositoryProvider).save(fresh);
    ref.invalidate(strategiesProvider);
    ref.read(selectedStrategyIdProvider.notifier).select(fresh.id);
    ref.read(activityLogProvider).success('Installed strategy “${fresh.name}”.');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Installed “${fresh.name}”.')));
    }
  }
}

/// Paste-or-open-file importer for strategies exported from Quant RD.
class _StrategyImportDialog extends StatefulWidget {
  const _StrategyImportDialog();

  @override
  State<_StrategyImportDialog> createState() => _StrategyImportDialogState();
}

class _StrategyImportDialogState extends State<_StrategyImportDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['json', 'txt']);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _controller.text = utf8.decode(bytes, allowMalformed: true);
      _error = null;
    });
  }

  void _confirm() {
    final spec = _parse(_controller.text);
    if (spec == null) {
      setState(() => _error = 'That JSON could not be read as a strategy. Export a strategy first to see the expected shape.');
      return;
    }
    Navigator.pop(context, spec);
  }

  StrategySpec? _parse(String text) {
    if (text.trim().isEmpty) return null;
    try {
      final decoded = jsonDecode(text);
      if (decoded is! Map) return null;
      final m = decoded.cast<String, dynamic>();
      return StrategySpec.fromMap({
        'id': m['id'] ?? 'imported',
        'name': m['name'] ?? 'Imported strategy',
        'description': m['description'] ?? '',
        'is_built_in': 0,
        'entry': m['entry'] ?? const [],
        'exit': m['exit'] ?? const [],
        'stop_loss_pct': m['stop_loss_pct'] ?? 0,
        'take_profit_pct': m['take_profit_pct'] ?? 0,
        'sizing': m['sizing'] ?? 'percentOfEquity',
        'sizing_value': m['sizing_value'] ?? 100,
        'allow_short': m['allow_short'] ?? 0,
        'enabled': m['enabled'] ?? 1,
        'updated_at': m['updated_at'] ?? DateTime.now().millisecondsSinceEpoch,
      });
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AlertDialog(
      title: const Text('Install / import a strategy'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Paste a strategy exported from Quant RD, or open a .json file.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: Spacing.sm),
            TextField(
              controller: _controller,
              maxLines: 10,
              minLines: 6,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              decoration: const InputDecoration(hintText: '{ "name": "...", "entry": [ ... ], "exit": [ ... ] }'),
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
            ),
            if (_error != null) ...[
              const SizedBox(height: Spacing.xs),
              Row(
                children: [
                  Icon(Icons.error_outline_rounded, size: 15, color: c.danger),
                  const SizedBox(width: 6),
                  Expanded(child: Text(_error!, style: TextStyle(color: c.danger, fontSize: 12))),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton.icon(onPressed: _pickFile, icon: const Icon(Icons.folder_open_rounded, size: 18), label: const Text('Open file')),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: _confirm, child: const Text('Install')),
      ],
    );
  }
}

class _StrategyDetail extends ConsumerWidget {
  final StrategySpec strategy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onDuplicate;
  final VoidCallback onToggleEnabled;
  final VoidCallback onExport;

  const _StrategyDetail({
    required this.strategy,
    required this.onEdit,
    required this.onDelete,
    required this.onDuplicate,
    required this.onToggleEnabled,
    required this.onExport,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return GlassCard(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(strategy.name, style: Theme.of(context).textTheme.headlineMedium)),
                if (strategy.isBuiltIn) Pill(label: 'Built-in', color: c.info) else Pill(label: 'Custom', color: c.accentAlt),
              ],
            ),
            const SizedBox(height: Spacing.xxs),
            Text(strategy.description, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: Spacing.md),
            _RuleGroup(title: 'Entry — ALL must hold', conditions: strategy.entry, emptyLabel: 'Always enters on the first bar.', accent: c.success),
            const SizedBox(height: Spacing.md),
            _RuleGroup(title: 'Exit — ANY closes the position', conditions: strategy.exit, emptyLabel: 'No exit rule (holds until the end).', accent: c.danger),
            const SizedBox(height: Spacing.md),
            Wrap(
              spacing: Spacing.sm,
              runSpacing: Spacing.xs,
              children: [
                Pill(label: 'Sizing: ${strategy.sizing.label}', icon: Icons.scale_rounded),
                if (strategy.sizing != PositionSizing.allIn) Pill(label: '${Fmt.decimal(strategy.sizingValue, 0)}${strategy.sizing == PositionSizing.percentOfEquity ? '%' : ''}'),
                if (strategy.stopLossPct > 0) Pill(label: 'Stop-loss ${strategy.stopLossPct}%', color: c.danger),
                if (strategy.takeProfitPct > 0) Pill(label: 'Take-profit ${strategy.takeProfitPct}%', color: c.success),
                if (strategy.allowShort) Pill(label: 'Long & short', color: c.warning),
              ],
            ),
            const SizedBox(height: Spacing.sm),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: strategy.enabled,
              onChanged: (_) => onToggleEnabled(),
              title: const Text('Active'),
              subtitle: Text(
                strategy.enabled ? 'Enabled — available in the backtest picker.' : 'Disabled — kept but excluded from active use.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: Spacing.sm),
            Row(
              children: [
                FilledButton.icon(onPressed: onEdit, icon: const Icon(Icons.edit_rounded, size: 18), label: Text(strategy.isBuiltIn ? 'Customise a copy' : 'Edit')),
                const SizedBox(width: Spacing.sm),
                OutlinedButton.icon(onPressed: onDuplicate, icon: const Icon(Icons.copy_rounded, size: 18), label: const Text('Duplicate')),
                const SizedBox(width: Spacing.sm),
                OutlinedButton.icon(onPressed: onExport, icon: const Icon(Icons.upload_rounded, size: 18), label: const Text('Export')),
                const Spacer(),
                if (!strategy.isBuiltIn)
                  TextButton.icon(
                    onPressed: onDelete,
                    icon: Icon(Icons.delete_outline_rounded, size: 18, color: c.danger),
                    label: Text('Delete', style: TextStyle(color: c.danger)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RuleGroup extends StatelessWidget {
  final String title;
  final List<Condition> conditions;
  final String emptyLabel;
  final Color accent;

  const _RuleGroup({required this.title, required this.conditions, required this.emptyLabel, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: accent)),
        const SizedBox(height: Spacing.xs),
        if (conditions.isEmpty)
          Text(emptyLabel, style: Theme.of(context).textTheme.bodySmall)
        else
          ...conditions.map((c) => Container(
                margin: const EdgeInsets.only(bottom: 6),
                padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: 8),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.08),
                  borderRadius: Radii.rXs,
                  border: Border.all(color: accent.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.rule_rounded, size: 15, color: accent),
                    const SizedBox(width: Spacing.xs),
                    Expanded(child: Text(c.label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.colors.textPrimary))),
                  ],
                ),
              )),
      ],
    );
  }
}

// --- Strategy builder -----------------------------------------------------

class _StrategyBuilderDialog extends StatefulWidget {
  final StrategySpec? existing;
  const _StrategyBuilderDialog({this.existing});

  @override
  State<_StrategyBuilderDialog> createState() => _StrategyBuilderDialogState();
}

class _StrategyBuilderDialogState extends State<_StrategyBuilderDialog> {
  late final TextEditingController _name;
  late final TextEditingController _desc;
  late final TextEditingController _sl;
  late final TextEditingController _tp;
  late final TextEditingController _sizingValue;
  late List<_EditableCondition> _entry;
  late List<_EditableCondition> _exit;
  PositionSizing _sizing = PositionSizing.percentOfEquity;
  bool _allowShort = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e == null ? 'My strategy' : '${e.name} (custom)');
    _desc = TextEditingController(text: e?.description ?? '');
    _sl = TextEditingController(text: (e?.stopLossPct ?? 0).toString());
    _tp = TextEditingController(text: (e?.takeProfitPct ?? 0).toString());
    _sizing = e?.sizing ?? PositionSizing.percentOfEquity;
    _sizingValue = TextEditingController(text: (e?.sizingValue ?? 100).toString());
    _allowShort = e?.allowShort ?? false;
    _entry = (e?.entry ?? []).map(_EditableCondition.fromCondition).toList();
    _exit = (e?.exit ?? []).map(_EditableCondition.fromCondition).toList();
    if (_entry.isEmpty) {
      _entry = [_EditableCondition.smaCross()];
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _desc, _sl, _tp, _sizingValue]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Dialog(
      insetPadding: const EdgeInsets.all(Spacing.lg),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 760),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(Spacing.md),
              child: Row(
                children: [
                  Icon(Icons.tune_rounded, color: c.accent),
                  const SizedBox(width: Spacing.sm),
                  Text(widget.existing == null ? 'New strategy' : 'Edit strategy', style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(Spacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FieldLabel(label: 'Name', child: TextField(controller: _name)),
                    const SizedBox(height: Spacing.sm),
                    FieldLabel(label: 'Description', child: TextField(controller: _desc)),
                    const SizedBox(height: Spacing.md),
                    _conditionSection('Entry conditions (all must hold)', _entry, true),
                    const SizedBox(height: Spacing.md),
                    _conditionSection('Exit conditions (any closes)', _exit, false),
                    const SizedBox(height: Spacing.md),
                    Row(
                      children: [
                        Expanded(child: FieldLabel(label: 'Stop-loss %', child: TextField(controller: _sl, keyboardType: const TextInputType.numberWithOptions(decimal: true)))),
                        const SizedBox(width: Spacing.sm),
                        Expanded(child: FieldLabel(label: 'Take-profit %', child: TextField(controller: _tp, keyboardType: const TextInputType.numberWithOptions(decimal: true)))),
                      ],
                    ),
                    const SizedBox(height: Spacing.sm),
                    Row(
                      children: [
                        Expanded(
                          child: FieldLabel(
                            label: 'Position sizing',
                            child: DropdownButtonFormField<PositionSizing>(
                              initialValue: _sizing,
                              items: PositionSizing.values.map((e) => DropdownMenuItem(value: e, child: Text(e.label))).toList(),
                              onChanged: (v) => setState(() => _sizing = v ?? PositionSizing.percentOfEquity),
                            ),
                          ),
                        ),
                        const SizedBox(width: Spacing.sm),
                        Expanded(
                          child: FieldLabel(
                            label: _sizing == PositionSizing.percentOfEquity ? 'Percent of equity' : 'Amount',
                            child: TextField(
                              controller: _sizingValue,
                              enabled: _sizing != PositionSizing.allIn,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Spacing.sm),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _allowShort,
                      onChanged: (v) => setState(() => _allowShort = v),
                      title: const Text('Allow short trades'),
                      subtitle: const Text('Interprets exit signals as shorts when flat (symmetric strategy).'),
                    ),
                  ],
                ),
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(Spacing.md),
              child: Row(
                children: [
                  const Spacer(),
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  const SizedBox(width: Spacing.sm),
                  FilledButton.icon(onPressed: _save, icon: const Icon(Icons.check_rounded, size: 18), label: const Text('Save strategy')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _conditionSection(String title, List<_EditableCondition> list, bool isEntry) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
            TextButton.icon(
              onPressed: () => setState(() => list.add(_EditableCondition.defaultFor(isEntry))),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: Spacing.xs),
        if (list.isEmpty)
          Text('No conditions.', style: Theme.of(context).textTheme.bodySmall)
        else
          ...List.generate(list.length, (i) => _ConditionEditor(
                condition: list[i],
                onChanged: () => setState(() {}),
                onRemove: () => setState(() => list.removeAt(i)),
              )),
      ],
    );
  }

  void _save() {
    final entry = _entry.map((e) => e.toCondition()).toList();
    final exit = _exit.map((e) => e.toCondition()).toList();
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Give your strategy a name.')));
      return;
    }
    final spec = StrategySpec(
      id: widget.existing?.id ?? Ids.newId('strat'),
      name: _name.text.trim(),
      description: _desc.text.trim(),
      entry: entry,
      exit: exit,
      stopLossPct: double.tryParse(_sl.text) ?? 0,
      takeProfitPct: double.tryParse(_tp.text) ?? 0,
      sizing: _sizing,
      sizingValue: double.tryParse(_sizingValue.text) ?? 100,
      allowShort: _allowShort,
      updatedAt: DateTime.now(),
    );
    Navigator.pop(context, spec);
  }
}

/// Mutable working copy of a [Condition] for the builder UI.
class _EditableCondition {
  IndicatorType leftType;
  int leftPeriod;
  int leftPeriod2;
  int leftPeriod3;
  double leftMultiplier;
  bool leftIsConstant;
  double leftConstant;
  ComparisonOp op;
  bool rightIsConstant;
  double rightConstant;
  IndicatorType rightType;
  int rightPeriod;
  int rightPeriod2;
  int rightPeriod3;
  double rightMultiplier;

  _EditableCondition({
    required this.leftType,
    required this.leftPeriod,
    required this.leftPeriod2,
    required this.leftPeriod3,
    required this.leftMultiplier,
    required this.leftIsConstant,
    required this.leftConstant,
    required this.op,
    required this.rightIsConstant,
    required this.rightConstant,
    required this.rightType,
    required this.rightPeriod,
    required this.rightPeriod2,
    required this.rightPeriod3,
    required this.rightMultiplier,
  });

  factory _EditableCondition.smaCross() => _EditableCondition(
        leftType: IndicatorType.sma,
        leftPeriod: 50,
        leftPeriod2: 26,
        leftPeriod3: 9,
        leftMultiplier: 2.0,
        leftIsConstant: false,
        leftConstant: 0,
        op: ComparisonOp.crossesAbove,
        rightIsConstant: false,
        rightConstant: 0,
        rightType: IndicatorType.sma,
        rightPeriod: 200,
        rightPeriod2: 26,
        rightPeriod3: 9,
        rightMultiplier: 2.0,
      );

  factory _EditableCondition.defaultFor(bool isEntry) => _EditableCondition(
        leftType: IndicatorType.rsi,
        leftPeriod: 14,
        leftPeriod2: 26,
        leftPeriod3: 9,
        leftMultiplier: 2.0,
        leftIsConstant: false,
        leftConstant: 0,
        op: isEntry ? ComparisonOp.lessThan : ComparisonOp.greaterThan,
        rightIsConstant: true,
        rightConstant: isEntry ? 30 : 70,
        rightType: IndicatorType.close,
        rightPeriod: 14,
        rightPeriod2: 26,
        rightPeriod3: 9,
        rightMultiplier: 2.0,
      );

  factory _EditableCondition.fromCondition(Condition c) {
    final l = c.left;
    final r = c.right;
    return _EditableCondition(
      leftType: l.isConstant ? IndicatorType.close : l.ref!.type,
      leftPeriod: l.isConstant ? 14 : l.ref!.period,
      leftPeriod2: l.isConstant ? 26 : l.ref!.period2,
      leftPeriod3: l.isConstant ? 9 : l.ref!.period3,
      leftMultiplier: l.isConstant ? 2.0 : l.ref!.multiplier,
      leftIsConstant: l.isConstant,
      leftConstant: l.isConstant ? l.constant : 0,
      op: c.op,
      rightIsConstant: r.isConstant,
      rightConstant: r.isConstant ? r.constant : 0,
      rightType: r.isConstant ? IndicatorType.close : r.ref!.type,
      rightPeriod: r.isConstant ? 14 : r.ref!.period,
      rightPeriod2: r.isConstant ? 26 : r.ref!.period2,
      rightPeriod3: r.isConstant ? 9 : r.ref!.period3,
      rightMultiplier: r.isConstant ? 2.0 : r.ref!.multiplier,
    );
  }

  Operand _left() => leftIsConstant
      ? Operand.constant(leftConstant)
      : Operand.series(SeriesRef(leftType, period: leftPeriod, period2: leftPeriod2, period3: leftPeriod3, multiplier: leftMultiplier));

  Operand _right() => rightIsConstant
      ? Operand.constant(rightConstant)
      : Operand.series(SeriesRef(rightType, period: rightPeriod, period2: rightPeriod2, period3: rightPeriod3, multiplier: rightMultiplier));

  Condition toCondition() => Condition(left: _left(), op: op, right: _right());
}

class _ConditionEditor extends StatelessWidget {
  final _EditableCondition condition;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  const _ConditionEditor({required this.condition, required this.onChanged, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.xs),
      padding: const EdgeInsets.all(Spacing.sm),
      decoration: BoxDecoration(color: c.glassFill, borderRadius: Radii.rSm, border: Border.all(color: c.border)),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _operandEditor(context, isLeft: true)),
              const SizedBox(width: Spacing.xs),
              SizedBox(
                width: 150,
                child: DropdownButtonFormField<ComparisonOp>(
                  initialValue: condition.op,
                  isExpanded: true,
                  items: ComparisonOp.values.map((e) => DropdownMenuItem(value: e, child: Text(e.label, style: const TextStyle(fontSize: 12)))).toList(),
                  onChanged: (v) {
                    condition.op = v ?? ComparisonOp.greaterThan;
                    onChanged();
                  },
                ),
              ),
              IconButton(onPressed: onRemove, icon: Icon(Icons.remove_circle_outline_rounded, size: 18, color: c.danger)),
            ],
          ),
          const SizedBox(height: Spacing.xxs),
          Row(
            children: [
              Expanded(child: _operandEditor(context, isLeft: false)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _operandEditor(BuildContext context, {required bool isLeft}) {
    final type = isLeft ? condition.leftType : condition.rightType;
    final isConst = isLeft ? condition.leftIsConstant : condition.rightIsConstant;
    final period = isLeft ? condition.leftPeriod : condition.rightPeriod;
    final period2 = isLeft ? condition.leftPeriod2 : condition.rightPeriod2;
    final period3 = isLeft ? condition.leftPeriod3 : condition.rightPeriod3;
    final mult = isLeft ? condition.leftMultiplier : condition.rightMultiplier;
    final constant = isLeft ? condition.leftConstant : condition.rightConstant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<IndicatorType>(
                initialValue: isConst ? IndicatorType.close : type,
                isExpanded: true,
                items: IndicatorType.values.map((e) => DropdownMenuItem(value: e, child: Text(e.label, style: const TextStyle(fontSize: 12)))).toList(),
                onChanged: isConst
                    ? null
                    : (v) {
                        if (isLeft) {
                          condition.leftType = v ?? IndicatorType.close;
                        } else {
                          condition.rightType = v ?? IndicatorType.close;
                        }
                        onChanged();
                      },
              ),
            ),
            const SizedBox(width: Spacing.xs),
            SizedBox(
              width: 96,
              child: TextFormField(
                initialValue: constant.toString(),
                enabled: isConst,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(hintText: 'value'),
                style: const TextStyle(fontSize: 12),
                onChanged: (v) {
                  final d = double.tryParse(v) ?? 0;
                  if (isLeft) {
                    condition.leftConstant = d;
                  } else {
                    condition.rightConstant = d;
                  }
                },
              ),
            ),
            IconButton(
              tooltip: isConst ? 'Use an indicator' : 'Use a fixed value',
              onPressed: () {
                if (isLeft) {
                  condition.leftIsConstant = !condition.leftIsConstant;
                } else {
                  condition.rightIsConstant = !condition.rightIsConstant;
                }
                onChanged();
              },
              icon: Icon(isConst ? Icons.functions_rounded : Icons.numbers_rounded, size: 18),
            ),
          ],
        ),
        if (!isConst && type.paramCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: Spacing.xxs),
            child: Row(
              children: [
                _smallNum('period', period, (v) {
                  if (isLeft) {
                    condition.leftPeriod = v;
                  } else {
                    condition.rightPeriod = v;
                  }
                }),
                if (type.paramCount > 1) ...[
                  const SizedBox(width: Spacing.xs),
                  _smallNum('slow', period2, (v) {
                    if (isLeft) {
                      condition.leftPeriod2 = v;
                    } else {
                      condition.rightPeriod2 = v;
                    }
                  }),
                  const SizedBox(width: Spacing.xs),
                  _smallNum('mult', mult, (_) {}, isDouble: true, onDouble: (v) {
                    if (isLeft) {
                      condition.leftMultiplier = v;
                    } else {
                      condition.rightMultiplier = v;
                    }
                  }),
                ],
                if (type.paramCount > 2) ...[
                  const SizedBox(width: Spacing.xs),
                  _smallNum('signal', period3, (v) {
                    if (isLeft) {
                      condition.leftPeriod3 = v;
                    } else {
                      condition.rightPeriod3 = v;
                    }
                  }),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _smallNum(String label, num value, ValueChanged<int> onInt, {bool isDouble = false, ValueChanged<double>? onDouble}) {
    return SizedBox(
      width: 86,
      child: TextFormField(
        initialValue: value.toString(),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(hintText: label),
        style: const TextStyle(fontSize: 12),
        onChanged: (v) {
          if (isDouble) {
            onDouble?.call(double.tryParse(v) ?? 0);
          } else {
            onInt(int.tryParse(v) ?? 1);
          }
        },
      ),
    );
  }
}
