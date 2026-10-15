/// UI navigation state.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum NavDestination {
  dashboard('Dashboard'),
  data('Market Data'),
  strategies('Strategy Lab'),
  backtest('Backtest'),
  results('Results'),
  research('Research'),
  knowledge('Book Intelligence'),
  models('Local Models'),
  swarm('Device Swarm'),
  activityLog('Activity Log');

  const NavDestination(this.label);
  final String label;
}

enum SidebarTab {
  navigate('Navigate'),
  apiKeys('API Keys'),
  configs('Configs');

  const SidebarTab(this.label);
  final String label;
}

class NavDestinationNotifier extends Notifier<NavDestination> {
  @override
  NavDestination build() => NavDestination.dashboard;
  void go(NavDestination d) => state = d;
}

class SidebarTabNotifier extends Notifier<SidebarTab> {
  @override
  SidebarTab build() => SidebarTab.navigate;
  void go(SidebarTab t) => state = t;
}

final navDestinationProvider = NotifierProvider<NavDestinationNotifier, NavDestination>(NavDestinationNotifier.new);
final sidebarTabProvider = NotifierProvider<SidebarTabNotifier, SidebarTab>(SidebarTabNotifier.new);
