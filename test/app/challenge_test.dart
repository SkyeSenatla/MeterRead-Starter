import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meterread/app/database/app_database.dart';
import 'package:meterread/core/fakes/meter_server.dart';

import '../support/harness.dart';

void main() {
  testWidgets('round loads all pages and keeps server meters-left count', (
    tester,
  ) async {
    await pumpMeterRead(tester);
    expect(find.text('11 meters left'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('21 Umthombo Road'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('21 Umthombo Road'), findsOneWidget);
  });

  testWidgets('finished round plural is correct in isiZulu', (tester) async {
    await pumpMeterRead(
      tester,
      server: MeterServer(latency: Duration.zero, roundDone: true),
      locale: const Locale('zu'),
    );
    expect(find.text('Kusele imitha engu-0'), findsOneWidget);
  });

  testWidgets('invalid characters are kept and explained under the field', (
    tester,
  ) async {
    await pumpMeterRead(tester, deepLink: '/round/meters/M-1001');
    await tester.enterText(find.byType(TextField), '48a90');
    await tester.tap(find.text('Save reading'));
    await tester.pumpAndSettle();
    expect(find.text('Use digits only, like 48 590.'), findsOneWidget);
    expect(find.text('48a90'), findsOneWidget);
  });

  testWidgets('one expired access token triggers one refresh for two reads', (
    tester,
  ) async {
    final harness = await pumpMeterRead(tester);
    final before = harness.server.refreshCalls;
    harness.server.expireAccessTokens();
    await tester.tap(find.text('2 Lwandle Street'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Last reading 48'), findsOneWidget);
    expect(harness.server.refreshCalls - before, 1);
  });

  testWidgets('lost response can be replayed without duplicate readings', (
    tester,
  ) async {
    final harness = await pumpMeterRead(
      tester,
      deepLink: '/round/meters/M-1007',
    );
    await tester.enterText(find.byType(TextField), '31 250');
    await tester.tap(find.text('Save reading'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Not sent yet'), findsOneWidget);
    expect(harness.server.readingsFor('M-1007').length, 1);
    await tester.tap(find.text('Send now'));
    await tester.pumpAndSettle();
    expect(harness.server.readingsFor('M-1007').length, 1);
    expect(find.textContaining('kWh used'), findsOneWidget);
  });

  testWidgets('signing out wipes cache, outbox and refresh token', (
    tester,
  ) async {
    final harness = await pumpMeterRead(tester);
    final database = harness.container.read(appDatabaseProvider);
    expect((await database.select(database.cachedRounds).get()).length, 1);
    await tester.tap(find.byTooltip('Sign out'));
    await tester.pumpAndSettle();
    expect(await rowsInDatabase(tester, harness.container), 0);
    expect(await harness.tokens.read(), isNull);
  });
}
