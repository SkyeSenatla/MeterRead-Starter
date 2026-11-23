import 'package:flutter/material.dart';
import 'package:meterread/app/failure_text.dart';
import 'package:meterread/core/network/failure.dart';
import 'package:meterread/l10n/app_localizations.dart';

/// A whole-screen failure: what went wrong in the reader's words, the
/// reference when it's the server's fault, and a way to try again.
class FailureView extends StatelessWidget {
  /// Creates the view for [error], whatever the data layer threw.
  const new({required this.error, required this.onRetry, super.key});

  /// What failed. It's turned into a [Failure] here.
  final Object error;

  /// Asks again.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final failure = toFailure(error);
    final reference = failure.reference;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              failure.message(l10n),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (reference != null) ...[
              const SizedBox(height: 8),
              Text(
                l10n.failureReference(reference),
                textAlign: TextAlign.center,
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
