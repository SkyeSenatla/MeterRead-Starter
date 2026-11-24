import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// A reading in whole kWh, as the municipality writes it: 48 213.
String formatKwh(int kwh) => NumberFormat(
  '#,##0',
  'en_ZA',
).format(kwh).replaceAll(RegExp(r'[,\u00a0\u202f]'), ' ');

/// A calendar day in the app's language: 23 Oct 2026.
String formatDay(BuildContext context, DateTime day) => DateFormat(
  'd MMM y',
  Localizations.localeOf(context).toString(),
).format(day);
