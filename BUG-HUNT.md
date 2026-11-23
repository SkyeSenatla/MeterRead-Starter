# Bug hunt

Eight short snippets, each with at least one bug from Week 11. For each, write
**what breaks, and for whom**, and **the fix**, in a line each.

## 1

```dart
Duration? retryPolicy(int retryCount, Object error) =>
    retryCount < 3 ? Duration(milliseconds: 200 * (1 << retryCount)) : null;
```

What breaks: Users with permanent errors, such as invalid credentials or validation failures, experience unnecessary retries and delays.

The fix: Users see raw technical error messages that are confusing and may expose sensitive implementation details.

## 2

```dart
AsyncError(:final error) => Center(child: Text('$error')),
```

What breaks:

The fix:

## 3

```dart
try {
  final (meter, history) = await (api.meter(id), api.history(id)).wait;
  return MeterView(meter, history);
} on DioException catch (error) {
  throw failureFrom(error);
}
```

What breaks:

The fix:

## 4

```dart
final prefs = await SharedPreferences.getInstance();
await prefs.setString('refresh_token', pair.refreshToken);
await prefs.setString('access_token', pair.accessToken);
```

What breaks:

The fix:

## 5

```dart
class SessionInterceptor extends Interceptor {
  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      final pair = await api.refresh(await store.read());
      // ... store the pair, then send the request again
    }
  }
}
```

What breaks: Users making multiple simultaneous requests may trigger competing token refreshes, and requests may hang because the interceptor does not complete the handler.

The fix: Use a single shared refresh operation, prevent infinite refresh loops and ensure every request is resolved, rejected or forwarded through the handler.

## 6

```dart
try {
  final pair = await api.refresh(stored);
  await keep(pair);
} on DioException {
  await auth.signOut();          // wipes the tokens and the database
}
```

What breaks: Users experiencing temporary network or server failures are unnecessarily signed out and lose their locally stored data.

The fix: Only sign out when the refresh token is definitively invalid or revoked; preserve the session and local data during temporary failures.

## 7

```dart
Future<void> send(PendingReading pending) => dio.post<void>(
  '/meters/${pending.meterId}/readings',
  data: {'value': pending.value},
  options: Options(headers: {'Idempotency-Key': const Uuid().v4()}),
);
```

What breaks: Users may submit duplicate meter readings when a request is retried because a new idempotency key is generated every time.

The fix: Generate and persist the idempotency key when the pending reading is created, then reuse it for every retry.

## 8

```dart
Text(left == 1 ? '1 meter left' : '$left meters left'),
```

What breaks: Users speaking other languages receive hardcoded English text that does not respect their language's pluralisation rules.

The fix: Use Flutter localisation with ICU plural messages to handle translated singular and plural forms correctly.
