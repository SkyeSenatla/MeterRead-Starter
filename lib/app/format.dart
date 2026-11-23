import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// A reading in whole kWh, as the municipality writes it: 48 213.
String formatKwh(int kwh) => NumberFormat('#,##0', 'en_ZA').format(kwh);

/// A calendar day in the app's language: 23 Oct 2026.
String formatDay(BuildContext context, DateTime day) => DateFormat(
  'd MMM y',
  Localizations.localeOf(context).toString(),
).format(day);

/// A moment in the app's language, to the minute: 23 Oct 2026, 14:05.
String formatWhen(BuildContext context, DateTime moment) => DateFormat(
  'd MMM y, HH:mm',
  Localizations.localeOf(context).toString(),
).format(moment);

/// A reading as the worker typed it ("48 590", "48590", "48\u00a0590"), or
/// null when it isn't whole digits. Whole kWh: never a double.
int? parseReading(String text) {
  final digits = text.replaceAll(RegExp(r'[\s\u00a0\u202f]'), '');
  if (digits.isEmpty || digits.length > 9) return null;
  return RegExp(r'^[0-9]+$').hasMatch(digits) ? int.parse(digits) : null;
}
