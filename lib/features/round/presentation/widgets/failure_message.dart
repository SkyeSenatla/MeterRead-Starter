import 'package:flutter/material.dart';
import 'package:meterread/core/failure/failure.dart';
import 'package:meterread/l10n/app_localizations.dart';

/// Reader-friendly failure copy shared by sign-in, round and meter screens.
String failureMessage(AppLocalizations l10n, Failure failure) =>
    switch (failure) {
      NoSignalFailure() => l10n.noSignal,
      FieldFailure() => l10n.checkReading,
      SignedOutFailure() => l10n.signInIncorrect,
      NotFoundFailure() => l10n.meterNotFound,
      ServerFailure() => l10n.serverError,
      UnexpectedFailure() => l10n.unexpectedError,
    };

/// A translated message and a labelled, tappable retry action.
class FailureMessage extends StatelessWidget {
  const new({required this.failure, required this.onRetry, super.key});

  final Failure failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(failureMessage(l10n, failure), textAlign: TextAlign.center),
              if (failure case ServerFailure(:final traceId?)) ...[
                const SizedBox(height: 8),
                SelectableText(l10n.errorReference(traceId)),
              ],
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: Text(l10n.tryAgain)),
            ],
          ),
        ),
      ),
    );
  }
}
