# Progress

Fill this in before you hand in. Saying what's unfinished is never sent back.

## What works

**Day 1: errors**
- Every failure becomes one `Failure` type (`lib/core/error/failure.dart`):
  `NoSignal`, `NotFound`, `ServerCrash`, `InvalidInput`, `SessionEnded`,
  `Unexpected`. The repository turns every Dio error, and the error `.wait`
  throws, into a `Failure` at the edge of the data layer.
- Every screen shows words, never the exception text, and a "Try again"
  button (`FailureView`). A server crash also shows its reference number
  (the ProblemDetails `traceId`).
- Retry only when there was no answer at all (`appRetryPolicy`). A 400, 404
  or 500 is never retried, and a save is never retried by the app: only the
  reader's "Send now" sends it again.

**Day 2: login session**
- The refresh token is in secure storage (`SecureTokenStore`: Keychain /
  Keystore). The access token is in memory only.
- Requests that fail together share one refresh (`SessionInterceptor`). A
  request that failed with the old token after someone else refreshed is
  just sent again with the new one.
- Only the API refusing a refresh (401/403) ends a session. No signal, a
  timeout or a server error never signs the reader out, at launch or later.

**Day 3: offline**
- The round screen shows the list saved on the phone straight away, then
  updates it in the background (`RoundSync`). If the update fails, the list
  stays, with "Couldn't update the list. Last updated ..." and Try again.
- A reading gets its Idempotency-Key once, when the worker taps Save (in
  `OutboxDao.capture`), and keeps it in the database. Every attempt to send
  uses that key.
- Signing out deletes the tokens and every database row (`AppDatabase.wipe`).

**Day 4: forms, lists, wording**
- All pages of the round load (14 meters, not 10).
- The reading field takes digits and spaces ("48 590"), stored as an `int`.
  The server's refusal shows under the field and what was typed stays.
- "11 meters left" is an ICU plural in English and isiZulu.
- Every button has a label, a meter's status is written in words as well as
  an icon, and the widget tests check the accessibility guidelines.

## What doesn't work yet

- The isiZulu strings are a first draft (as the file already says), and only
  the plural is translated: everything else shows in English.
- A meter's own screen still needs the server the first time: with no signal
  the reader can't open a meter that hasn't been opened before, so can't
  capture a reading for it. The round list works offline; the meter detail is
  not cached.
- When the session ends for real (the API refuses a refresh), everything on
  the phone is wiped, including readings not yet sent. They couldn't be sent
  without a session, and must not go out under the next reader, but the
  reader isn't warned.
- Old installs that kept the refresh token in `SharedPreferences` are not
  migrated: they sign in once, and the old plaintext copy is left behind.

## What I copied, and what I changed

| File in MeterRead | Copied from (Matric Compass, RondiTrack or class materials) | What I changed |
| --- | --- | --- |
| `lib/core/error/failure.dart` | Week 11 class materials (the `Failure` idea) | Written for this API: ProblemDetails, `traceId`, `.wait` unwrapping |
| `lib/core/network/session_interceptor.dart` | The starter's interceptor | One shared refresh; only a refused refresh signs out; handler always answered |
| `lib/core/network/token_store.dart` | The starter | `SecureTokenStore` instead of preferences |
| `lib/features/round/presentation/round_providers.dart` | The starter | Cached-first `RoundSync`; key made at capture, never per attempt |
| `lib/features/round/data/round_repository.dart` | The starter | All pages; every error becomes a `Failure` |

## What the phone keeps

Everything MeterRead stores on the phone, where, and what removes it:

| What | Where | Removed when |
| --- | --- | --- |
| Refresh token | Secure storage (Keychain / Keystore) | Sign out, or the API refuses a refresh |
| Access token | Memory only | Sign out, a refused refresh, or closing the app |
| Saved round (name, counts, meters, when it was fetched) | SQLite database `meterread` | Sign out, or a refused refresh |
| Readings not yet sent, with their Idempotency-Key and last error | SQLite database `meterread` | The server accepts or refuses them, the reader discards them, sign out, or a refused refresh |

## What I'd do next

- Cache each meter's detail, so a meter can be opened (and read) offline the
  first time.
- Warn before a refused refresh wipes readings that haven't been sent.
- Migrate the old `SharedPreferences` refresh token, then delete it.
- Have a first-language isiZulu speaker check and finish the translations.
