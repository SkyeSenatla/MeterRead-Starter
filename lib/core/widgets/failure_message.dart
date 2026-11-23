import 'package:flutter/material.dart';
import 'package:meterread/core/failures/failure.dart';
import 'package:meterread/l10n/app_localizations.dart';

class FailureMessage extends StatelessWidget {
  /// Creates an inline failure message.
  const FailureMessage({
    required this.error,
    this.onRetry,
    this.notFoundText,
    this.signingIn = false,
    super.key,
  });
  final Object error;
  final VoidCallback? onRetry;
  final String? notFoundText;
  final bool signingIn;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final failure = error is Failure
        ? error as Failure
        : const UnexpectedFailure();
    final message = switch (failure) {
      NoSignalFailure() => l10n.noSignal,
      ValidationFailure() => l10n.validationFailed,
      SignedOutFailure() => signingIn ? l10n.signInMismatch : l10n.signedOut,
      NotFoundFailure() => notFoundText ?? l10n.notFound,
      ServerFailure() => l10n.serverFault,
      UnexpectedFailure() => l10n.unexpectedFailure,
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(liveRegion: true, child: Text(message)),
        if (failure.reference case final reference?)
          SelectableText(l10n.failureReference(reference)),
        if (onRetry != null) ...[
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: Text(l10n.tryAgain)),
        ],
      ],
    );
  }
}
