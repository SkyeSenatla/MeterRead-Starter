import 'package:meterread/core/network/failure.dart';
import 'package:meterread/l10n/app_localizations.dart';

/// A [Failure] in the reader's words.
extension FailureText on Failure {
  /// What went wrong, without the reference.
  String message(AppLocalizations l10n) => switch (this) {
    NoSignal() => l10n.failureNoSignal,
    FieldErrors(:final errors) =>
      errors.values.expand((messages) => messages).firstOrNull ??
          l10n.failureServer,
    SessionEnded() => l10n.failureSessionEnded,
    NotFound() => l10n.failureMeterNotFound,
    ServerFault() => l10n.failureServer,
  };

  /// The server's reference, when it's the server's fault and it sent one.
  String? get reference => switch (this) {
    ServerFault(:final reference) => reference,
    _ => null,
  };

  /// The message and the reference on one line, for a snack bar.
  String summary(AppLocalizations l10n) {
    final text = message(l10n);
    final ref = reference;
    return ref == null ? text : '$text ${l10n.failureReference(ref)}';
  }
}
