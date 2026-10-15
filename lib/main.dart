/// Application entrypoint.
///
/// Opens the local database before the first frame, installs the self-healing
/// error reporter, restores the persisted activity log, seeds the built-in
/// strategies, then starts the app.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/errors/error_reporter.dart';
import 'core/logging/activity_log.dart';
import 'data/storage/database_factory.dart';
import 'data/storage/repositories.dart';
import 'domain/providers/core_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Install global error handlers first so nothing is ever lost.
  final bootLog = ActivityLog();
  ErrorReporter(bootLog).install();

  try {
    final database = createAppDatabase();
    await database.open();

    // Restore and persist the plain-English activity log.
    final activityLog = ActivityLog(
      onChanged: (json) {
        // Fire-and-forget persistence; a failure here must never crash the app.
        database.setSetting('activity_log', json).catchError((_) {});
      },
    );
    activityLog.loadFrom(await database.getSetting('activity_log'));

    // Seed the global built-in strategies for the active workspace.
    final activeWorkspace = await WorkspaceRepository(database).activeId();
    await StrategyRepository(database).all(activeWorkspace);

    activityLog.info('Quant RD started. Workspace: ${activeWorkspace == 'ws-default' ? 'Default project' : activeWorkspace}.');

    runApp(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(database),
          activityLogProvider.overrideWithValue(activityLog),
        ],
        child: const QuantRdApp(),
      ),
    );
  } catch (error, stack) {
    bootLog.error(ErrorReporter.describeError(error, stack, context: 'Startup'));
    runApp(StartupErrorApp(message: 'Local storage could not be initialised.\n\n$error'));
  }
}
