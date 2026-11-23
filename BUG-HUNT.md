# Bug hunt

Eight short snippets, each with at least one bug from Week 11. For each, write
**what breaks, and for whom**, and **the fix**, in a line each.

## 1

```dart
Duration? retryPolicy(int retryCount, Object error) =>
    retryCount < 3 ? Duration(milliseconds: 200 * (1 << retryCount)) : null;
```

What breaks: The retryPoliy, for the program. It shouldn't allow the user to keep retrying if there's a problem with their request

The fix: Making sure we only retry successful HTTP requests

## 2

```dart
AsyncError(:final error) => Center(child: Text('$error')),
```

What breaks: Text('$error'), exposes the program

The fix: The error should have a status code instead of revealing the backend stuff. Basically private things. Also a descriptive text would be great.

## 3

```dart
try {
  final (meter, history) = await (api.meter(id), api.history(id)).wait;
  return MeterView(meter, history);
} on DioException catch (error) {
  throw failureFrom(error);
}
```

What breaks: When one request fails it might affect the whole outcome of the requests.

The fix: Introducing a condition where as a failed request doesnt affect the successful one. The meter and history should have their own tries separately.

## 4

```dart
final prefs = await SharedPreferences.getInstance();
await prefs.setString('refresh_token', pair.refreshToken);
await prefs.setString('access_token', pair.accessToken);
```

What breaks: Exposing a user's token, for the program. ANother user's will get to see someone else's token which is not great

The fix: Making the tokens go into a secure file not be exposed.

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

What breaks: There would be a lot of tokens for each request and it would be impossible to be traced back.

The fix: Letting all the request use one token instead of using multiple. 

## 6

```dart
try {
  final pair = await api.refresh(stored);
  await keep(pair);
} on DioException {
  await auth.signOut();          // wipes the tokens and the database
}
```

What breaks: Losing all the data that the meter was supposed to get. The user would have to start over the entire proesss

The fix: Making the database be available offline so that requests can still be processed when the app goes offline. So that the user is able to continue where they left off.

## 7

```dart
Future<void> send(PendingReading pending) => dio.post<void>(
  '/meters/${pending.meterId}/readings',
  data: {'value': pending.value},
  options: Options(headers: {'Idempotency-Key': const Uuid().v4()}),
);
```

What breaks: The program might read a retried as the value and then work on the wrong value because maybe connection got lost.

The fix: Making sure the program checks for retries to see if anything changes before it continues doing what the request needs. 

## 8

```dart
Text(left == 1 ? '1 meter left' : '$left meters left'),
```

What breaks: The desired language wont displayed because nothing of the other language is linked on the code.

The fix: Linking the language to the code where it translate from English to isiZulu.
