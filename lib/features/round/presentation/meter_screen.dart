import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meterread/app/format.dart';
import 'package:meterread/core/failure/failure.dart';
import 'package:meterread/core/fakes/test_tools.dart';
import 'package:meterread/features/round/domain/meter.dart';
import 'package:meterread/features/round/presentation/reading_form.dart';
import 'package:meterread/features/round/presentation/round_providers.dart';
import 'package:meterread/features/round/presentation/widgets/failure_message.dart';
import 'package:meterread/l10n/app_localizations.dart';

class MeterScreen extends ConsumerWidget {
  const new({required this.meterId, super.key});
  final String meterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(meterId), actions: const [TestToolsButton()]),
      body: switch (ref.watch(meterDetailProvider(meterId))) {
        AsyncData(:final value) => _MeterBody(meter: value),
        AsyncError(:final error) => FailureMessage(
          failure: failureFrom(error),
          onRetry: () => ref.invalidate(meterDetailProvider(meterId)),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _MeterBody extends StatelessWidget {
  const new({required this.meter});
  final Meter meter;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(meter.address, style: text.titleLarge),
        Text(l10n.meterAndAccount(meter.meterNumber, meter.accountNumber)),
        const SizedBox(height: 8),
        Text(_statusWord(l10n, meter.status), style: text.titleMedium),
        Text(
          l10n.lastReading(
            formatKwh(meter.lastReading),
            formatDay(context, meter.lastReadOn),
          ),
        ),
        if (meter.thisCycle case final reading?) ...[
          Text(
            l10n.thisCycle(
              formatKwh(reading.value),
              formatKwh(reading.consumption),
            ),
          ),
          if (reading.flagged) Text(l10n.flagged),
        ] else if (meter.status != MeterStatus.due)
          Text(l10n.readThisCycle),
        if (meter.status == MeterStatus.query) Text(l10n.queryExplained),
        const SizedBox(height: 16),
        if (meter.status == MeterStatus.due) ReadingForm(meterId: meter.id),
        const SizedBox(height: 16),
        Text(l10n.earlierReadings, style: text.titleMedium),
        for (final past in meter.history)
          Text(
            l10n.pastReading(
              formatKwh(past.value),
              formatDay(context, past.readOn),
            ),
          ),
      ],
    );
  }

  static String _statusWord(AppLocalizations l10n, MeterStatus status) =>
      switch (status) {
        MeterStatus.due => l10n.statusDue,
        MeterStatus.read => l10n.statusRead,
        MeterStatus.query => l10n.statusQuery,
        MeterStatus.unknown => l10n.statusUnknown,
      };
}
