import 'package:flutter_test/flutter_test.dart';
import 'package:quant_rd/core/constants.dart';
import 'package:quant_rd/data/models/candle.dart';
import 'package:quant_rd/data/models/dataset.dart';
import 'package:quant_rd/data/models/strategy_spec.dart';
import 'package:quant_rd/data/storage/app_database_web.dart';
import 'package:quant_rd/data/storage/repositories.dart';

Candle candle(int i, double close) => Candle(
      time: DateTime.utc(2020, 1, 1).add(Duration(days: i)),
      open: close,
      high: close + 1,
      low: close - 1,
      close: close,
      volume: 100,
    );

void main() {
  late WebAppDatabase db;
  const wsA = 'ws-a';
  const wsB = 'ws-b';

  setUp(() async {
    db = WebAppDatabase();
    await db.open();
  });

  test('datasets round-trip through the store', () async {
    final repo = DatasetRepository(db);
    final r = await repo.save(
      workspaceId: wsA,
      symbol: 'TEST',
      interval: BarInterval.d1,
      source: DataSource.csvImport,
      candles: [candle(0, 1), candle(1, 2)],
    );
    final ds = r.valueOrThrow;
    expect((await repo.all(wsA)).length, 1);
    expect((await repo.candles(ds.id)).length, 2);
    await repo.delete(ds.id);
    expect(await repo.all(wsA), isEmpty);
    expect(await repo.candles(ds.id), isEmpty);
  });

  test('workspaces are isolated from each other', () async {
    final repo = DatasetRepository(db);
    await repo.save(workspaceId: wsA, symbol: 'AAA', interval: BarInterval.d1, source: DataSource.custom, candles: [candle(0, 1)]);
    await repo.save(workspaceId: wsB, symbol: 'BBB', interval: BarInterval.d1, source: DataSource.custom, candles: [candle(0, 1)]);
    expect((await repo.all(wsA)).single.symbol, 'AAA');
    expect((await repo.all(wsB)).single.symbol, 'BBB');
    expect((await repo.all('ws-empty')), isEmpty);
  });

  test('clearing a workspace removes only its own data', () async {
    final repo = DatasetRepository(db);
    await repo.save(workspaceId: wsA, symbol: 'AAA', interval: BarInterval.d1, source: DataSource.custom, candles: [candle(0, 1)]);
    await repo.save(workspaceId: wsB, symbol: 'BBB', interval: BarInterval.d1, source: DataSource.custom, candles: [candle(0, 1)]);
    await db.clearWorkspace(wsA);
    expect(await repo.all(wsA), isEmpty);
    expect((await repo.all(wsB)).length, 1);
  });

  test('settings persist and delete', () async {
    expect(await db.getSetting('k'), isNull);
    await db.setSetting('k', 'v');
    expect(await db.getSetting('k'), 'v');
    await db.deleteSetting('k');
    expect(await db.getSetting('k'), isNull);
  });

  test('StrategyRepository seeds built-ins and protects them from deletion', () async {
    final repo = StrategyRepository(db);
    final all = await repo.all(wsA);
    expect(all.where((s) => s.isBuiltIn).length, 6);
    expect(await repo.delete(wsA, 'builtin.sma_cross'), isFalse);
  });

  test('a user strategy is scoped to its workspace', () async {
    final repo = StrategyRepository(db);
    await repo.all(wsA); // seed the global built-ins
    final spec = StrategySpec(id: 'user-1', workspaceId: wsA, name: 'Mine', updatedAt: DateTime.utc(2024));
    await repo.save(spec);
    expect((await repo.all(wsA)).any((s) => s.id == 'user-1'), isTrue);
    expect((await repo.all(wsB)).any((s) => s.id == 'user-1'), isFalse);
    // Built-ins are global, so both workspaces see all six.
    expect((await repo.all(wsB)).where((s) => s.isBuiltIn).length, 6);
  });

  test('workspace create / rename / delete / active', () async {
    final repo = WorkspaceRepository(db);
    final ws = await repo.create('Research');
    expect((await repo.all()).any((w) => w.id == ws.id), isTrue);

    await repo.rename(ws.id, 'Renamed');
    expect((await repo.all()).firstWhere((w) => w.id == ws.id).name, 'Renamed');

    await repo.setActive(ws.id);
    expect(await repo.activeId(), ws.id);

    await repo.delete(ws.id);
    expect((await repo.all()).any((w) => w.id == ws.id), isFalse);

    // The default workspace can never be deleted.
    await repo.delete(StorageKeys.defaultWorkspaceId);
    expect((await repo.all()).any((w) => w.id == StorageKeys.defaultWorkspaceId), isTrue);
  });

  test('DatasetRepository rejects an empty import', () async {
    final repo = DatasetRepository(db);
    final result = await repo.save(
      workspaceId: wsA,
      symbol: 'X',
      interval: BarInterval.d1,
      source: DataSource.custom,
      candles: const [],
    );
    expect(result.isFailure, isTrue);
  });
}
