import 'package:meterread/features/round/domain/meter.dart';
import 'package:meterread/l10n/app_localizations.dart';

/// A meter's status in words, so it never rests on a colour or an icon.
String statusWord(AppLocalizations l10n, MeterStatus status) =>
    switch (status) {
      MeterStatus.due => l10n.statusDue,
      MeterStatus.read => l10n.statusRead,
      MeterStatus.query => l10n.statusQuery,
      MeterStatus.unknown => l10n.statusUnknown,
    };
