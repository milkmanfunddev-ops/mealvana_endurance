# 31: Retest: meal logging

**Status:** in-progress (wave 3, 2026-10-08)
**Labels:** retest, round:develop-2026-10, area:meal-logging, ai-call
**Branch:** `develop-next` (worktree per ticket, branched from the round's base after the fix wave lands)
**Source:** TRIAGE.md rulings of 2026-10-07: followups 02-006, 02-007, 02-008, 02-009, 02-010, 02-011,
02-012; fix retests for ticket 24 (02-003, 02-005)
**Blocked by:** the fix wave (tickets 21–29) and its rebuild; runs in wave 3
**Next:** `/testing-wave develop-2026-10 --only 31`
**Model:** opus

**What to test:** The Log a meal sheet's Describe tab and the Review screen after the fixes: the AI note
is saved with the meal, an edited quantity round-trips over the original portion, and the token pill moves
with the wallet. Then the paths ticket 02 only listed: Review's back, rename, Any time and item swap;
Describe's input edges and offline failure; photo plus text; the software keyboard; a described meal's
Timeline menu; and the TrainingPeaks sharing sheet on relaunch.

**Not here:** ticket 23 (the token model end to end: start at 50, one per call, the wall at 0, packs) is
retested by ticket 12, not by this ticket. 02-012's pill check below only reads the pill against the
wallet around this ticket's own spends. The out-of-credits half of 02-007 (step 3, balance 0) is ticket
12's too: this ticket never drains a wallet. 02-011 may also close through ticket 29 (backports).

**Runs by:** `docs/testing-wave/RUNBOOK.md`. RUNS = `.scratch/testing-wave/rounds/develop-2026-10/runs/31/`,
Findings in `.scratch/testing-wave/rounds/develop-2026-10/findings/`. One slot, console to RUNS, a
look-around on every screen, every problem a Finding, nothing fixed.

**Accounts:** the dev test account (`CRED type test@test.com --udid UDID`). Other tickets in the same wave
(32 and 33's cross-device half) may write on it: 33 logs and deletes two manual meals; 32 writes nothing
by design. Check only the rows this run writes (by `created_at` inside the run's minutes and the text you
typed). Every meal this run logs is deleted by step 6, so the account ends as it started.

**App data:** cleared by the wave lead.

**Cost: at most three AI logging spends**, each `COST spend WAVE logging 31` before the tap that sends,
never after. Spend 1 is the fix retests, so it goes first. Count per check:

| Spend | Checks it carries |
|---|---|
| 1: text describe | 02-003, 02-005, 02-006 (b, c, d), 02-012, 02-011, 02-009, ticket 27's describe status |
| 2: photo + text | 02-010, ticket 27's photo status |
| 3: non-food text | 02-007 (c), 02-006 (a) |
| none | 02-007 (a, b: empty, short, offline), 02-008 |

**Exit 3 (the wave's cap is used up):** skip that spend's checks and file one followup-test Finding
naming them. Spend 1 refused skips 02-003, 02-005, 02-006 b-d, 02-012 and 27's describe half (02-011 and
02-009 still run without a send: 02-011 up to the Analyze tap, 02-009 on any described meal already on
the day, or skipped). Spend 2 refused skips 02-010 and 27's photo half. Spend 3 refused skips 02-007 (c)
and 02-006 (a). A spend that bought nothing goes in notes for the lead to count back.

**Retest rule.** A check that passes closes the Finding named beside it: write `PASS <id>` in
`RUNS/notes.md` with the evidence, and the lead marks it `closed`. A check that fails files a new Finding
with `findings.mjs new 31 … --round develop-2026-10` citing the old id (`Retest of 02-NNN`). Ticket 24
closes when 02-003 and 02-005 both pass.

## Screens (from code, unverified)

| Screen | Entry | Code |
|---|---|---|
| Timeline, "+ Add Food", a meal card's ⋯ | `/main` | `lib/features/macro_dashboard/presentation/screens/macro_dashboard_screen.dart` |
| Log a meal sheet, Describe tab (token pill, Camera, Gallery, thinking status) | `openLogMealScreen` | `lib/features/meal_logging/presentation/screens/log_meal_screen.dart` |
| Review & Log, Edit Item | `/meal-log/review` | `lib/features/meal_logging/presentation/screens/meal_review_screen.dart` |
| Edit a logged meal | Timeline card ⋯ | `lib/features/meal_logging/presentation/screens/edit_meal_log_screen.dart` |
| TrainingPeaks sharing sheet | shown by the tab shell once, when TrainingPeaks is active | `lib/shared/widgets/tabs_screen.dart` (`_maybeShowWritebackMigrationNotice`), `lib/shared/widgets/kyle_design/sheets/tp_writeback_consent_sheet.dart` |

The thinking-status widget moved to `lib/shared/widgets/` under ticket 27 (archive Jade); read its new
path in 27's file.

## Expected records (`RUNS/expected.md`)

- Read `meal_logs`' columns from `information_schema.columns` first, then name them.
- Each logged meal: one `meal_logs` row whose macros equal Review's totals; `notes` equals the AI note shown
  on Review (02-003); a photo meal stores `source` = `photo` and a `photo_path` (02-010); a meal logged with
  no slot stores `slot` null (02-006 c).
- Credits: before and after each spend, `token_wallets.balance` and the newest `token_ledger` rows. One
  debit per successful analysis; none for a refused or failed call (`supabase/functions/_shared/ai/credits.ts`,
  "failed calls aren't charged"). Whatever unit ticket 23 left the wallet in, the pill equals the balance.
- Delete from the Timeline: the row's `is_deleted` true.
- 02-008 writes device prefs only (from code, unverified: `tp_writeback_notice_shown`,
  `tp_writeback_enabled` in `lib/shared/services/preferences_service.dart`); `integrations` for
  `training_peaks` does not change (name the columns: never select token columns).

## Steps

1. **02-008**, first, because the sheet shows on the first shell launch after sign-in. Sign in. If the
   sheet "Your fuel plan goes to your coach" shows, record when (after which prompts) and whether the
   console shows TrainingPeaks `invalid_grant` at the same time (a sheet promising sharing over a dead
   connection is a Finding). Close it by the scrim. Terminate, read the two prefs keys (names and these
   two values only, python `plistlib` on the container's prefs plist), relaunch: does it come back? Then
   reset it on this simulator only, app terminated: `xcrun simctl spawn UDID defaults delete
   com.milkman.mealvanaendurance.dev flutter.tp_writeback_notice_shown` (a device-only write this ticket
   names). Relaunch, take Turn Off Sharing, read the keys. Reset again, relaunch, take Keep Sharing, read
   the keys: the run ends with sharing on, as it started. If the sheet never shows (TrainingPeaks not
   active on the account), write that and skip.
2. **02-007 (a, b), no spend.** Describe tab: Analyze with the field empty, then with 4 characters: each is
   stopped before any call (no ledger row, no `describe-meal` request in the edge log for those minutes).
   Then `netcut.sh launch UDID SCRATCH` + `netcut.sh on SCRATCH`, type a real description, Analyze: the
   error shown (a MealvanaSnackbar-style message), no ledger row, no wallet change, and no
   `describe-meal` line in the edge log (Supabase MCP `query_logs`, runbook step 6). Check
   `SCRATCH/netcut.log` shows the blocked connect before trusting "no call". `netcut.sh off SCRATCH`.
3. **Spend 1: 02-012, 02-011, 27, then Review.** Turn the hardware keyboard off (simulator I/O →
   Keyboard → Connect Hardware Keyboard) so the iOS keyboard shows. Read the pill and SQL balance: equal.
   Type "two scrambled eggs, a slice of whole wheat toast with butter, a banana". **02-011:** with the
   keyboard up, is Analyze reachable without dismissing it? Spend, Analyze. **27:** screenshot the
   thinking status while the call runs (describe phases). On Review:
   - **02-005 (ticket 24).** Edit the banana: Quantity 2, save; the row reads two bananas. Edit it again:
     it reopens at Quantity 2 over the original portion (1 medium banana, ~118 g, 105 kcal). Set 1, save:
     the row and totals are back to the start.
   - **02-006 (b, c, d).** Clear the meal name: Log is disabled or says why (a silent no-op is a Finding).
     Put the name back. Swap one item through the food picker; remove one if the editor allows; the
     totals follow. Deselect the slot (Any time).
   - Record the AI note text. Log it.
   - **02-003 (ticket 24).** SQL: `notes` equals the note shown; `slot` null; macros equal Review's totals.
   - **02-012.** Back on the sheet without relaunching: the pill dropped by one call's cost and equals the
     SQL balance, with one ledger debit.
4. **02-009.** On the Timeline, scroll the new card out of y 650-790 (the dev overlay sits there), open ⋯:
   edit the meal and change one item, save: the card, the Net Balance "Eaten" and the row (`updated_at`,
   items, totals) agree. Move it to a slot. Leave it for step 6's delete.
5. **Spend 2: 02-010 and 27.** Describe tab → Gallery, pick a food photo from the simulator library (add
   one with `xcrun simctl addmedia UDID <jpg>` if the library has none; a device-only write), then remove
   it: back to text-only, no call. Pick it again, add one line of text, spend, Analyze. Screenshot the
   thinking status (photo phases). One ledger debit for photo plus text. Log it; SQL `source`,
   `photo_path`, `notes`.
6. **Spend 3: 02-007 (c) and 02-006 (a).** Describe "my bike ride", spend, Analyze: record the answer
   (a clear "not food" message, or a Review). If a Review opens, tap Back without logging: is the text
   kept, and does getting back to Review need another Analyze (another token)? Do not spend again to
   find out; read the button and the ledger. No meal row for this text.
7. Delete every meal this run logged from its card's ⋯: card gone, Eaten back down, `is_deleted` true.
   Relaunch: they stay gone.

## What counts as a Finding

- A retest that fails (02-003, 02-005): new bug Finding citing the old id.
- Numbers on Review, the card and the row that disagree; a pill that disagrees with the wallet; a debit
  for a stopped, failed or refused call; two debits for one analysis.
- A thinking status missing during a describe or photo call (ticket 27's retest; ticket 32 checks the
  `/jade` half).
- Any edge-function error line in the run's window, even one this run did not cause (screen none).
- Console errors on any visited screen (or "known noise: <why>"; TrainingPeaks and V.O2 token Degradeds
  on this account are known, Sentry ticket 22). Look-around paths as followup-test Findings.

## Exit

- [ ] Findings filed with `node scripts/testing-wave/findings.mjs new 31 "<one line>" --round develop-2026-10 --kind bug|ssot-conflict|followup-test|idea --run RUN`, every field filled; `findings.mjs index --round develop-2026-10 --out "$TMPDIR/tw-31-index.md"` exits clean.
- [ ] `RUNS/notes.md` lists each check with `PASS <id>`, the new Finding's id, or "skipped: cap" so the lead can close or keep each old Finding; spends that bought nothing are named.
- [ ] Every meal this run logged is deleted; TrainingPeaks sharing left on; hardware keyboard turned back on. No account was created (nothing to delete).
- [ ] `netcut.sh off SCRATCH`; background processes stopped by PID, log stream stopped, app terminated, `LOCK release slot testing-wave-31`. The simulator is left for the wave lead to drop.
- [ ] Console redacted (runbook § 9.4); only `console-redacted.log` is kept.
- [ ] `findings/31-*.md` and `runs/31/` committed on the ticket branch, explicit paths only.
