/// Activity Log screen: a plain-English history of everything the app did.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/activity_log.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../domain/providers/core_providers.dart';
import '../../domain/providers/feature_providers.dart';
import '../widgets/common.dart';
import '../widgets/export_helper.dart';

class ActivityLogScreen extends ConsumerWidget {
  const ActivityLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(activityLogStreamProvider);
    final c = context.colors;

    return Padding(
      padding: const EdgeInsets.all(Spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Activity Log',
            subtitle: 'A plain-English record of imports, fetches, backtests and errors.',
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    final log = ref.read(activityLogProvider);
                    unawaited(exportText(context, fileName: 'quant-rd-activity-log.txt', content: log.exportText(), log: log));
                  },
                  icon: const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Export'),
                ),
                const SizedBox(width: Spacing.xs),
                TextButton.icon(
                  onPressed: () => ref.read(activityLogProvider).clear(),
                  icon: Icon(Icons.delete_sweep_rounded, size: 18, color: c.textSecondary),
                  label: Text('Clear', style: TextStyle(color: c.textSecondary)),
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.md),
          Expanded(
            child: entries.when(
              loading: () => const LoadingView(),
              error: (e, _) => ErrorView(message: 'Could not read the log: $e'),
              data: (list) {
                if (list.isEmpty) {
                  return const GlassCard(
                    child: EmptyState(
                      icon: Icons.receipt_long_rounded,
                      title: 'Nothing logged yet',
                      message: 'Import data, fetch from a provider or run a backtest and it will appear here.',
                    ),
                  );
                }
                return GlassCard(
                  padding: const EdgeInsets.symmetric(vertical: Spacing.xs),
                  child: ListView.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, _) => Divider(height: 1, color: c.border),
                    itemBuilder: (context, i) => _LogRow(entry: list[i]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  final LogEntry entry;
  const _LogRow({required this.entry});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (icon, color) = switch (entry.level) {
      LogLevel.success => (Icons.check_circle_rounded, c.success),
      LogLevel.warning => (Icons.warning_amber_rounded, c.warning),
      LogLevel.error => (Icons.error_outline_rounded, c.danger),
      LogLevel.info => (Icons.info_outline_rounded, c.info),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm, vertical: Spacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(child: Text(entry.message, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: c.textPrimary))),
          const SizedBox(width: Spacing.sm),
          Text(_time(entry.time), style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }

  String _time(DateTime t) {
    final local = t.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
  }
}
