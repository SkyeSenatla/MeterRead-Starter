import 'package:meterread/core/error/failure.dart';

/// When Riverpod may retry a provider that failed. Keep this name: main()
/// and the test harness both use it.
///
/// Only when there was no answer at all (no signal, a timeout): three tries,
/// 200 ms, 400 ms and 800 ms apart. A 400, 404 or 500 is an answer, and
/// asking again gets the same one. Saves never come through here: they go
/// through the outbox, and are sent again only by the reader.
Duration? appRetryPolicy(int retryCount, Object error) {
  if (retryCount >= 3) return null;
  if (!failureFrom(error).retryable) return null;
  return Duration(milliseconds: 200 * (1 << retryCount));
}
