# 04: A Tester adds a photo by web address

**What to build:** A Tester (7-tap "Mark this device as internal" switch) opens a library Meal's
recipe screen and sees a small camera icon on its photo, or an "Add photo" line where the picture
would be. Athletes see neither. Either one opens the Meal photos page. It shows the current photo
or says there is none. The Tester pastes an image address, sees a preview, optionally adds a
credit (text plus link), and confirms. Once the server confirms, "Photo added" shows and the photo
replaces whatever the Meal showed, for every athlete. Spec: Implementation Decisions (photo
function, History, controller, page).

**Blocked by:** 01

**Status:** ready-for-agent

- [x] Migration: a History table (one row per photo a Meal has had: Meal id, address, credit,
      credit link, storage path or null, who added it, when) and an event table (action, photo,
      account, time). RLS is on and there are no client policies. Applied to dev.
- [x] A new edge function authenticates the caller and refuses anyone whose `users.is_internal` is
      not true (403 `not_tester`). It implements `add_address` (https only; the address must answer
      with an image content type, else 400 `not_an_image`) and `history`.
- [x] Each write updates the Meal's current-photo fields, inserts the History row and the event
      in one transaction through an SQL function, and returns the new current photo. An unknown
      Meal returns 404.
- [x] The function is deployed to dev.
- [x] The Tester-only entry points show only when the internal flag is on. The Meal photos page
      is pushed with a route name, all strings go through the content system, and results use
      `MealvanaSnackbar`.
- [x] The page loads the pasted address and shows a preview before Confirm. An address that
      doesn't load shows a clear message and Confirm stays disabled. Cancel changes nothing.
- [x] A new `@riverpod` AsyncNotifier for one Meal's photos uses remote-ack only, with no local
      write and no queue. With no signal it fails clearly. On success it invalidates the Meal's
      detail and the catalog so the new photo shows on the next fetch.
- [x] Seam 2 test through the real notifier with a recording fake repository: one request per
      add, state changes only after the ack, and a thrown failure leaves state unchanged and
      reaches the screen.
- [x] Seam 3 Deno test on the handler with the fake database (`--allow-sys`): a non-Tester gets
      403 and nothing is written; an add writes the current photo, one History row and one event
      with the account; a non-image address is refused.
- [ ] Checked on the simulator: a Tester pastes an address on the salmon salad, confirms, and a
      second non-Tester account sees the photo on the Meals tab and recipe screen.

## Comments

**2026-09-16 — implemented.** Everything but the simulator check is done and verified.

- **Migration `20260916160000_meal_photo_history_and_events.sql`** — `meal_photo_history` (one row
  per photograph a Meal has shown) and `meal_photo_events` (add/remove/restore/delete, with the
  account and the time). Both have RLS on and **no policies at all**, and `authenticated`/`anon` are
  revoked, so only the service role reaches them. `meal_library` gained `photo_history_id`.
  `storage_path` is there from the start, so ticket 05 adds no column. Applied to dev and verified:
  RLS true on both, 0 policies, 0 rows.
- **`meal_photo_add`** is `SECURITY DEFINER` and does the whole write in one transaction: History
  row, the Meal's current-photo fields, the event. An unknown Meal raises before anything is
  written. Execute is granted to `service_role` only — it takes the account as a parameter, so a
  client calling it directly could sign a row as somebody else.
- **Edge function `meal-photo`**, deployed to dev. `index.ts` resolves the JWT; `handler.ts` holds
  the logic and takes an injected image probe, so the Deno test drives it with a fake database and
  no network. `add_address` and `history` only — 05 and 06 add their actions against the same
  Tester check.
- **App:** `MealPhotoRepository` (remote-ack, no local write, no queue), `MealPhotosController`,
  the Meal photos page, and the two Tester entry points, which live in
  `presentation/widgets/meal_photo_entry_points.dart` rather than in the 1,150-line recipe screen.
  Whether to draw them is still the recipe screen's decision, so one place answers "is this a
  Tester", not three.

