import 'package:flutter_test/flutter_test.dart';

import '../support/harness.dart';

void main() {
  testWidgets('a meter that is not on the round says so', (tester) async {
    await pumpMeterRead(tester, deepLink: '/round/meters/M-9999');

    expect(find.text('Meter not found.'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.textContaining('DioException'), findsNothing);
  });

  testWidgets('a server fault shows its reference', (tester) async {
    await pumpMeterRead(tester, deepLink: '/round/meters/M-1012');

    expect(find.text('Something went wrong on our side.'), findsOneWidget);
    expect(find.textContaining('Reference 00-4bf92f35'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.textContaining('DioException'), findsNothing);
  });

  testWidgets('no signal says so, and Try again works once it is back', (
    tester,
  ) async {
    final harness = await pumpMeterRead(tester);

    harness.server.online = false;
    await tester.tap(find.text('4 Lwandle Street'));
    await tester.pumpAndSettle();

    expect(find.textContaining('No signal'), findsOneWidget);
    expect(find.textContaining('DioException'), findsNothing);

    harness.server.online = true;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Last reading'), findsOneWidget);
  });

  testWidgets('a wrong password says the email and password do not match', (
    tester,
  ) async {
    await pumpMeterRead(tester, signedInAs: null);

    await tester.enterText(find.bySemanticsLabel('Email'), thandeka);
    await tester.enterText(find.bySemanticsLabel('Password'), 'not-it');
    await tester.tap(find.text('Sign in').last);
    await tester.pumpAndSettle();

    expect(find.text("That email and password don't match."), findsOneWidget);
    expect(find.textContaining('DioException'), findsNothing);
  });
}
