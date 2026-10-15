import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quant_rd/app.dart';
import 'package:quant_rd/core/constants.dart';
import 'package:quant_rd/data/models/backtest_config.dart';
import 'package:quant_rd/data/models/dataset.dart';
import 'package:quant_rd/data/sample/sample_data.dart';
import 'package:quant_rd/data/storage/app_database_web.dart';
import 'package:quant_rd/data/storage/repositories.dart';
import 'package:quant_rd/domain/engine/backtest_engine.dart';
import 'package:quant_rd/domain/providers/core_providers.dart';

/// Pumps a bounded number of frames so async loads complete and entrance
/// animations finish, without waiting for a fully idle tree (which never
/// happens while a progress spinner is on screen).
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

/// Walks every screen and sidebar tab with seeded data. Any layout overflow or
/// unhandled exception fails the test.
void main() {
  testWidgets('every screen and sidebar tab renders without errors', (tester) async {
    tester.view.physicalSize = const Size(1500, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = WebAppDatabase();
    await db.open();

    // Seed a dataset and a completed backtest.
    const wsId = StorageKeys.defaultWorkspaceId;
    final dsRepo = DatasetRepository(db);
    final candles = SampleData.generate(symbol: 'SAMPLE', bars: 600, interval: BarInterval.d1);
    final saved = await dsRepo.save(workspaceId: wsId, symbol: 'SAMPLE', interval: BarInterval.d1, source: DataSource.custom, candles: candles);
    final dataset = saved.valueOrThrow;

    final strategies = await StrategyRepository(db).all(wsId);
    final strategy = strategies.firstWhere((s) => s.id == 'builtin.sma_cross');
    final result = BacktestEngine.run(
      resultId: 'bt1',
      candles: candles,
      strategy: strategy,
      config: const BacktestConfig(initialCapital: 100000),
      datasetId: dataset.id,
      symbol: 'SAMPLE',
      workspaceId: wsId,
    );
    await BacktestRepository(db).save(result);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const QuantRdApp(),
      ),
    );
    await settle(tester);

    // Walk each navigation destination.
    for (final label in ['Market Data', 'Strategy Lab', 'Backtest', 'Results', 'Dashboard']) {
      await tester.tap(find.text(label).first);
      await settle(tester);
      expect(tester.takeException(), isNull, reason: 'Navigation to $label threw');
    }

    // Walk each sidebar tab.
    for (final tab in ['API Keys', 'Configs', 'Navigate']) {
      await tester.tap(find.text(tab).first);
      await settle(tester);
      expect(tester.takeException(), isNull, reason: 'Sidebar tab $tab threw');
    }
  });
}