**Verified live against deployed dev**, not just in tests: Tester → 200; non-Tester → 403
`not_tester` with nothing written; unknown Meal → 404; no JWT → 401; a page that is not an image →
400 `not_an_image`; `http://` → 400 `invalid_input`. A real `add_address` on **AD-001** then wrote
exactly one History row signed by the account, one event, pointed `meal_library` at it, and left
the frozen pipeline's columns untouched.

**Tests:** seam 3 12 Deno tests, seam 2 6 through the real notifier, 8 on the page, plus the
Tester entry points added to the existing seam-1 file. Deno suite 108/108. Flutter suite
**5080 pass / 8 skip / 2 fail**, both failures pre-existing and unrelated (`ci_config_contract_test`
and a manual-live TrainingPeaks credential test).

**Four defects `/code-review` caught, all fixed:**

1. **"Photo added" could be said having sent nothing.** `addAddress` opened with
   `if (current == null) return;` — a silent success while the page was still loading. It now
   always sends.
2. **The device invented the server's own truth.** The repository built the new History row with
   `DateTime.now()`, the local account id, and `readString(json,'historyId') ?? ''` — an empty id
   that the History parser itself would have rejected, which `withAdded`'s de-dupe would then have
   dropped. `meal_photo_add` now returns the row it wrote (id, account, server clock) and the app
   parses it with the same reader the History list uses.
3. **`meal_not_found` was matched on the error's prose.** It now matches the SQLSTATE as well —
   `P0002`, confirmed against dev.
4. **The page hand-rolled a `TextField`** while `KyleTextField` exists, and mapped error codes to
   content keys in two places. Both collapsed to one.

**Two review findings deliberately NOT taken**, both worth your eye:

- **`AsyncValue.guard()`.** The spec says every write is "wrapped in `AsyncValue.guard()`", and
  CLAUDE.md makes it a non-negotiable. But guard puts the failure *in* the state, and this
  ticket says "a thrown failure leaves state unchanged and reaches the screen" — the page must keep
  showing the photograph athletes still see rather than replacing it with an error. I followed the
  ticket, matching what `MealDetailController.review` already does for the other cross-user write
  (checked: `review` does not wrap in guard either). **A ruling would settle it for 05 and 06.**
- **The bucket migration.** The spec's Further Notes put it in "the photo function's ticket", but
  ticket 05's first checkbox also claims it and 04 needs no storage. Left to 05.

**Open for Lee — nothing in this repo writes `users.is_internal`.** The app-side Tester is
`internalDeviceFlagProvider` (the 7-tap switch, device-local). The server gate is the
`users.is_internal` **column**, and no code anywhere sets it: it is hand-set in the database, like
`is_admin`. So a Tester who flips the switch sees the entry points and then gets 403 on every add
until someone edits their row. The spec never said who writes that column. Three ways out — the
7-tap switch also writes the column; the gate moves to `users.is_admin` (already hand-set, and the
spec says switching is a one-line change on each side); or it stays hand-set and we accept it.
**This blocks nothing in 04, but 05 and 06 inherit it.**

**A trap worth knowing: a debug build is *forced* internal.** `InternalDeviceFlagNotifier` follows
`InternalUserService.testerModeEnabled`, which defaults to `isForced` — true on any debug/profile
or `IS_INTERNAL` build. So on dev **every device is a Tester by default**, which is consistent with
"dev ships visible and broken freely", but it also silently broke 8 meal-detail goldens by drawing
the Add photo line into what is supposed to be an athlete's screen. The golden host and the widget
helpers now pin the flag off (`test/features/meal_planning/presentation/helpers/tester_flag.dart`)
rather than regenerating goldens — a golden should keep showing what an athlete sees.

**The simulator check is NOT done.** Dev is seeded so it is quick: **AD-001** (the salmon salad the
ADR names, which showed nothing) now carries a Pexels photograph added through the real function by
`607f9dd5` (test@test.com, `is_internal = true`). Account `37129f7e` has `is_internal = false` and
is the ready-made non-Tester. What is left to see on a device: the Tester's camera icon and Add
photo line, a paste-preview-confirm round trip, and that second account seeing the photo on the
Meals tab and recipe screen without the entry points.
