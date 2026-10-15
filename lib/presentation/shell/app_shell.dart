/// The application shell: a persistent, multi-tab sidebar beside the main
/// content area on wide screens, collapsing to a drawer on narrow ones.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/design_tokens.dart';
import '../../domain/providers/ui_providers.dart';
import 'screens.dart';
import 'sidebar.dart';

class AppShell extends ConsumerWidget {
  const AppShell({super.key});

  static const double _sidebarWidth = 296;
  static const double _breakpoint = 900;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final destination = ref.watch(navDestinationProvider);
    final wide = MediaQuery.sizeOf(context).width >= _breakpoint;

    final content = _ContentArea(destination: destination);

    return Scaffold(
      drawer: wide ? null : const Drawer(width: _sidebarWidth, child: Sidebar(compact: true)),
      appBar: wide
          ? null
          : AppBar(
              title: Text(destination.label),
              backgroundColor: context.colors.bgTop.withValues(alpha: 0.85),
            ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [context.colors.bgTop, context.colors.bgBottom],
          ),
        ),
        child: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (wide)
                SizedBox(
                  width: _sidebarWidth,
                  child: const Sidebar(),
                ),
              if (wide) const _VerticalDivider(),
              Expanded(child: content),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContentArea extends StatelessWidget {
  final NavDestination destination;
  const _ContentArea({required this.destination});

  @override
  Widget build(BuildContext context) {
    final child = switch (destination) {
      NavDestination.dashboard => const DashboardScreen(),
      NavDestination.data => const DataManagerScreen(),
      NavDestination.strategies => const StrategyLabScreen(),
      NavDestination.backtest => const BacktestScreen(),
      NavDestination.results => const ResultsScreen(),
      NavDestination.research => const ResearchScreen(),
      NavDestination.knowledge => const BookIntelligenceScreen(),
      NavDestination.models => const ModelsScreen(),
      NavDestination.swarm => const SwarmScreen(),
      NavDestination.activityLog => const ActivityLogScreen(),
    };
    return AnimatedSwitcher(
      duration: Motion.standard,
      switchInCurve: Motion.emphasized,
      transitionBuilder: (c, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero).animate(anim),
          child: c,
        ),
      ),
      child: KeyedSubtree(key: ValueKey(destination), child: child),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  const _VerticalDivider();
  @override
  Widget build(BuildContext context) => Container(width: 1, color: context.colors.border);
}
