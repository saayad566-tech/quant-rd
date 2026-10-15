/// Book Intelligence: the framework catalogue, the screener, the supply-chain
/// map, and the on-device book library.
library;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../domain/knowledge/book_catalogue.dart';
import '../../domain/knowledge/book_framework.dart';
import '../../domain/knowledge/framework_screener.dart';
import '../../domain/knowledge/supply_chain.dart';
import '../../domain/providers/knowledge_providers.dart';
import '../widgets/common.dart';

/// The compliance badge. Non-dismissible by design.
class ComplianceBanner extends StatelessWidget {
  const ComplianceBanner({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(Spacing.sm),
      decoration: BoxDecoration(
        color: c.warning.withValues(alpha: 0.10),
        borderRadius: Radii.rSm,
        border: Border.all(color: c.warning.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.gavel_rounded, size: 16, color: c.warning),
          const SizedBox(width: Spacing.xs),
          Expanded(
            child: Text(
              'NOT INVESTMENT ADVICE: The strategies and asset listings generated in Strategy Lab are purely algorithmic '
              'outputs derived from financial literature frameworks (e.g. Benjamin Graham, Joel Greenblatt, Peter Lynch). '
              'This tool is for research and educational purposes only and does not constitute financial advice.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: c.warning,
                    fontSize: compact ? 10.5 : 11.5,
                    height: 1.35,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class BookIntelligenceScreen extends ConsumerStatefulWidget {
  const BookIntelligenceScreen({super.key});

  @override
  ConsumerState<BookIntelligenceScreen> createState() => _BookIntelligenceScreenState();
}

class _BookIntelligenceScreenState extends ConsumerState<BookIntelligenceScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this);
  String _frameworkId = kFrameworks.first.id;

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final region = ref.watch(marketRegionProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Spacing.lg, Spacing.lg, Spacing.lg, Spacing.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(
                title: 'Book Intelligence',
                subtitle: 'Frameworks from the investment literature, applied to real data.',
              ),
              const SizedBox(height: Spacing.sm),
              const ComplianceBanner(),
              const SizedBox(height: Spacing.xs),
              Text(
                'Active market region: ${region.label} (${region.exchanges}). Every screen and listing is filtered to this region.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Frameworks'),
            Tab(text: 'Screener'),
            Tab(text: 'Supply chain'),
            Tab(text: 'Book library'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _FrameworkList(selected: _frameworkId, onSelect: (id) => setState(() => _frameworkId = id)),
              _ScreenerTab(frameworkId: _frameworkId),
              const _ThemesTab(),
              const _LibraryTab(),
            ],
          ),
        ),
      ],
    );
  }
}

