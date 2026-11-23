import 'package:meterread/core/failures/failure.dart';

/// When Riverpod may retry a provider that failed. Keep this name: main()
/// and the test harness both use it.
///
Duration? appRetryPolicy(int retryCount, Object error) {
  if (error is! NoSignalFailure || retryCount >= 3) return null;
  return Duration(milliseconds: 200 * (1 << retryCount));
}
