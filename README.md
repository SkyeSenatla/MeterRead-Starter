# MeterRead

An electricity meter reader's app for Kwanele Municipality. The reader signs
in, walks today's round of meters, and captures each meter's reading,
with or without signal.

Week 11 revision challenge starter. The brief is handed out in class.

## Running it

Flutter **3.47.7** (Dart 3.13.5), the same as the Week 11 demo.

```
flutter pub get                  # also generates lib/l10n/app_localizations*.dart
dart run build_runner build      # first run compiles builders: about 2 minutes
flutter run                      # on the emulator
```

`flutter pub get` and `flutter run` print "N untranslated message(s)" for
`zu`. That's expected: messages missing from `app_zu.arb` show in English.

The four CI steps, in CI's order:

```
dart format --output=none --set-exit-if-changed .
dart run build_runner build
dart analyze --fatal-infos
flutter test
```

Sign in as **thandeka@kwanele.test** (Round 7, 14 meters) or
**sipho@kwanele.test** (Round 8, 2 meters). The password for both is
**Kwanele-2026**. These exist only in the pretend server below.

## The backend: `lib/core/fakes/meter_server.dart`

There is no network. `MeterServer` is a Dio `HttpClientAdapter`: your Dio
client sends it real requests and gets real HTTP answers back (status
codes, JSON, ProblemDetails), as from a server, in about 400 ms. **Don't
edit `lib/core/fakes/`**: work with the API as it is. Restarting the app
resets the server, so you'll sign in again.

The flask icon in each app bar opens **Test tools**: **No signal** makes
every request fail before it leaves, as with no signal (a
`DioExceptionType.connectionError`); **Expire access tokens** makes every
access token issued so far stop working at once, as if five minutes had
passed.

Every path is under `https://api.kwanele.test/v1`.

| Call | Answers |
| --- | --- |
| `POST /auth/sign-in` `{email, password}` | 200 `{accessToken, refreshToken, expiresIn, readerName, email}`. Wrong: 401 |
| `POST /auth/refresh` `{refreshToken}` | 200, a new pair. **Each refresh token works once.** Presenting a spent one ends every session that came from it: 401, and the new tokens stop working too |
| `POST /auth/sign-out` `{refreshToken}` | 204. The session is over |
| `GET /round/today?pageToken=` | Today's round, **10 meters a page**: `roundName`, `totalMeters`, `metersLeft`, `meters` (`id`, `address`, `meterNumber`, `status`) and `nextPageToken`. **The last page leaves `nextPageToken` out** |
| `GET /meters/{id}` | One meter: `accountNumber`, `status`, `lastReading` (whole kWh), `lastReadOn` (a date), `thisCycle` (this month's reading, or null) |
| `GET /meters/{id}/readings` | The last three months' readings, newest first |
| `POST /meters/{id}/readings` `{value, meterReplaced}` | 201: the reading as the server stored it, with `consumption` and `flagged`, which **the server works out**. Needs an `Idempotency-Key` header: the same key again gets the same answer again, and stores nothing new |

Everything except `/auth/*` needs `Authorization: Bearer <accessToken>`;
without a live one: 401.

Errors are ProblemDetails (`application/problem+json`): `title`, `status`,
`detail`, and `traceId`, the reference support asks for. A 400 from
`POST /meters/{id}/readings` adds `errors`: field name to messages, such as
`{"value": ["That's lower than the last reading (48 213 kWh). …"]}`. A meter
on another reader's round is 404, as if it didn't exist.

A meter's `status` is `Due`, `Read` or `Query`. `Query` means two readings
in one month: the billing office will query which is right.

### The seed data

| Meter | Address | Last reading | Notes |
| --- | --- | --- | --- |
| M-1001 | 2 Lwandle Street | 48 213 | Due |
| M-1002 | 4 Lwandle Street | 30 115 | Due |
| M-1003, M-1009, M-1013 | | | Read already |
| M-1007 | 5 Isibaya Crescent | 30 876 | **The first reading sent for it reaches the server, but the answer never comes back** |
| M-1012 | 17 Umthombo Road | 27 561 | **`GET /meters/M-1012` is a 500** |
| M-1014 | 21 Umthombo Road | 61 988 | The last meter on the round |

Round 7 has 14 meters, 11 of them due. Sipho's Round 8 has M-2001 and
M-2002.

## Rules for this repo

- Don't edit `lib/core/fakes/` or anything in `test/support/`.
- `test/support/harness.dart` pumps the whole app the way `main()` does, on
  a server with no delay, a database in memory and a token store in memory.
  Use it in your widget tests; your instructor's checks use it too.
- Keep these names: `appRetryPolicy`, `TokenStore` (and its three methods)
  with `tokenStoreProvider`, `AppDatabase` with `appDatabaseProvider`, and
  `MeterReadApp`.
- Work on your own branch. Never push to `main`.
