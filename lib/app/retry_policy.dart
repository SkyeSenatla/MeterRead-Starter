import 'package:meterread/core/failure/failure.dart';

/// Only retry requests which received no answer. Never retry a response,
/// especially a write, a validation error or a server fault.
Duration? appRetryPolicy(int retryCount, Object error) {
  if (retryCount >= 3 || failureFrom(error) is! NoSignalFailure) return null;
  return Duration(milliseconds: 200 * (1 << retryCount));
}
