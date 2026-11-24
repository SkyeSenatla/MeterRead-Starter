# Walkthrough: what changed in MeterRead, and why

Written for: you, reading the code top to bottom and checking you follow it.

Each stop below has a file link (click it, or Cmd-click in VS Code), what to
look at, **why** it is the way it is, and a question to test yourself. Go in
order: later stops lean on earlier ones.

How to try it live: `flutter run`, sign in as `thandeka@kwanele.test` with
`Kwanele-2026`, and use the flask icon (**Test tools**) for *No signal* and
*Expire access tokens*.

---

## The big picture

```
 screen  ──►  provider / controller  ──►  repository (Dio)  ──►  fake server
   ▲                                          │
   │                                          ▼
   └──────────  Failure  ◄──────────  failureFrom(error)
```

- Dio errors are turned into **one** type, `Failure`, at the edge of the data
  layer. Screens only ever see a `Failure`.
- The phone keeps a copy of the round (SQLite), so the list shows without signal.
- Readings go through an **outbox**: saved on the phone first, then sent, each
  with one fixed Idempotency-Key.

---

## Day 1: errors

### 1. The `Failure` type
[lib/core/error/failure.dart:9](lib/core/error/failure.dart#L9)

A `sealed class` with six cases: `NoSignal`, `NotFound`, `ServerCrash`,
`InvalidInput`, `SessionEnded`, `Unexpected`.

- **Why sealed:** a `switch` over it must cover every case, so adding a new
  failure later makes the compiler show you every screen to update.
- `NoSignal.retryable` is the only `true`. That one flag drives the retry rule.
- `ServerCrash.reference` holds the `traceId` support asks for.
- `InvalidInput.fields` holds the server's per-field messages, e.g.
  `{'value': ['That's lower than …']}`.

### 2. `failureFrom`: the one place errors are translated
[lib/core/error/failure.dart:109](lib/core/error/failure.dart#L109)

Read it as a decision list:

1. Already a `Failure`? Return it.
2. A `ParallelWaitError` ([line 112](lib/core/error/failure.dart#L112))?
   Dig out the real error inside and translate that. This is **BUG-HUNT #3**:
   `(a, b).wait` never throws a `DioException`, so `on DioException` never
   matched.
3. A `DioException` with **no response** → `NoSignal` (connection error or any
   timeout).
4. With a response, by status: 401 → `SessionEnded`, 404 → `NotFound`,
   400/422 → `InvalidInput`, 5xx → `ServerCrash`.

> Check yourself: why is a *receive timeout* a `NoSignal`? (The request may have
> reached the server, but the phone got no answer, so as far as the phone knows,
> there was no answer.)

### 3. The retry rule
[lib/app/retry_policy.dart:10](lib/app/retry_policy.dart#L10)

Retry up to 3 times (200, 400, 800 ms), **only if** `failureFrom(error).retryable`.
This is **BUG-HUNT #1**: the old policy retried every error.

> Check yourself: a 500 gets the same answer on the next try. Why is retrying
> it still harmful? (Waiting for nothing, and more load on a server that is
> already struggling.)

### 4. Turning a `Failure` into words
[lib/core/error/failure_view.dart:6](lib/core/error/failure_view.dart#L6) (the
`words` extension) and [line 20](lib/core/error/failure_view.dart#L20) (`FailureView`).

- `words(l10n)` picks a friendly, translated sentence. The exception's own text
  is never shown. This is **BUG-HUNT #2**.
- `FailureView` shows the sentence, the **reference** only for `ServerCrash`,
  and a **Try again** button.

### 5. The repository applies it
[lib/features/round/data/round_repository.dart:101](lib/features/round/data/round_repository.dart#L101)

`_guard` wraps every call. Whatever is thrown leaves as a `Failure`. Notice the
three public methods ([fetchRound](lib/features/round/data/round_repository.dart#L18),
[fetchMeter](lib/features/round/data/round_repository.dart#L54),
[submitReading](lib/features/round/data/round_repository.dart#L86)) are all
`=> _guard(() async { … })`.

`submitReading` is **never retried** here. Only the reader's "Send now" sends again.

---

## Day 2: the login session

### 6. Refresh token in secure storage
[lib/core/network/token_store.dart:22](lib/core/network/token_store.dart#L22)

`SecureTokenStore` uses the Keychain (iOS) / Keystore (Android). This is
**BUG-HUNT #4** (plain `SharedPreferences` is readable). The access token stays
in memory only ([access_token.dart](lib/core/network/access_token.dart)).

### 7. One shared refresh
[lib/core/network/session_interceptor.dart](lib/core/network/session_interceptor.dart)

Read `onError` ([line 43](lib/core/network/session_interceptor.dart#L43)) slowly:

- Not a 401? Pass it on.
- **`_refreshing`** ([line 32](lib/core/network/session_interceptor.dart#L32)):
  if a refresh is already running, every other failing request *awaits that
  same one* instead of starting its own. This matters because each refresh token
  works **once**; a second refresh would end the whole session. This is
  **BUG-HUNT #5**.
- **`sentWith`** ([line 55](lib/core/network/session_interceptor.dart#L55)): a
  request that went out with the *old* token and failed *after* someone already
  refreshed doesn't refresh again; it is just sent again with the new token.
- The handler is always answered (`resolve` or `next`), so no request hangs.

### 8. When does a session really end?
[session_interceptor.dart:105](lib/core/network/session_interceptor.dart#L105) (`refused`)

Only if the API itself answers the refresh with **401/403**. No signal, a
timeout or a 500 → the reader stays signed in. This is **BUG-HUNT #6**: the old
code signed out on *any* `DioException`.

### 9. Launch
[lib/features/auth/presentation/auth_controller.dart:30](lib/features/auth/presentation/auth_controller.dart#L30)

`_restore` refreshes once at launch. A refusal → signed out. No signal → still
signed in (`Reader.unknown`), so the reader reaches the saved round.

> Check yourself: open the app with *No signal* on. Why does it not go to the
> sign-in screen?

---

## Day 3: offline

### 10. The saved round, shown first
[lib/features/round/presentation/round_providers.dart:44](lib/features/round/presentation/round_providers.dart#L44) (`RoundSync`)

- `build` listens to the database (`dao.watch()`) and kicks off a refresh.
- [`refresh`](lib/features/round/presentation/round_providers.dart#L66) can't
  run twice at once (`_inFlight`).
- A failed update does **not** touch the saved list; it only sets
  `RoundView.failure`.
- [`_withRetry`](lib/features/round/presentation/round_providers.dart#L93)
  applies the same "only when no answer" rule.

Then see how the screen reads it:
[round_screen.dart:45](lib/features/round/presentation/round_screen.dart#L45) shows
the saved list whenever there is one, plus a banner ("Couldn't update the list.
Last updated …", [line 86](lib/features/round/presentation/round_screen.dart#L86)).
Only with *no* saved list does it show a spinner or a `FailureView`.

### 11. One Idempotency-Key, made at Save
[lib/features/round/data/outbox_dao.dart:19](lib/features/round/data/outbox_dao.dart#L19)

`capture` inserts the reading **and** its key
([line 28](lib/features/round/data/outbox_dao.dart#L28)). The key is stored in
the database row, so it survives retries and even an app restart. This is
**BUG-HUNT #7**: the old code made a new UUID on every attempt, so a lost reply
plus a retry stored the reading twice.

Then [`ReadingOutbox.send`](lib/features/round/presentation/round_providers.dart#L163)
reads that stored key and reuses it every time.

What happens to the row after a send:

| Outcome | Row | Why |
| --- | --- | --- |
| Accepted | removed | done |
| `InvalidInput` / `NotFound` | removed, error thrown | sending again gets the same answer |
| No signal, server crash, session ended | **kept**, reason stored | the reader can tap "Send now" |

### 12. Sign-out deletes everything
[lib/features/auth/presentation/auth_controller.dart:96](lib/features/auth/presentation/auth_controller.dart#L96) (`_forgetEverything`)
→ [`AppDatabase.wipe`](lib/app/database/app_database.dart#L27).

Clears the access token, the refresh token, and every table row.

---

## Day 4: forms, lists and wording

### 13. All pages
[round_repository.dart:18](lib/features/round/data/round_repository.dart#L18)

Loops, passing `nextPageToken` back as `pageToken`, until the server leaves it
out (the last page). That's how 10 became 14.

### 14. The reading field
[lib/features/round/presentation/reading_form.dart](lib/features/round/presentation/reading_form.dart)

- Input formatter allows digits and spaces only
  ([line 103](lib/features/round/presentation/reading_form.dart#L103)).
- [`parseReading`](lib/app/format.dart#L21) strips spaces and makes an `int`
  (never a `double`).
- [`_save`](lib/features/round/presentation/reading_form.dart#L38): if the server
  refuses, `on InvalidInput` ([line 67](lib/features/round/presentation/reading_form.dart#L67))
  puts the server's message under the field and **does not clear what was typed**.
- It marks itself busy via `SavingReading`
  ([round_providers.dart:118](lib/features/round/presentation/round_providers.dart#L118))
  so the meter screen keeps the form on screen while saving
  ([meter_screen.dart:77](lib/features/round/presentation/meter_screen.dart#L77)).
  Without that, the "waiting to send" card would replace the form before the error
  could show.

### 15. The plural
[lib/l10n/app_en.arb:83](lib/l10n/app_en.arb#L83) and [app_zu.arb:8](lib/l10n/app_zu.arb#L8)

One ICU message: `{count, plural, =0{…} =1{…} other{…}}`. This is **BUG-HUNT #8**.
isiZulu is a draft (not checked by a first-language speaker).

### 16. Accessibility
- Status shown in words: `meterStatusLine` → "KW-… · Due"
  ([round_screen.dart:102](lib/features/round/presentation/round_screen.dart#L102));
  the icon is decorative (`ExcludeSemantics`, [line 123](lib/features/round/presentation/round_screen.dart#L123)).
- The "Send now" icon button has a tooltip, which is its label
  ([meter_screen.dart:89](lib/features/round/presentation/meter_screen.dart#L89)).
- The field has a real label (`Reading (kWh)`), not just a hint.

---

## The tests: read these to see what is promised

| File | What it proves |
| --- | --- |
| [test/errors/failure_test.dart](test/errors/failure_test.dart) | every error maps to the right `Failure`; retry rule |
| [test/session/session_interceptor_test.dart](test/session/session_interceptor_test.dart) | 5 failing requests → 1 refresh; no signal never signs out; refusal ends the session once |
| [test/round/round_flow_test.dart](test/round/round_flow_test.dart) | the whole app on the fake server, grouped by day |

Run them all with `flutter test`. CI's four steps: `dart format`, `build_runner`,
`dart analyze --fatal-infos`, `flutter test`.

---

## Known gaps (also in PROGRESS.md)

- A meter you have never opened can't be opened offline.
- If the API refuses a refresh, unsent readings are wiped with everything else.
- Old installs that kept the token in `SharedPreferences` aren't migrated.
- isiZulu is a draft, and only the plural is translated.

---

## Self-test: BUG-HUNT answers, in one line each

1. Retries every error → retry only when there was no answer.
2. Shows the raw exception → map to a friendly message plus Try again.
3. `.wait` throws `ParallelWaitError`, so the `DioException` catch never fires → unwrap it in `failureFrom`.
4. Tokens in plain `SharedPreferences`, two separate writes → secure storage.
5. Handler never called, and concurrent 401s each refresh → always answer the handler; share one refresh.
6. Any `DioException` signs out and wipes everything → only a refused refresh ends a session.
7. New key on every attempt → make the key once at Save and store it.
8. English-only `== 1` plural → ICU plural message in the `.arb` files.
