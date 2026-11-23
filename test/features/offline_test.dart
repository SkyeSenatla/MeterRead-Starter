import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

void main() {
  testWidgets('a lost answer is stored once', (tester) async {
    final h = await pumpMeterRead(tester, location: '/round/meters/M-1007');
    final first = await outbox.save('M-1007', 31250, false);
    expect(first, isNull);
    final rowId =
        (await h.container.read(outboxDaoProvider).allWaiting()).single.id;
    await outbox.sendOne(rowId);
    expect(h.server.readingsFor('M-1007').length, 1);
  });

  testWidgets('sign-out leaves nothing', (tester) async {
    final h = await pumpMeterRead(tester, location: '/round');
    await h.container.read(outboxServiceProvider).save('M-1007', 31250, false);
    await h.container.read(sessionWiperProvider).wipe();
    expect(await h.tokens.readRefresh(), isNull);
    expect(h.tokens.access, isNull);
    final db = h.container.read(appDatabaseProvider);
    for (final t in db.allTables) {
      expect(await db.select(t).get(), isEmpty, reason: t.actualTableName);
    }
  });
}
