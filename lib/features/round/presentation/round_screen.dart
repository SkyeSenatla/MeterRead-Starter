import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meterread/app/format.dart';
import 'package:meterread/app/router/routes.dart';
import 'package:meterread/core/cache/snapshot.dart';
import 'package:meterread/core/error/failure.dart';
import 'package:meterread/core/error/failure_view.dart';
import 'package:meterread/core/fakes/test_tools.dart';
import 'package:meterread/features/auth/presentation/auth_controller.dart';
import 'package:meterread/features/round/domain/meter.dart';
import 'package:meterread/features/round/presentation/round_providers.dart';
import 'package:meterread/features/round/presentation/status_words.dart';
import 'package:meterread/l10n/app_localizations.dart';

/// Today's round: every meter the reader visits, in walking order.
class RoundScreen extends ConsumerWidget {
  /// Creates the screen.
  const new({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.roundTitle),
        actions: [
          const TestToolsButton(),
          IconButton(
            tooltip: l10n.signOut,
            icon: const Icon(Icons.logout),
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signOut(),
          ),
        ],
      ),
      body: _body(context, ref),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref) {
    final view = ref.watch(roundSyncProvider);
    final sync = ref.read(roundSyncProvider.notifier);
    return switch (view) {
      // The phone has a round: show it now, whatever the server is doing.
      RoundView(:final snapshot?) => _RoundList(
        snapshot: snapshot,
        refreshing: view.refreshing,
        failure: view.failure,
        onRetry: sync.refresh,
      ),
      RoundView(:final failure?, refreshing: false) => FailureView(
        failure: failure,
        onRetry: sync.refresh,
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

class _RoundList extends StatelessWidget {
  const new({
    required this.snapshot,
    required this.refreshing,
    required this.failure,
    required this.onRetry,
  });

  final Snapshot<Round> snapshot;
  final bool refreshing;
  final Failure? failure;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final round = snapshot.value;
    final updated = formatWhen(context, snapshot.fetchedAt.toLocal());
    return ListView(
      children: [
        ListTile(
          title: Text(round.name),
          subtitle: Text(l10n.metersLeft(round.metersLeft)),
        ),
        if (failure != null && !refreshing)
          MaterialBanner(
            content: Text(l10n.updateFailed(updated)),
            actions: [
              TextButton(onPressed: onRetry, child: Text(l10n.tryAgain)),
            ],
          )
        else
          ListTile(
            dense: true,
            title: Text(refreshing ? l10n.updating : l10n.lastUpdated(updated)),
          ),
        const Divider(height: 1),
        for (final meter in round.meters)
          ListTile(
            leading: _StatusIcon(status: meter.status),
            title: Text(meter.address),
            subtitle: Text(
              l10n.meterStatusLine(
                meter.meterNumber,
                statusWord(l10n, meter.status),
              ),
            ),
            onTap: () => MeterRoute(meterId: meter.id).go(context),
          ),
      ],
    );
  }
}

class _StatusIcon extends StatelessWidget {
  const new({required this.status});

  final MeterStatus status;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    // Decorative: the status is also written in words beside it.
    return ExcludeSemantics(child: _icon(colors));
  }

  Widget _icon(ColorScheme colors) {
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
