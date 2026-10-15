import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quant_rd/core/theme/app_theme.dart';
import 'package:quant_rd/data/models/fundamentals.dart';
import 'package:quant_rd/data/remote/edgar_client.dart';
import 'package:quant_rd/domain/providers/knowledge_providers.dart';
import 'package:quant_rd/presentation/shell/options_screen.dart';

Future<void> settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pumpAndSettle(const Duration(seconds: 2));
}

void main() {
  group('chain parsing', () {
    test('parses a supplied chain and accepts percentages', () {
      final (chain, err) = ChainCsvParser.parse('strike, openInterest, iv, type\n100, 4000, 25, C\n105, 3200, 0.26, P');
      expect(err, isNull);
      expect(chain, isNotNull);
      expect(chain!.length, 2);
      expect(chain.first.strike, 100);
      expect(chain.first.impliedVolatility, closeTo(0.25, 1e-9)); // "25" read as 25%
      expect(chain.first.isCall, isTrue);
      expect(chain.last.isCall, isFalse);
    });

    test('a malformed line is reported, not silently dropped', () {
      final (chain, err) = ChainCsvParser.parse('100, notanumber, 0.2');
      expect(chain, isNull);
      expect(err, contains('Line 1'));
    });

    test('an empty document is reported', () {
      final (chain, err) = ChainCsvParser.parse('   \n  ');
      expect(chain, isNull);
      expect(err, isNotNull);
    });
  });

  group('simulated feed', () {
    test('produces a symmetric chain around the spot with a smile', () {
      final chain = SimulatedOptionFeed.generate(spot: 100, baseVolatility: 0.25, strikesEachSide: 6);
      expect(chain, isNotEmpty);
      final strikes = chain.map((q) => q.strike).toSet().toList()..sort();
      expect(strikes.length, 13);
      // At-the-money implied vol is the base; the wings are higher (the smile).
      final atm = chain.where((q) => q.strike == 100).map((q) => q.impliedVolatility).reduce((a, b) => a + b) / 2;
      final wing = chain.where((q) => q.strike == strikes.first).map((q) => q.impliedVolatility).reduce((a, b) => a + b) / 2;
      expect(wing, greaterThan(atm));
    });

    test('it is deterministic', () {
      final a = SimulatedOptionFeed.generate(spot: 100);
      final b = SimulatedOptionFeed.generate(spot: 100);
      expect(a.length, b.length);
      for (var i = 0; i < a.length; i++) {
        expect(a[i].strike, b[i].strike);
        expect(a[i].openInterest, b[i].openInterest);
      }
    });
  });

  group('options screen', () {
    Widget wrap() => ProviderScope(
          overrides: [edgarClientProvider.overrideWithValue(_NoEdgar())],
          // The app's theme supplies the colour extension the screens read.
          child: MaterialApp(theme: AppTheme.dark(), home: const Scaffold(body: OptionsScreen())),
        );

    testWidgets('renders and computes a GEX dashboard, labelling the simulated chain', (tester) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrap());
      await settle(tester);

      expect(find.text('Options & Dealer Gamma'), findsOneWidget);
      expect(find.text('Compute'), findsOneWidget);

      await tester.tap(find.text('Compute'));
      await settle(tester);

      // The simulated feed must be labelled, per the data-integrity guardrail.
      expect(find.textContaining('SIMULATED CHAIN'), findsOneWidget);
      // The dashboard panels render. The smile sits below the fold, so scroll to it.
      expect(find.text('Dealer gamma exposure'), findsOneWidget);
      expect(find.text('Net gamma by strike'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Volatility smile'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('Volatility smile'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('rejects a bad spot rather than computing nonsense', (tester) async {
      tester.view.physicalSize = const Size(1600, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(wrap());
      await settle(tester);

      await tester.enterText(find.widgetWithText(TextField, '100'), '-5');
      await settle(tester);
      await tester.tap(find.text('Compute'));
      await settle(tester);

      expect(find.textContaining('must be positive'), findsOneWidget);
      expect(find.text('Net gamma by strike'), findsNothing);
    });
  });
}

/// A stub EDGAR client so the options screen never touches the network.
class _NoEdgar implements EdgarClient {
  @override
  bool get supported => false;
  @override
  Future<String?> resolveCik(String ticker) async => null;
  @override
  Future<FundamentalSnapshot> fetchFundamentals(String ticker, {required String userAgent}) async =>
      throw const DataFeedUnavailable('SEC EDGAR', 'disabled in tests');
}
