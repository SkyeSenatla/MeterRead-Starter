# Bug hunt

Eight short snippets, each with at least one bug from Week 11. For each, write
**what breaks, and for whom**, and **the fix**, in a line each.

## 1

```dart
Duration? retryPolicy(int retryCount, Object error) =>
    retryCount < 3 ? Duration(milliseconds: 200 * (1 << retryCount)) : null;
```

What breaks:

The fix:

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

What breaks:

The fix:

## 6

```dart
try {
  final pair = await api.refresh(stored);
  await keep(pair);
} on DioException {
  await auth.signOut();          // wipes the tokens and the database
}
```

What breaks:

The fix:

## 7

```dart
Future<void> send(PendingReading pending) => dio.post<void>(
  '/meters/${pending.meterId}/readings',
  data: {'value': pending.value},
  options: Options(headers: {'Idempotency-Key': const Uuid().v4()}),
);
```

What breaks:

The fix:

## 8

```dart
Text(left == 1 ? '1 meter left' : '$left meters left'),
```

What breaks:

The fix:
