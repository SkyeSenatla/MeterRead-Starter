import 'package:flutter/material.dart';
import 'package:meterread/core/error/failure.dart';
import 'package:meterread/l10n/app_localizations.dart';

/// A [Failure] in the reader's words.
extension FailureWords on Failure {
  /// Friendly, in the app's language, and never the exception's own text.
  String words(AppLocalizations l10n) => switch (this) {
    NoSignal() => l10n.failureNoSignal,
    NotFound() => l10n.failureNotFound,
    ServerCrash() => l10n.failureServer,
    InvalidInput(:final message) => message ?? l10n.failureInput,
    SessionEnded() => l10n.failureSignedOut,
    Unexpected() => l10n.failureUnexpected,
  };
}

/// What every screen shows when it can't load: a friendly message, the
/// reference when the server is at fault, and a "Try again" button.
class FailureView extends StatelessWidget {
  /// Creates the view for [failure]; [onRetry] asks again.
  const new({required this.failure, required this.onRetry, super.key});

  /// What went wrong.
  final Failure failure;

  /// Called by the "Try again" button.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final text = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              failure.words(l10n),
              textAlign: TextAlign.center,
              style: text.titleMedium,
            ),
            if (failure case ServerCrash(:final reference?)) ...[
              const SizedBox(height: 8),
              SelectableText(
                l10n.failureReference(reference),
                textAlign: TextAlign.center,
                style: text.bodySmall,
              ),
            ],
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: Text(l10n.tryAgain)),
          ],
        ),
      ),
    );
  }
}
