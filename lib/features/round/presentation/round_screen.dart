import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:meterread/app/database/app_database.dart';
import 'package:meterread/app/router/routes.dart';
import 'package:meterread/core/cache/snapshot.dart';
import 'package:meterread/core/failure/failure.dart';
import 'package:meterread/core/fakes/test_tools.dart';
import 'package:meterread/features/auth/presentation/auth_controller.dart';
import 'package:meterread/features/round/domain/meter.dart';
import 'package:meterread/features/round/presentation/round_providers.dart';
import 'package:meterread/features/round/presentation/widgets/failure_message.dart';
import 'package:meterread/l10n/app_localizations.dart';

/// Cache-first list: show saved data immediately, then refresh in background.
class RoundScreen extends ConsumerWidget {
  const new({super.key});

  Future<void> _refresh(WidgetRef ref) async {
    try {
      await ref.refresh(roundProvider.future);
    } on Object {
      // The error is displayed from the provider; the cache remains.
    }
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final pending = await ref
        .read(appDatabaseProvider)
        .outboxDao
        .waitingCount();
    if (!context.mounted) return;
    if (pending > 0) {
      final l10n = AppLocalizations.of(context);
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.signOut),
          content: Text(l10n.pendingWarning(pending)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(l10n.confirmSignOut),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
    }
    await ref.read(authControllerProvider.notifier).signOut();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    // Watching this starts the background fetch even when cache exists.
    final remote = ref.watch(roundProvider);
    final local = ref.watch(cachedRoundProvider);
    final snapshot = local.value;
    final cached = snapshot?.value;
    final round = cached ?? remote.value;
    final failure = remote.hasError ? failureFrom(remote.error!) : null;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.roundTitle),
        actions: [
          IconButton(
            tooltip: l10n.refreshRound,
            icon: const Icon(Icons.refresh),
            onPressed: () => _refresh(ref),
          ),
          const TestToolsButton(),
          IconButton(
            tooltip: l10n.signOut,
            icon: const Icon(Icons.logout),
            onPressed: () => _signOut(context, ref),
          ),
        ],
      ),
      body: round == null
          ? failure == null
                ? const Center(child: CircularProgressIndicator())
                : FailureMessage(failure: failure, onRetry: () => _refresh(ref))
          : RefreshIndicator(
              onRefresh: () => _refresh(ref),
              child: _RoundList(
                round: round,
                snapshot: snapshot,
                failure: failure,
                retry: () => _refresh(ref),
              ),
            ),
    );
  }
}

class _RoundList extends StatelessWidget {
  const new({
    required this.round,
    required this.snapshot,
    required this.failure,
    required this.retry,
  });

  final Round round;
  final Snapshot<Round>? snapshot;
  final Failure? failure;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final updated = snapshot == null
        ? null
        : DateFormat('HH:mm').format(snapshot!.fetchedAt.toLocal());
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        ListTile(
          title: Text(round.name),
          subtitle: Text(l10n.metersLeft(round.metersLeft)),
        ),
        if (updated != null || failure != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (failure is NoSignalFailure && updated != null)
                  Text(l10n.offlineUpdated(updated))
                else ...[
                  if (updated != null) Text(l10n.lastUpdated(updated)),
                  if (failure != null) Text(failureMessage(l10n, failure!)),
                ],
                if (failure != null)
                  TextButton(onPressed: retry, child: Text(l10n.tryAgain)),
              ],
            ),
          ),
        const Divider(height: 1),
        for (final meter in round.meters)
          ListTile(
            leading: _StatusIcon(status: meter.status),
            title: Text(meter.address),
            subtitle: Text(
              '${meter.meterNumber} · ${_statusWord(l10n, meter.status)}',
            ),
            onTap: () => MeterRoute(meterId: meter.id).go(context),
          ),
      ],
    );
  }
}

String _statusWord(AppLocalizations l10n, MeterStatus status) =>
    switch (status) {
      MeterStatus.due => l10n.statusDue,
      MeterStatus.read => l10n.statusRead,
      MeterStatus.query => l10n.statusQuery,
      MeterStatus.unknown => l10n.statusUnknown,
    };

class _StatusIcon extends StatelessWidget {
  const new({required this.status});
  final MeterStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return switch (status) {
      MeterStatus.due => Icon(
        Icons.radio_button_unchecked,
        color: colors.outline,
      ),
      MeterStatus.read => Icon(Icons.check_circle, color: colors.primary),
      MeterStatus.query => Icon(Icons.error, color: colors.error),
      MeterStatus.unknown => Icon(Icons.help, color: colors.outline),
    };
  }
}
