import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

void main() {
  testWidgets('a stored session opens on the round', (tester) async {
    await pumpMeterRead(tester);

    expect(find.text('Round 7 · Kwanele Ext 4'), findsOneWidget);
    expect(find.text('2 Lwandle Street'), findsOneWidget);
  });

  testWidgets('signed out, the reader can sign in', (tester) async {
    await pumpMeterRead(tester, signedInAs: null);

    await tester.enterText(find.bySemanticsLabel('Email'), thandeka);
    await tester.enterText(find.bySemanticsLabel('Password'), password);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text("Today's round"), findsOneWidget);
  });

  testWidgets('a meter shows its last reading', (tester) async {
    await pumpMeterRead(tester, deepLink: '/round/meters/M-1001');

    expect(find.text('2 Lwandle Street'), findsOneWidget);
    expect(find.textContaining('Last reading 48'), findsOneWidget);
  });
}
