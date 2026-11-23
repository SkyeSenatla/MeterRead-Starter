import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meterread/app/router/router_provider.dart';
import 'package:meterread/l10n/app_localizations.dart';

/// The app: the router, the theme, and the languages.
class MeterReadApp extends ConsumerWidget {
  /// Creates the app.
  const new({super.key});

  /// Kwanele green: the seed every colour role grows from.
  static const seed = Color(0xFF2E6B3F);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: seed),
      darkTheme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.dark),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
