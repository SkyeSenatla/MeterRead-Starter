import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meterread/app/app.dart';
import 'package:meterread/app/database/app_database.dart';
import 'package:meterread/app/retry_policy.dart';
import 'package:meterread/core/fakes/meter_server.dart';
import 'package:meterread/core/fakes/meter_server_provider.dart';
import 'package:meterread/core/network/token_store.dart';

import 'in_memory_token_store.dart';

/// What a test gets back from [pumpMeterRead].
typedef MeterReadHarness = ({
  MeterServer server,
  InMemoryTokenStore tokens,
  ProviderContainer container,
});

/// Thandeka's email: her round is Round 7.
const thandeka = 'thandeka@kwanele.test';

/// Sipho's email: his round is Round 8.
const sipho = 'sipho@kwanele.test';

/// Both readers' password, on the pretend server.
const password = 'Kwanele-2026';

/// Pumps the whole app, as main() does, on a meter server with no delay
/// (or [server]), a database in memory and a token store in memory.
///
/// [signedInAs] starts the app with a stored session for that reader, as if
/// they had signed in yesterday; null starts signed out. [deepLink] is the
/// address the app opens at. Don't change this file: your instructor's
/// checks use it too.
Future<MeterReadHarness> pumpMeterRead(
  WidgetTester tester, {
  MeterServer? server,
  String? signedInAs = thandeka,
  String? deepLink,
  Locale locale = const Locale('en'),
  Size size = const Size(400, 800),
  double textScale = 1,
  bool settle = true,
}) async {
  final meterServer = server ?? MeterServer(latency: Duration.zero);
  final tokens = InMemoryTokenStore(
    signedInAs == null ? null : meterServer.issueRefreshTokenFor(signedInAs),
  );

  tester.view
    ..physicalSize = size
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher
    ..localesTestValue = [locale]
    ..localeTestValue = locale
    ..textScaleFactorTestValue = textScale;
  if (deepLink != null) {
    tester.platformDispatcher.defaultRouteNameTestValue = deepLink;
  }
  addTearDown(tester.platformDispatcher.clearAllTestValues);

  final container = ProviderContainer(
    overrides: [
      meterServerProvider.overrideWithValue(meterServer),
      tokenStoreProvider.overrideWithValue(tokens),
      appDatabaseProvider.overrideWith((ref) {
        final database = memoryDatabase();
        ref.onDispose(database.close);
        return database;
      }),
    ],
    retry: appRetryPolicy,
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MeterReadApp(),
    ),
  );
  if (settle) await tester.pumpAndSettle();
  return (server: meterServer, tokens: tokens, container: container);
}

/// The app's database in memory: real SQLite, nothing on disk.
AppDatabase memoryDatabase() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  // Drift keeps a cancelled stream alive for one zero-length timer; a
  // widget test fails on a timer still pending at its end.
  return AppDatabase(
    DatabaseConnection(
      NativeDatabase.memory(),
      closeStreamsSynchronously: true,
    ),
  );
}

/// Every row in every table of the app's database.
Future<int> rowsInDatabase(WidgetTester tester, ProviderContainer container) =>
    tester
        .runAsync(() async {
          final database = container.read(appDatabaseProvider);
          var rows = 0;
          for (final table in database.allTables) {
            rows += (await database.select(table).get()).length;
          }
          return rows;
        })
        .then((rows) => rows ?? -1);
