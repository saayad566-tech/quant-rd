import 'package:flutter_test/flutter_test.dart';
import 'package:quant_rd/data/models/api_provider.dart';
import 'package:quant_rd/data/models/strategy_spec.dart';
import 'package:quant_rd/domain/engine/builtin_strategies.dart';

void main() {
  group('strategy import / export', () {
    test('a strategy round-trips through its map', () {
      final s = BuiltInStrategies.smaCrossover();
      final restored = StrategySpec.fromMap(s.toMap());
      expect(restored.name, s.name);
      expect(restored.entry.length, s.entry.length);
      expect(restored.exit.length, s.exit.length);
      expect(restored.sizing, s.sizing);
      expect(restored.enabled, isTrue);
    });

    test('the enabled flag round-trips', () {
      final s = StrategySpec(id: 'x', name: 'x', enabled: false, updatedAt: DateTime.utc(2024));
      expect(StrategySpec.fromMap(s.toMap()).enabled, isFalse);
    });

    test('a minimal imported map is tolerated with sensible defaults', () {
      final spec = StrategySpec.fromMap({
        'id': 'imported',
        'name': 'My strategy',
        'updated_at': DateTime.utc(2024).millisecondsSinceEpoch,
      });
      expect(spec.name, 'My strategy');
      expect(spec.entry, isEmpty);
      expect(spec.sizing, PositionSizing.percentOfEquity);
      expect(spec.sizingValue, 100);
      expect(spec.enabled, isTrue);
      expect(spec.isBuiltIn, isFalse);
    });

    test('conditions survive a round-trip', () {
      final s = BuiltInStrategies.macdTrend();
      final restored = StrategySpec.fromMap(s.toMap());
      expect(restored.entry.single.label, s.entry.single.label);
    });
  });

  group('provider metadata', () {
    test('yahoo and binance are keyless; the rest need a key', () {
      expect(ApiProvider.yahoo.requiresKey, isFalse);
      expect(ApiProvider.binance.requiresKey, isFalse);
      expect(ApiProvider.alphaVantage.requiresKey, isTrue);
      expect(ApiProvider.keyless, containsAll([ApiProvider.yahoo, ApiProvider.binance]));
      expect(ApiProvider.keyless, isNot(contains(ApiProvider.custom)));
    });

    test('keyed excludes the keyless sources and the custom endpoint', () {
      expect(ApiProvider.keyed, isNot(contains(ApiProvider.yahoo)));
      expect(ApiProvider.keyed, isNot(contains(ApiProvider.binance)));
      expect(ApiProvider.keyed.length, 4);
    });

    test('fromId falls back to a keyless source', () {
      expect(ApiProvider.fromId('nonsense'), ApiProvider.yahoo);
      expect(ApiProvider.fromId('binance'), ApiProvider.binance);
    });
  });
}
