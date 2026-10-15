/// Core providers: database, logging, secret store, clients and repositories.
///
/// The [databaseProvider] and [activityLogProvider] are overridden in `main()`
/// with already-opened instances so every other provider can access them
/// synchronously.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/ids.dart';
import '../../core/logging/activity_log.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/workspace.dart';
import '../../data/remote/asset_pack_factory.dart';
import '../../data/remote/asset_pack_manager.dart';
import '../../data/remote/market_data_client.dart';
import '../../data/storage/app_database.dart';
import '../../data/storage/repositories.dart';
import '../../data/storage/secret_store.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('databaseProvider must be overridden in ProviderScope.');
});

final activityLogProvider = Provider<ActivityLog>((ref) {
  final log = ActivityLog();
  ref.onDispose(log.dispose);
  return log;
});

final secretStoreProvider = Provider<SecretStore>((ref) => SecureSecretStore());

final marketDataClientProvider = Provider<MarketDataClient>((ref) => MarketDataClient());

final assetPackManagerProvider = Provider<AssetPackManager>((ref) => createAssetPackManager());

final datasetRepositoryProvider =
    Provider<DatasetRepository>((ref) => DatasetRepository(ref.watch(databaseProvider)));

final strategyRepositoryProvider =
    Provider<StrategyRepository>((ref) => StrategyRepository(ref.watch(databaseProvider)));

final backtestRepositoryProvider =
    Provider<BacktestRepository>((ref) => BacktestRepository(ref.watch(databaseProvider)));

final settingsRepositoryProvider =
    Provider<SettingsRepository>((ref) => SettingsRepository(ref.watch(databaseProvider)));

final workspaceRepositoryProvider =
    Provider<WorkspaceRepository>((ref) => WorkspaceRepository(ref.watch(databaseProvider)));

/// Application settings, loaded once from the database.
final settingsProvider = FutureProvider<AppSettings>((ref) async {
  return ref.watch(settingsRepositoryProvider).load();
});

/// Convenience: resolved theme mode with a safe default while settings load.
final themeModeProvider = Provider<ThemeMode>((ref) {
  return ref.watch(settingsProvider).maybeWhen(
        data: (s) => s.themeMode,
        orElse: () => ThemeMode.dark,
      );
});

/// Convenience: currency symbol from settings.
final currencySymbolProvider = Provider<String>((ref) {
  return ref.watch(settingsProvider).maybeWhen(
        data: (s) => s.currencySymbol,
        orElse: () => '\u20b9',
      );
});

// --- Workspaces -----------------------------------------------------------

final workspacesProvider = FutureProvider<List<Workspace>>((ref) async {
  return ref.watch(workspaceRepositoryProvider).all();
});

/// The active workspace id. Every data provider depends on this, so switching
/// workspace automatically re-scopes datasets, strategies and backtests.
final activeWorkspaceIdProvider = FutureProvider<String>((ref) async {
  return ref.watch(workspaceRepositoryProvider).activeId();
});

class WorkspaceController {
  final Ref ref;
  WorkspaceController(this.ref);

  ActivityLog get _log => ref.read(activityLogProvider);

  Future<void> switchTo(String id) async {
    await ref.read(workspaceRepositoryProvider).setActive(id);
    ref.invalidate(activeWorkspaceIdProvider);
    ref.invalidate(workspacesProvider);
    final name = await _nameOf(id);
    _log.info('Switched to workspace “$name”. Data from other projects is hidden.');
  }

  Future<String> create(String name) async {
    final ws = await ref.read(workspaceRepositoryProvider).create(name);
    ref.invalidate(workspacesProvider);
    await ref.read(workspaceRepositoryProvider).setActive(ws.id);
    ref.invalidate(activeWorkspaceIdProvider);
    _log.success('Created workspace “${ws.name}”.');
    return ws.id;
  }

  Future<void> rename(String id, String name) async {
    await ref.read(workspaceRepositoryProvider).rename(id, name);
    ref.invalidate(workspacesProvider);
    _log.info('Renamed workspace to “$name”.');
  }

  Future<void> delete(String id) async {
    if (id == StorageKeys.defaultWorkspaceId) {
      _log.warn('The default workspace cannot be deleted.');
      return;
    }
    final name = await _nameOf(id);
    await ref.read(workspaceRepositoryProvider).delete(id);
    final active = await ref.read(workspaceRepositoryProvider).activeId();
    if (active == id) {
      await ref.read(workspaceRepositoryProvider).setActive(StorageKeys.defaultWorkspaceId);
    }
    ref.invalidate(workspacesProvider);
    ref.invalidate(activeWorkspaceIdProvider);
    _log.warn('Deleted workspace “$name” and all of its data.');
  }

  Future<void> clear(String id) async {
    final name = await _nameOf(id);
    await ref.read(workspaceRepositoryProvider).clear(id);
    ref.invalidate(workspacesProvider);
    ref.invalidate(activeWorkspaceIdProvider);
    _log.warn('Cleared all data in workspace “$name”.');
  }

  Future<String> _nameOf(String id) async {
    final list = await ref.read(workspaceRepositoryProvider).all();
    for (final w in list) {
      if (w.id == id) return w.name;
    }
    return id;
  }
}

final workspaceControllerProvider = Provider<WorkspaceController>((ref) => WorkspaceController(ref));

/// Centralised settings mutation: reads current, applies a transform, saves and
/// refreshes the [settingsProvider].
class SettingsController {
  final Ref ref;
  SettingsController(this.ref);

  Future<void> update(AppSettings Function(AppSettings current) transform) async {
    final repo = ref.read(settingsRepositoryProvider);
    final current = await repo.load();
    await repo.save(transform(current));
    ref.invalidate(settingsProvider);
  }

  Future<void> reset() async {
    await ref.read(settingsRepositoryProvider).save(const AppSettings());
    ref.invalidate(settingsProvider);
  }
}

final settingsControllerProvider = Provider<SettingsController>((ref) => SettingsController(ref));

/// The id used when creating new entities in the active workspace.
final newIdProvider = Provider<String Function(String)>((ref) => Ids.newId);
