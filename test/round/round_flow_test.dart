import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meterread/app/database/app_database.dart';
import 'package:meterread/core/fakes/meter_server.dart';
import 'package:meterread/features/round/data/round_repository.dart';
import 'package:meterread/features/round/domain/meter.dart';
import 'package:meterread/features/round/presentation/round_providers.dart';
import 'package:meterread/l10n/app_localizations.dart';

import '../support/harness.dart';

MeterServer _server() => MeterServer(latency: Duration.zero);

Future<void> _scrollTo(WidgetTester tester, Finder finder) => tester
    .scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);

void main() {
  group('errors (day 1)', () {
    testWidgets('no signal: friendly words, Try again, and not signed out', (
      tester,
    ) async {
      final server = _server()..online = false;
      final app = await pumpMeterRead(tester, server: server);

      expect(
        find.text('No signal. Check your connection and try again.'),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);
      expect(find.textContaining('DioException'), findsNothing);
      expect(app.tokens.refreshToken, isNotNull);

      server.online = true;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Round 7 · Kwanele Ext 4'), findsOneWidget);
    });

    testWidgets('a server crash shows the reference and is not retried', (
      tester,
    ) async {
      final server = _server();
      await pumpMeterRead(tester, server: server);
      await _scrollTo(tester, find.text('17 Umthombo Road'));
      final before = server.requestsReceived;

      await tester.tap(find.text('17 Umthombo Road'));
      await tester.pumpAndSettle();

      expect(find.textContaining('The server had a problem'), findsOneWidget);
      expect(
        find.textContaining(
          '00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01',
        ),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsOneWidget);
      // The meter and its readings, once each: no retry of a 500.
      expect(server.requestsReceived - before, 2);
    });

    testWidgets('a meter that is not there says so, without a retry', (
      tester,
    ) async {
      final server = _server();
      await pumpMeterRead(
        tester,
        server: server,
        deepLink: '/round/meters/M-9999',
      );

      expect(find.textContaining("couldn't find that"), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });
  });

  group('session (day 2)', () {
    testWidgets('no signal at launch does not sign the reader out', (
      tester,
    ) async {
      final server = _server()..online = false;
      final app = await pumpMeterRead(tester, server: server);

      expect(app.tokens.refreshToken, isNotNull);
      expect(find.text('Sign in'), findsNothing);
    });

    testWidgets('expired tokens refresh once for requests that fail together', (
      tester,
    ) async {
      final server = _server();
      final app = await pumpMeterRead(tester, server: server);
      server.expireAccessTokens();
      final before = server.refreshCalls;

      final readings = await tester.runAsync(() async {
        final repository = app.container.read(roundRepositoryProvider);
        return await Future.wait([
          repository.fetchMeter('M-1001'),
          repository.fetchMeter('M-1002'),
          repository.fetchMeter('M-1003'),
        ]);
      });

      expect(readings, hasLength(3));
      expect(server.refreshCalls - before, 1);
    });

    testWidgets('signing out deletes the tokens and every row', (tester) async {
      final app = await pumpMeterRead(tester);
      expect(await rowsInDatabase(tester, app.container), greaterThan(0));

      await tester.tap(find.byTooltip('Sign out'));
      await tester.pumpAndSettle();

      expect(find.text('Sign in'), findsWidgets);
      expect(app.tokens.refreshToken, isNull);
      expect(await rowsInDatabase(tester, app.container), 0);
    });
  });

  group('offline (day 3)', () {
    testWidgets('the saved list shows first, then updates', (tester) async {
      final server = MeterServer(latency: const Duration(seconds: 2));
      final app = await pumpMeterRead(tester, server: server, settle: false);
      // Let the launch refresh finish: the app is signed in.
      await tester.pump(const Duration(seconds: 3));
      await tester.runAsync(
        () => app.container
            .read(appDatabaseProvider)
            .roundDao
            .save(
              const Round(
                name: 'Saved round',
                totalMeters: 1,
                metersLeft: 1,
                meters: [
                  MeterSummary(
                    id: 'M-0',
                    address: '1 Saved Street',
                    meterNumber: 'KW-1',
                    status: MeterStatus.due,
                  ),
                ],
              ),
              fetchedAt: DateTime.utc(2026, 11, 22, 8),
            ),
      );
      await tester.pump(const Duration(milliseconds: 100));

      // The server is still working on it: the saved list is on screen.
      expect(find.text('Saved round'), findsOneWidget);
      expect(find.text('1 Saved Street'), findsOneWidget);

      await tester.pump(const Duration(seconds: 10));
      await tester.pump();
      expect(find.text('Round 7 · Kwanele Ext 4'), findsOneWidget);
    });

    testWidgets('a failed update keeps the list and says when it was fresh', (
      tester,
    ) async {
      final server = _server();
      final app = await pumpMeterRead(tester, server: server);
      expect(find.text('2 Lwandle Street'), findsOneWidget);

      server.online = false;
      unawaited(app.container.read(roundSyncProvider.notifier).refresh());
      // The list shows, so nothing animates: step past the retries (200,
      // 400 and 800 ms) by hand.
      await tester.pump(const Duration(seconds: 3));
      await tester.pump();

      expect(find.text('2 Lwandle Street'), findsOneWidget);
      expect(find.textContaining("Couldn't update the list"), findsOneWidget);
      expect(find.textContaining('Last updated'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('a reading keeps one Idempotency-Key through every retry', (
      tester,
    ) async {
      final server = _server();
      final app = await pumpMeterRead(
        tester,
        server: server,
        deepLink: '/round/meters/M-1007',
      );

      // M-1007: the first POST reaches the server, the answer is lost.
      await tester.enterText(find.byType(TextField), '30 900');
      await tester.tap(find.text('Save reading'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Not sent yet'), findsOneWidget);
      final key = await tester.runAsync(
        () => app.container
            .read(appDatabaseProvider)
            .outboxDao
            .readFor('M-1007')
            .then((r) => r?.idempotencyKey),
      );
      expect(key, isNotNull);

      await tester.tap(find.byTooltip('Send now'));
      await tester.pumpAndSettle();

      // Same key: the server answered again, and stored one reading.
      expect(server.readingsFor('M-1007'), hasLength(1));
      expect(find.textContaining('Not sent yet'), findsNothing);
    });

    testWidgets('a reading with no signal waits, with its key', (tester) async {
      final server = _server();
      final app = await pumpMeterRead(
        tester,
        server: server,
        deepLink: '/round/meters/M-1001',
      );
      server.online = false;

      await tester.enterText(find.byType(TextField), '48590');
      await tester.tap(find.text('Save reading'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Not sent yet: 48'), findsOneWidget);
      expect(find.text('Waiting for signal.'), findsOneWidget);
      final waiting = await tester.runAsync(
        () =>
            app.container.read(appDatabaseProvider).outboxDao.readFor('M-1001'),
      );
      expect(waiting?.idempotencyKey, isNotNull);

      server.online = true;
      await tester.tap(find.byTooltip('Send now'));
      await tester.pumpAndSettle();
      expect(server.readingsFor('M-1001'), hasLength(1));
    });
  });

  group('forms, lists and words (day 4)', () {
    testWidgets('all 14 meters load, not just the first 10', (tester) async {
      final app = await pumpMeterRead(tester);

      final round = app.container.read(roundSyncProvider).snapshot!.value;
      expect(round.meters, hasLength(14));
      await _scrollTo(tester, find.text('21 Umthombo Road'));
      expect(find.text('21 Umthombo Road'), findsOneWidget);
    });

    testWidgets('"48 590" is stored as the whole number 48590', (tester) async {
      final server = _server();
      await pumpMeterRead(
        tester,
        server: server,
        deepLink: '/round/meters/M-1001',
      );

      await tester.enterText(find.byType(TextField), '48 590');
      await tester.tap(find.text('Save reading'));
      await tester.pumpAndSettle();

      final stored = server.readingsFor('M-1001').single['value'];
      expect(stored, isA<int>());
      expect(stored, 48590);
    });

    testWidgets("the server's refusal shows under the field, input kept", (
      tester,
    ) async {
      final server = _server();
      await pumpMeterRead(
        tester,
        server: server,
        deepLink: '/round/meters/M-1001',
      );

      await tester.enterText(find.byType(TextField), '100');
      await tester.tap(find.text('Save reading'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('lower than the last reading'),
        findsOneWidget,
      );
      expect(find.text('100'), findsOneWidget);
      expect(server.readingsFor('M-1001'), isEmpty);
      expect(find.textContaining('Not sent yet'), findsNothing);
    });

    testWidgets('an empty field asks for a reading', (tester) async {
      await pumpMeterRead(tester, deepLink: '/round/meters/M-1001');

      await tester.tap(find.text('Save reading'));
      await tester.pumpAndSettle();

      expect(find.text('Enter the reading.'), findsOneWidget);
    });

    testWidgets('"11 meters left" in English and isiZulu', (tester) async {
      await pumpMeterRead(tester);
      expect(find.text('11 meters left'), findsOneWidget);
    });

    testWidgets('isiZulu says it in isiZulu', (tester) async {
      await pumpMeterRead(tester, locale: const Locale('zu'));
      expect(find.text('Kusele amamitha angu-11'), findsOneWidget);
    });

    test('plurals: none, one, many', () {
      final en = lookupAppLocalizations(const Locale('en'));
      expect(en.metersLeft(0), 'No meters left');
      expect(en.metersLeft(1), '1 meter left');
      expect(en.metersLeft(11), '11 meters left');
      final zu = lookupAppLocalizations(const Locale('zu'));
      expect(zu.metersLeft(1), isNot(zu.metersLeft(11)));
      expect(zu.metersLeft(11), contains('11'));
    });

    testWidgets('every status is in words, not only a colour', (tester) async {
      await pumpMeterRead(tester);
      expect(find.textContaining('· Due'), findsWidgets);
      expect(find.textContaining('· Read'), findsWidgets);
    });

    testWidgets('the round screen meets the accessibility guidelines', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpMeterRead(tester);

      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });

    testWidgets('the meter screen meets the accessibility guidelines', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpMeterRead(tester, deepLink: '/round/meters/M-1001');

      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  });
}
