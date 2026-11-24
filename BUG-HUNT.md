# Bug hunt

Eight short snippets, each with at least one bug from Week 11. For each, write
**what breaks, and for whom**, and **the fix**, in a line each.

## 1

```dart
Duration? retryPolicy(int retryCount, Object error) =>
    retryCount < 3 ? Duration(milliseconds: 200 * (1 << retryCount)) : null;
```

What breaks: this will pick any error and do a retry 

The fix: with this code we can specify what errors can be seen as trigger to retry 

Duration? retryPolicy(int retryCount, Object error) {
  if (retryCount >= 3) return null;
  final transient = error is DioException &&
      (error.type == DioExceptionType.connectionTimeout ||
       error.type == DioExceptionType.receiveTimeout ||
       error.type == DioExceptionType.connectionError ||
       (error.response?.statusCode ?? 0) >= 500);
  return transient ? Duration(milliseconds: 200 * (1 << retryCount)) : null;
}

## 2

```dart
AsyncError(:final error) => Center(child: Text('$error')),
```

What breaks: Auser will the exact type of error the app is having 

The fix:
AsyncError(:final error) => Center(
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(failureFrom(error).message), // friendly, no internals
      FilledButton(
        onPressed: () => ref.invalidate(meterProvider),
        child: const Text('Try again'),
      ),
    ],
  ),
),

## 3

```dart
try {
  final (meter, history) = await (api.meter(id), api.history(id)).wait;
  return MeterView(meter, history);
} on DioException catch (error) {
  throw failureFrom(error);
}
```

What breaks: doesn't rethrow the original DioException

The fix:
try {
  final (meter, history) = await (api.meter(id), api.history(id)).wait;
  return MeterView(meter, history);
} on ParallelWaitError<dynamic, dynamic> catch (e) {
  final cause = e.errors.$1?.error ?? e.errors.$2?.error;
  if (cause is DioException) throw failureFrom(cause);
  rethrow;
}
## 4

```dart
final prefs = await SharedPreferences.getInstance();
await prefs.setString('refresh_token', pair.refreshToken);
await prefs.setString('access_token', pair.accessToken);
```

What breaks: not secure

The fix: store the tokens in flutter_secure_storage, which uses the Keychain on iOS and Keystore-backed encryption on Android

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

The fix: make sure the handler is always called, share one in-flight refresh among all callers, and use a separate Dio for the refresh call.

Future<TokenPair>? _refreshing;

@override
Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
  if (err.response?.statusCode != 401 || err.requestOptions.extra['retried'] == true) {
    return handler.next(err);
  }
  try {
    _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
    final pair = await _refreshing!;
    final opts = err.requestOptions
      ..headers['Authorization'] = 'Bearer ${pair.accessToken}'
      ..extra['retried'] = true;
    handler.resolve(await plainDio.fetch(opts)); // plainDio has no interceptor
  } on DioException catch (e) {
    handler.reject(e);
  }
}
## 7

```dart
Future<void> send(PendingReading pending) => dio.post<void>(
  '/meters/${pending.meterId}/readings',
  data: {'value': pending.value},
  options: Options(headers: {'Idempotency-Key': const Uuid().v4()}),
);
```

What breaks:  the key is generated inside send, so every call gets a fresh UUID. A retry is the case idempotency keys exist for. Say the first request reaches the server and is saved, but the response is lost to a timeout or a dropped connection. The retry then goes out with a different key, so the server treats it as a new reading and saves it again.

The fix:
generate the key once, when the reading is created, and store it on PendingReading. Every attempt for that reading then sends the same key.

class PendingReading {
  PendingReading({required this.meterId, required this.value})
      : idempotencyKey = const Uuid().v4(); // created once, saved with the row
  // ...
}

Future<void> send(PendingReading pending) => dio.post<void>(
  '/meters/${pending.meterId}/readings',
  data: {'value': pending.value},
  options: Options(headers: {'Idempotency-Key': pending.idempotencyKey}),
);
## 8

```dart
Text(left == 1 ? '1 meter left' : '$left meters left'),
```

What breaks:The text is not localized, so users in other languages see English.

The fix:use ICU plural messages through intl / ARB localization, so each locale defines its own plural rules.



