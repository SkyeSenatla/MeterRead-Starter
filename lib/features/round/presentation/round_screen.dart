import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:meterread/app/failure_view.dart';
import 'package:meterread/app/router/routes.dart';
import 'package:meterread/core/fakes/test_tools.dart';
import 'package:meterread/features/auth/presentation/auth_controller.dart';
import 'package:meterread/features/round/domain/meter.dart';
import 'package:meterread/features/round/presentation/round_providers.dart';
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
      body: switch (ref.watch(roundProvider)) {
        AsyncData(:final value) => _RoundList(round: value),
        AsyncError(:final error) => FailureView(
          error: error,
          onRetry: () => ref.invalidate(roundProvider),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _RoundList extends StatelessWidget {
  const new({required this.round});

  final Round round;

  @override
  Widget build(BuildContext context) {
    final left = round.metersLeft;
    return ListView(
      children: [
        ListTile(
          title: Text(round.name),
          subtitle: Text(left == 1 ? '1 meter left' : '$left meters left'),
        ),
        const Divider(height: 1),
        for (final meter in round.meters)
          ListTile(
            leading: _StatusIcon(status: meter.status),
            title: Text(meter.address),
            subtitle: Text(meter.meterNumber),
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
