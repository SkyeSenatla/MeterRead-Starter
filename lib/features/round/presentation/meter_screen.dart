import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meterread/app/format.dart';
import 'package:meterread/core/error/failure.dart';
import 'package:meterread/core/error/failure_view.dart';
import 'package:meterread/core/fakes/test_tools.dart';
import 'package:meterread/features/round/domain/meter.dart';
import 'package:meterread/features/round/presentation/reading_form.dart';
import 'package:meterread/features/round/presentation/round_providers.dart';
import 'package:meterread/features/round/presentation/status_words.dart';
import 'package:meterread/l10n/app_localizations.dart';

/// One meter: what the server knows about it, and the reading form while
/// it's due.
class MeterScreen extends ConsumerWidget {
  /// Creates the screen for [meterId].
  const new({required this.meterId, super.key});

  /// `M-1001`.
  final String meterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: Text(meterId), actions: const [TestToolsButton()]),
      body: switch (ref.watch(meterDetailProvider(meterId))) {
        AsyncValue(:final value?) => _MeterBody(meter: value),
        AsyncError(:final error) => FailureView(
          failure: failureFrom(error),
          onRetry: () => ref.invalidate(meterDetailProvider(meterId)),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _MeterBody extends ConsumerWidget {
  const new({required this.meter});

  final Meter meter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    final pending = ref.watch(pendingReadingProvider(meter.id)).value;
    final saving = ref.watch(savingReadingProvider(meter.id));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(meter.address, style: text.titleLarge),
        Text(l10n.meterAndAccount(meter.meterNumber, meter.accountNumber)),
        const SizedBox(height: 8),
        Text(statusWord(l10n, meter.status), style: text.titleMedium),
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
        // While the form is saving, it stays: a refusal shows under its field.
        if (pending != null && !saving)
          Card(
            child: ListTile(
              title: Text(l10n.notSentYet(formatKwh(pending.value))),
              subtitle: switch (Failure.decode(pending.lastError)) {
                null => null,
                final failure => Text(_whyNotSent(l10n, failure)),
              },
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: l10n.sendNow,
                    icon: const Icon(Icons.send),
                    onPressed: () => _sendNow(context, ref),
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.read(readingOutboxProvider).discard(meter.id),
                    child: Text(l10n.discard),
                  ),
                ],
              ),
            ),
          )
        else if (meter.status == MeterStatus.due)
          ReadingForm(meterId: meter.id),
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

  Future<void> _sendNow(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final container = ProviderScope.containerOf(context, listen: false);
    try {
      final accepted = await container
          .read(readingOutboxProvider)
          .send(meter.id);
      if (accepted != null) {
        container.invalidate(meterDetailProvider(meter.id));
        unawaited(container.read(roundSyncProvider.notifier).refresh());
      }
    } on Object catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(failureFrom(error).words(l10n))),
      );
    }
  }

  static String _whyNotSent(AppLocalizations l10n, Failure failure) =>
      switch (failure) {
        NoSignal() => l10n.pendingNoSignal,
        ServerCrash(:final reference) =>
          reference == null
              ? l10n.pendingServer
              : '${l10n.pendingServer} ${l10n.pendingReference(reference)}',
        _ => failure.words(l10n),
      };
}
