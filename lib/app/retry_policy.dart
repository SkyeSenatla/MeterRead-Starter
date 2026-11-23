/// When Riverpod may retry a provider that failed. Keep this name: main()
/// and the test harness both use it.
///
/// Three tries, 200 ms, 400 ms and 800 ms apart.
Duration? appRetryPolicy(int retryCount, Object error) {
  if (retryCount >= 3) return null;
  return Duration(milliseconds: 200 * (1 << retryCount));
}
