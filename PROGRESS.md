# MeterRead — Week 11 revision challenge progress

## What was implemented in this working copy

- **Error handling:** a single sealed `Failure` mapper handles Dio and parallel request failures; the retry policy retries only requests with no HTTP response. Sign-in, round, meter and restore screens have user-facing error messages, reference IDs and retry actions.
- **Session:** refresh token is stored in `flutter_secure_storage`, with the access token kept in memory. A queued interceptor reuses a refreshed access token when two requests fail concurrently. Offline refresh errors do not revoke the session.
- **Offline round:** all API pages are fetched in walking order and written to `RoundDao`. The round shows cached values immediately, refreshes in the background, retains its cache on failed network refresh, shows the last-updated time and supports pull-to-refresh.
- **Outbox:** a UUID idempotency key is assigned when the reader saves a reading, persists beside it, and is reused on Send now. An unanswered POST leaves the reading in the outbox. Sign-out and API-revoked sessions clear local database rows and the token.
- **Reading form:** validates required whole-kWh input, accepts spaces as thousands separators, never converts through `double`, preserves input on a server field error, and shows that error under the labelled field.
- **Language and accessibility:** added English messages and the required draft isiZulu ICU plural, status words, labelled Send now, form label and sign-out confirmation for unsent readings.
- **Tests added:** unit cases for failure mapping and retry policy, plus widget scenarios for pagination, isiZulu, validation, one refresh, the lost-response replay and sign-out clearing data.
- **Bug hunt:** all eight explanations and fixes entered in `BUG-HUNT.md`.

## What has not been verified

- This working environment **has no Flutter/Dart SDK installed**, so `flutter pub get`, code generation, formatting, `dart analyze`, `flutter test` and an Android run **have not been executed here**. The code above is an implementation, not a claim of passing CI.
- The isiZulu translations other than the requested meters-left plural remain the starter's draft/fallback English, pending language review.
- The optional 200% text-size test and waiting status on *round list* were not added.

## What I copied and changed

No source was copied from Matric Compass or RondiTrack. The provided MeterRead starter was used as the base; Week 11 patterns were reimplemented against this API.

| MeterRead file | Purpose of change |
| --- | --- |
| `lib/core/network/token_store.dart` | Secure refresh token storage |
| `lib/core/network/session_interceptor.dart` | One refresh for simultaneous 401s; preserve session when offline |
| `lib/features/auth/{domain/reader.dart,presentation/auth_controller.dart}` | Recoverable launch, translated failures, wipe on sign-out/expired session |
| `lib/app/router/{router_provider.dart,routes.dart}` | Route recoverable launch to restore screen |
| `lib/app/retry_policy.dart` | Retry no-response only |
| `lib/features/round/data/round_repository.dart` | All pages, data-layer failure mapping |
| `lib/features/round/data/outbox_dao.dart` | Persist idempotency key at capture |
| `lib/features/round/presentation/{round_providers.dart,round_screen.dart}` | Cache-first round, pull to refresh, localized states, outbox |
| `lib/features/round/presentation/{meter_screen.dart,reading_form.dart}` | Reader-friendly retry and safe form |
| `lib/features/auth/presentation/sign_in_screen.dart` | Safe sign-in errors |
| `lib/l10n/{app_en.arb,app_zu.arb}` | New messages and ICU plural |
| `test/core/failure_test.dart`, `test/app/challenge_test.dart` | Unit and widget regression tests |
| `BUG-HUNT.md` | Eight explanations |

## What the phone keeps

| What | Where | Removed when |
| --- | --- | --- |
| Refresh token | Secure storage, via `TokenStore` | Sign-out or API refuses refresh; not on temporary no signal |
| Short-lived access token | Memory only, `AccessToken` | Session end or app process closes |
| Round name, server counts, update time | SQLite `CachedRounds` | Sign-out, API-revoked session, or another reader signs in |
| Round meters in walking order and statuses | SQLite `CachedMeters` | New round replaces them; session wipe clears them |
| Unsent reading, value, replacement flag, captured time, one idempotency key and last error | SQLite `PendingReadings` | Server accepts, reader discards, or session wipe |
| Reading form draft | Widget memory | Form closes/unmounts; only saved readings enter the outbox |

## Final checks to run on a machine with Flutter 3.47.7

```sh
flutter pub get
dart format .
dart run build_runner build --delete-conflicting-outputs
dart analyze --fatal-infos
flutter test
flutter run
```

Manual test: Sign in as Thandeka, open M-1012 and M-9999 from deep links, simulate no signal, expire access tokens, submit 31 250 for M-1007 then retry, and check all 14 meters.

## What I would do next

1. Run the exact four CI checks above, fix any analyzer/test findings, and retest on an emulator.
2. Add the optional large-text and round-row waiting-state checks.
3. Push only the named personal branch and give the instructor its URL. Mark a late submission accurately if the deadline has passed.
