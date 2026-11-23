import 'package:meterread/core/network/failure.dart';

/// When Riverpod may retry a provider that failed. Keep this name: main()
/// and the test harness both use it.
///
/// Only "no answer at all" is retried: three tries, 200 ms, 400 ms and
/// 800 ms apart. Anything the server answered (a 400, 401, 404 or 500)
/// would get the same answer again, so it fails at once.
Duration? appRetryPolicy(int retryCount, Object error) {
  if (retryCount >= 3) return null;
  if (toFailure(error) is! NoSignal) return null;
  return Duration(milliseconds: 200 * (1 << retryCount));
}