class _FrameworkList extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelect;

  const _FrameworkList({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fw = frameworkById(selected)!;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 300,
          child: ListView.builder(
            padding: const EdgeInsets.all(Spacing.md),
            itemCount: kFrameworks.length,
            itemBuilder: (context, i) {
              final f = kFrameworks[i];
              final isSel = f.id == selected;
              return GlassCard(
                margin: const EdgeInsets.only(bottom: Spacing.xs),
                padding: const EdgeInsets.all(Spacing.sm),
                tint: isSel ? c.accent.withValues(alpha: 0.12) : null,
                onTap: () => onSelect(f.id),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(f.name, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 13.5)),
                    const SizedBox(height: 2),
                    Text(f.book.citation, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10.5)),
                  ],
                ),
              );
            },
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(Spacing.md),
            children: [
              GlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      title: fw.name,
                      subtitle: fw.book.citation,
                      trailing: Pill(label: fw.category.label, color: c.accent),
                    ),
                    const SizedBox(height: Spacing.sm),
                    Text(fw.philosophy, style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: Spacing.md),
                    Text('METRICS USED', style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: Spacing.xxs),
                    for (final m in fw.metrics)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text('\u2022 $m', style: Theme.of(context).textTheme.bodySmall),
                      ),
                    const SizedBox(height: Spacing.md),
                    Text('CRITERIA', style: Theme.of(context).textTheme.labelSmall),
                    const SizedBox(height: Spacing.xs),
                    for (final crit in fw.criteria) _CriterionRow(criterion: crit),
                    if (fw.sources.isNotEmpty) ...[
                      const SizedBox(height: Spacing.md),
                      Text('SOURCES', style: Theme.of(context).textTheme.labelSmall),
                      const SizedBox(height: Spacing.xxs),
                      for (final s in fw.sources)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Text('\u2022 $s', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10.5)),
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CriterionRow extends StatelessWidget {
  final FrameworkCriterion criterion;
  const _CriterionRow({required this.criterion});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final auto = criterion.computableFromCandles;
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(auto ? Icons.bolt_rounded : Icons.dataset_outlined, size: 14, color: auto ? c.success : c.textMuted),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${criterion.name} — ${criterion.metric}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12.5)),
                Text(criterion.description, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
                if (criterion.threshold.isNotEmpty)
                  Text('Threshold: ${criterion.threshold}', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10.5, color: c.textMuted)),
                Text(
                  auto ? 'Computed from price and volume' : 'Needs fundamentals — reported as N/A, never faked',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10.5, color: auto ? c.success : c.warning),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ScreenerTab extends ConsumerWidget {
  final String frameworkId;
  const _ScreenerTab({required this.frameworkId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final state = ref.watch(screenerControllerProvider);
    final fw = frameworkById(frameworkId)!;
    return ListView(
      padding: const EdgeInsets.all(Spacing.md),
      children: [
        GlassCard(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Screen: ${fw.name}', style: Theme.of(context).textTheme.titleMedium),
                    Text('Runs against your stored datasets for the active region.', style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: state.running ? null : () => ref.read(screenerControllerProvider.notifier).run(frameworkId),
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: Text(state.running ? 'Screening…' : 'Run screen'),
              ),
            ],
          ),
        ),
        if (state.error != null) ...[
          const SizedBox(height: Spacing.sm),
          GlassCard(child: Text(state.error!, style: TextStyle(color: c.danger, fontSize: 12))),
        ],
        if (state.report != null && state.frameworkId == frameworkId) ...[
          const SizedBox(height: Spacing.md),
          GlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(
                  title: 'Results',
                  subtitle: '${state.report!.universeSize} symbols screened · ${state.report!.passing.length} passed every evaluable criterion',
                ),
                const SizedBox(height: Spacing.sm),
                for (final hit in state.report!.hits) _HitCard(hit: hit),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _HitCard extends StatelessWidget {
  final ScreenHit hit;
  const _HitCard({required this.hit});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final v = hit.verdict;
    final passed = v.passed;
    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.sm),
      child: Container(
        padding: const EdgeInsets.all(Spacing.sm),
        decoration: BoxDecoration(
          color: (passed ? c.success : c.surfaceAlt).withValues(alpha: passed ? 0.08 : 0.4),
          borderRadius: Radii.rSm,
          border: Border.all(color: passed ? c.success.withValues(alpha: 0.4) : c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(hit.symbol, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14))),
                Pill(label: '${v.met}/${v.evaluated} met', color: passed ? c.success : c.warning),
                const SizedBox(width: Spacing.xxs),
                if (v.unknown > 0) Pill(label: '${v.unknown} need data', color: c.textMuted),
              ],
            ),
            const SizedBox(height: 4),
            for (final r in v.results)
              Padding(
                padding: const EdgeInsets.only(bottom: 1),
                child: Text(
                  '${r.icon}  ${r.criterion.name}: ${r.detail}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 11,
                        color: r.state == CriterionState.met
                            ? c.success
                            : r.state == CriterionState.unmet
                                ? c.danger
                                : c.textMuted,
                      ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ThemesTab extends StatelessWidget {
  const _ThemesTab();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListView(
      padding: const EdgeInsets.all(Spacing.md),
      children: [
        GlassCard(
          child: Text(
            'Picks and shovels: when a theme booms, the front-line names are the most crowded. These maps point at the '
            'upstream choke-points instead. This describes industrial structure — it recommends no security and carries '
            'no price expectation.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: Spacing.sm),
        for (final theme in kSupplyChainThemes)
          GlassCard(
            margin: const EdgeInsets.only(bottom: Spacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(title: theme.name, subtitle: theme.thesis),
                const SizedBox(height: Spacing.xs),
                Wrap(
                  spacing: Spacing.xs,
                  runSpacing: Spacing.xxs,
                  children: [
                    for (final f in theme.frontLine) Pill(label: f, color: c.textMuted),
                  ],
                ),
                const SizedBox(height: Spacing.sm),
                Text('UPSTREAM CHOKE-POINTS', style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: Spacing.xs),
                for (final layer in theme.upstream)
                  Padding(
                    padding: const EdgeInsets.only(bottom: Spacing.xs),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${layer.layer} — ${layer.role}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12.5)),
                        Text(layer.whyItMatters, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
                        Text('Categories: ${layer.exampleCategories}', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10.5, color: c.textMuted)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _LibraryTab extends ConsumerStatefulWidget {
  const _LibraryTab();

  @override
  ConsumerState<_LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends ConsumerState<_LibraryTab> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final lib = ref.watch(bookLibraryProvider);
    final installed = ref.watch(installedBooksProvider);
    final state = ref.watch(bookLibraryControllerProvider);
    final pd = publicDomainBooks();

    return ListView(
      padding: const EdgeInsets.all(Spacing.md),
      children: [
        GlassCard(
          tint: c.info.withValues(alpha: 0.06),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Copyright, stated plainly', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 13.5)),
              const SizedBox(height: 2),
              Text(
                'This library downloads only public-domain titles, in full, from Project Gutenberg, which hosts them for '
                'anyone to copy and reuse. It will not download an in-copyright book. For those, use "Add my own copy" and '
                'supply a text file you own — it is stored on your device and never uploaded.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: Spacing.md),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(title: 'Public domain (${pd.length})', subtitle: 'Free to download in full, legally'),
              const SizedBox(height: Spacing.sm),
              if (!lib.supported)
                Text('Available in the Android and Windows builds.', style: TextStyle(color: c.warning, fontSize: 12))
              else
                for (final b in pd)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Icon(Icons.menu_book_rounded, size: 18, color: c.accent),
                    title: Text(b.title, style: const TextStyle(fontSize: 13)),
                    subtitle: Text('${b.author} · Gutenberg #${b.gutenbergId}', style: const TextStyle(fontSize: 11)),
                    trailing: OutlinedButton(
                      onPressed: state.busy ? null : () => ref.read(bookLibraryControllerProvider.notifier).fetchPublicDomain(b),
                      child: const Text('Fetch'),
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
              const SectionHeader(title: 'Add my own copy', subtitle: 'For a book you own — stored locally, never uploaded'),
              const SizedBox(height: Spacing.sm),
              _OwnCopyForm(onAdd: (title, author, text) {
                ref.read(bookLibraryControllerProvider.notifier).addOwnCopy(title: title, author: author, text: text);
              }),
            ],
          ),
        ),
        const SizedBox(height: Spacing.md),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SectionHeader(title: 'On this device (${installed.value?.length ?? 0})', subtitle: 'Indexed for search'),
              const SizedBox(height: Spacing.sm),
              installed.when(
                loading: () => const SizedBox.shrink(),
                error: (_, _) => const SizedBox.shrink(),
                data: (list) => list.isEmpty
                    ? Text('Nothing stored yet.', style: Theme.of(context).textTheme.bodySmall)
                    : Column(
                        children: [
                          for (final e in list)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              leading: Icon(e.userSupplied ? Icons.person_rounded : Icons.public_rounded, size: 18, color: c.accentAlt),
                              title: Text(e.title, style: const TextStyle(fontSize: 13)),
                              subtitle: Text('${e.author} · ${e.words} words · ${e.sizeKb.toStringAsFixed(0)} KB', style: const TextStyle(fontSize: 11)),
                              trailing: IconButton(
                                icon: Icon(Icons.delete_outline_rounded, size: 18, color: c.danger),
                                onPressed: () => ref.read(bookLibraryControllerProvider.notifier).remove(e.id),
                              ),
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: Spacing.sm),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _query,
                      decoration: const InputDecoration(hintText: 'Search across your stored books…', isDense: true),
                      onSubmitted: (v) => ref.read(bookLibraryControllerProvider.notifier).search(v),
                    ),
                  ),
                  const SizedBox(width: Spacing.sm),
                  FilledButton(onPressed: () => ref.read(bookLibraryControllerProvider.notifier).search(_query.text), child: const Text('Search')),
                ],
              ),
              if (state.message != null) ...[
                const SizedBox(height: Spacing.xs),
                Text(state.message!, style: TextStyle(color: state.error != null ? c.danger : c.success, fontSize: 11.5)),
              ],
              for (final p in state.passages)
                Padding(
                  padding: const EdgeInsets.only(top: Spacing.xs),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(p.bookTitle, style: Theme.of(context).textTheme.labelSmall),
                      Text('…${p.snippet}…', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OwnCopyForm extends StatefulWidget {
  final void Function(String title, String author, String text) onAdd;
  const _OwnCopyForm({required this.onAdd});

  @override
  State<_OwnCopyForm> createState() => _OwnCopyFormState();
}

class _OwnCopyFormState extends State<_OwnCopyForm> {
  final _title = TextEditingController();
  final _author = TextEditingController();
  final _text = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _author.dispose();
    _text.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final file = await FilePicker.pickFile(type: FileType.custom, allowedExtensions: ['txt', 'md']);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() {
      _text.text = String.fromCharCodes(bytes);
      if (_title.text.isEmpty) _title.text = file.name.split('.').first;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: TextField(controller: _title, decoration: const InputDecoration(labelText: 'Title', isDense: true))),
            const SizedBox(width: Spacing.sm),
            Expanded(child: TextField(controller: _author, decoration: const InputDecoration(labelText: 'Author', isDense: true))),
          ],
        ),
        const SizedBox(height: Spacing.sm),
        TextField(
          controller: _text,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'Paste the text of a book you own, or open a file below.'),
        ),
        if (_error != null) ...[
          const SizedBox(height: Spacing.xxs),
          Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 11.5)),
        ],
        const SizedBox(height: Spacing.sm),
        Row(
          children: [
            OutlinedButton.icon(onPressed: _pick, icon: const Icon(Icons.folder_open_rounded, size: 16), label: const Text('Open file')),
            const SizedBox(width: Spacing.sm),
            FilledButton(
              onPressed: () {
                if (_title.text.trim().isEmpty || _text.text.trim().length < 200) {
                  setState(() => _error = 'Give the book a title and at least a few hundred characters of text.');
                  return;
                }
                widget.onAdd(_title.text.trim(), _author.text.trim(), _text.text);
                _title.clear();
                _author.clear();
                _text.clear();
                setState(() => _error = null);
              },
              child: const Text('Index it'),
            ),
          ],
        ),
      ],
    );
  }
}
