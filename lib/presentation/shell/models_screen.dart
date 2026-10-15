/// Models screen: the local model download and storage manager.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../data/models/local_model.dart';
import '../../domain/providers/advanced_providers.dart';
import '../../domain/providers/core_providers.dart';
import '../widgets/common.dart';

class ModelsScreen extends ConsumerStatefulWidget {
  const ModelsScreen({super.key});

  @override
  ConsumerState<ModelsScreen> createState() => _ModelsScreenState();
}

class _ModelsScreenState extends ConsumerState<ModelsScreen> {
  final _progress = <String, double>{};
  String? _status;
  bool _error = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hub = ref.watch(modelHubProvider);
    final manifest = ref.watch(modelManifestProvider);
    final installed = ref.watch(installedModelsProvider);

    return ListView(
      padding: const EdgeInsets.all(Spacing.lg),
      children: [
        const SectionHeader(
          title: 'Local Models',
          subtitle: 'Download, verify and manage quantized GGUF models on this device.',
        ),
        const SizedBox(height: Spacing.md),

        // Honest capability notice — never imply inference we cannot run.
        GlassCard(
          tint: c.warning.withValues(alpha: 0.08),
          border: Border.all(color: c.warning.withValues(alpha: 0.3)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, size: 18, color: c.warning),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Runtime not installed', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(
                      'This hub downloads, verifies and stores models — that part is fully functional. Running a GGUF '
                      'requires a native inference runtime (llama.cpp or equivalent) which is not bundled with this build, '
                      'so the app does not pretend to answer questions it cannot execute.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.md),

        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'Model repository', subtitle: 'Set the base URL of a repo holding manifest.json'),
              const SizedBox(height: Spacing.sm),
              _RepoField(
                initial: ref.watch(settingsProvider).value?.modelBaseUrl ?? '',
                onSave: (v) async {
                  await ref.read(settingsControllerProvider).update((s) => s.copyWith(modelBaseUrl: v));
                  ref.invalidate(modelManifestProvider);
                },
              ),
              if (!hub.supported) ...[
                const SizedBox(height: Spacing.sm),
                Text('Model storage is only available in the Android and Windows builds.', style: TextStyle(color: c.warning, fontSize: 12)),
              ],
            ],
          ),
        ),
        const SizedBox(height: Spacing.md),

        manifest.when(
          loading: () => const GlassCard(child: LoadingView()),
          error: (e, _) => GlassCard(child: ErrorView(message: 'Could not read the model manifest: $e', onRetry: () => ref.invalidate(modelManifestProvider))),
          data: (m) {
            if (m == null) {
              return GlassCard(
                child: Text(
                  'No repository configured. Point the field above at a repo containing manifest.json to list models here.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              );
            }
            if (m.models.isEmpty) {
              return GlassCard(child: Text('The manifest lists no models.', style: Theme.of(context).textTheme.bodyMedium));
            }
            return GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeader(title: 'Available (${m.models.length})', subtitle: 'Manifest v${m.version}'),
                  const SizedBox(height: Spacing.sm),
                  for (final model in m.models)
                    _ModelRow(
                      model: model,
                      progress: _progress[model.id],
                      onDownload: () => _download(model),
                    ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: Spacing.md),

        installed.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (list) => GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(title: 'Installed on this device (${list.length})', subtitle: 'Stored under the app support directory'),
                const SizedBox(height: Spacing.sm),
                if (list.isEmpty)
                  Text('Nothing installed yet.', style: Theme.of(context).textTheme.bodySmall)
                else
                  for (final m in list)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.memory_rounded, color: c.accent),
                      title: Text(m.info.name),
                      subtitle: Text('${m.info.quantization} · ${m.sizeMb.toStringAsFixed(0)} MB · ${m.info.license}'),
                      trailing: IconButton(
                        tooltip: 'Remove',
                        icon: Icon(Icons.delete_outline_rounded, color: c.danger),
                        onPressed: () async {
                          await hub.remove(m.info.id);
                          ref.invalidate(installedModelsProvider);
                          ref.read(activityLogProvider).warn('Removed model “${m.info.name}”.');
                        },
                      ),
                    ),
              ],
            ),
          ),
        ),
        if (_status != null) ...[
          const SizedBox(height: Spacing.sm),
          Text(_status!, style: TextStyle(color: _error ? c.danger : c.success, fontSize: 12)),
        ],
      ],
    );
  }

  Future<void> _download(ModelInfo model) async {
    final hub = ref.read(modelHubProvider);
    setState(() {
      _status = 'Downloading ${model.name}…';
      _error = false;
      _progress[model.id] = 0;
    });
    try {
      await hub.download(
        model,
        onProgress: (p) => setState(() => _progress[model.id] = p.fraction),
      );
      ref.invalidate(installedModelsProvider);
      ref.read(activityLogProvider).success('Downloaded and verified model “${model.name}”.');
      setState(() {
        _progress.remove(model.id);
        _status = 'Installed ${model.name}.';
      });
    } catch (e) {
      setState(() {
        _progress.remove(model.id);
        _status = 'Download failed — $e';
        _error = true;
      });
    }
  }
}

class _ModelRow extends StatelessWidget {
  final ModelInfo model;
  final double? progress;
  final VoidCallback onDownload;

  const _ModelRow({required this.model, required this.progress, required this.onDownload});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final p = progress;
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(model.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14)),
                    Text(
                      '${model.family} · ${model.parameters} · ${model.quantization} · ${model.sizeMb.toStringAsFixed(0)} MB · ${model.license}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (p == null)
                OutlinedButton.icon(
                  onPressed: model.url.isEmpty ? null : onDownload,
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Download'),
                )
              else
                SizedBox(
                  width: 120,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      LinearProgressIndicator(value: p, backgroundColor: c.surfaceAlt, color: c.accent),
                      const SizedBox(height: 2),
                      Text('${(p * 100).toStringAsFixed(0)}%', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RepoField extends StatefulWidget {
  final String initial;
  final ValueChanged<String> onSave;
  const _RepoField({required this.initial, required this.onSave});

  @override
  State<_RepoField> createState() => _RepoFieldState();
}

class _RepoFieldState extends State<_RepoField> {
  late final TextEditingController _c = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _c,
            decoration: const InputDecoration(hintText: 'https://raw.githubusercontent.com/ORG/quant-rd-models/main'),
          ),
        ),
        const SizedBox(width: Spacing.sm),
        FilledButton(onPressed: () => widget.onSave(_c.text.trim()), child: const Text('Save')),
      ],
    );
  }
}
