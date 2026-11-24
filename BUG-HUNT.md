# Bug hunt — Week 11

1. **Retry policy:** It retries every failure, including validation errors, 404s and 500s, wasting requests and misleading readers. **Fix:** Retry only requests which received no HTTP answer; stop after three retries.
2. **Raw error on a screen:** A meter reader sees `DioException` instead of a useful explanation and retry action. **Fix:** Map errors to a sealed `Failure` in the data layer, translate the message, and show a labelled Try again button.
3. **Parallel requests:** `Record.wait` throws `ParallelWaitError`, not `DioException`; a meter's error bypasses the mapper. **Fix:** Catch `Object` and use `failureFrom`, which unwraps both members of a parallel failure.
4. **Preferences tokens:** Refresh and access tokens are written to ordinary preferences, exposing sensitive tokens and persisting short-lived access tokens. **Fix:** Keep the refresh token in `flutter_secure_storage` and access token in memory only.
5. **Simultaneous refresh:** Two 401s refresh with the same one-use token; the second revokes the whole session. **Fix:** Queue error handling and compare the failed request's token with the latest one, refreshing only once.
6. **Offline restoration:** No signal at launch is treated like a revoked session, wiping a legitimate reader's round and login. **Fix:** Only clear the session if refresh receives 401; keep the stored token and offer Try again on network failure.
7. **Idempotency per attempt:** Each send creates another key, so retrying a lost response records the same reading twice and marks the meter Query. **Fix:** Generate the key on Save, persist it in the outbox and reuse it for every attempt.
8. **Hand-coded plural:** English strings don't use ICU; the same code cannot localize correctly to isiZulu or handle a finished round. **Fix:** Add one ICU plural message per ARB, including the expected isiZulu zero form.
