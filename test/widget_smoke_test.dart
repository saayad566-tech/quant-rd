import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quant_rd/app.dart';
import 'package:quant_rd/data/storage/app_database_web.dart';
import 'package:quant_rd/data/storage/repositories.dart';
import 'package:quant_rd/core/constants.dart';
import 'package:quant_rd/domain/providers/core_providers.dart';

void main() {
  testWidgets('the app shell renders with a local database', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final db = WebAppDatabase();
    await db.open();
    await StrategyRepository(db).all(StorageKeys.defaultWorkspaceId);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const QuantRdApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Sidebar brand + navigation are present.
    expect(find.text('Quant RD'), findsOneWidget);
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Strategy Lab'), findsWidgets);
    expect(find.text('Welcome back'), findsOneWidget);
  });
}
