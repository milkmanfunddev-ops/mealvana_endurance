# Ticket 113 notes (wave 40, run w40-20260926T1051Z)

- App build: commit 72d3723e7a441d607e5b39de19f8ff6d89cb8cf7 (already installed on wave-pool-1, A7D6E56A-07DF-4F61-8C56-86532F7A1F94). Carries fix tickets 41, 44, 50, 54.
- Worktree base: 6739f0fcc3ff6cde08ed4b4c104b1424bbd7f853.
- Slot claimed 10:51:34Z.
- Shared account: ticket 117 reads test@test.com on another simulator at the same time.
- Camera permission reset before the first launch (28-001 Allow leg), 10:52:30Z.
- Log stream PID in SCRATCH/logstream.pid; app launched 10:52:33Z; mobile MCP's first screenshot sent the app to the home screen (IMPROVEMENTS #50), relaunched with simctl.
- Signed in as test@test.com at 10:53:27Z (What's New sheet dismissed).

## Timeline (UTC)
- 10:53:55 scanner from Log a Meal → camera alert → Allow 10:54:01 → plain no-camera text.
- 10:54:3x Enter 12345 → Invalid Barcode dialog. 10:54:5x Enter 4006381333931 → Log Food for "DiagnosticTest Diagnostic Test Product DELETE ME" (Open Food Facts junk entry, no nutrition). Not logged.
- 10:56:28 Manual "W40-113 Decimal kcal" 250.5 kcal → 251. 10:57:36 "W40-113 Huge values". 10:58:01 "W40-113 No macros". 10:58:17 half entry + Back: not saved.
- 10:58:5x Build a Meal scanner, Enter barcode → item added to the draft; swiped away.
- 11:02 15-item draft (red Duplicate keys box), Back → draft discarded.
- 11:06:12 "W40-113 Built bowl" (4 items, favorite ticked). 11:07:36 "W40-113 Twice" (combo twice).
- 11:09:25 edit Decimal carbs 31 (via leave dialog Save). 11:09:59 / 11:10:27 / 11:10:46 calories 250.5 / 300.5 / empty: all dropped.
- 11:12:20 edit No macros: Lunch, 11:45 PM, sodium 100, note.
- 11:12:57 app killed on Edit Meal (Twice, one Banana swiped away unsaved); relaunched; iOS notification prompt → Don't Allow.
- 11:14:09 Remove Twice. 11:14:38 Remove Decimal → 11:14:41 Undo.
- 11:14:59 netcut on (relaunch). 11:15:23 Remove Huge values offline. 11:16:21 "W40-113 Offline log" saved offline. 11:16:36 offline kill+relaunch. 11:16:55 netcut off.
- 11:17:45 plain relaunch online; offline writes still unsent at 11:17:15, 11:17:34, 11:18:05, 11:24:46, 11:26:40 (112-001, still true, re-checked).
- 11:19:23 Remove Decimal, 11:19:25 app terminated; server had is_deleted true at 11:19:24.
- 11:21:09 old row a61f94fd: 250.5 dropped; 11:21:36 251 saved.
- 11:22 camera revoke → denied text; reset; Don't Allow; double Reset; Settings app and back.
- 11:23:20 netcut on; 11:23:43 offline Enter lookup → "Unable to connect to product lookup service". 11:24:09 netcut off.
- 11:25 Start from recent (Built bowl) → 4 items copied; backed out, not logged.
- 11:26:52 log stream stopped, app terminated, slot released.

## Console
- Flutter printed nothing between 05:59:07 and 06:03:20 local; that stretch had no analytics-bearing action and the app kept working. Not a Flutter hang: the Duplicate keys error itself never reached the console (probably routed to Sentry only).
- Known noise: TrainingPeaks token refresh 400 and V.O2 "reconnect" on every integration sync (21-004); network-unreachable errors, CreditsRepository, FoodRepository template_foods and [IS_ADMIN] (3 boxes) only inside the netcut windows (offline by design; IS_ADMIN is 120-009); GoRouter "extra … without a codec" on /meal-log/edit (already in 27-005).
- Edge extract (edge-requests.txt): vana-action at 10:54:51Z with no console line in this app and no vana_calls row in the window: another run's request (ticket 117 on the same account), no model call. generate-macros-v4 / generate-nutrition-plan-v3 at 11:17Z also not from this app's console; likely 117. garmin-push ×55 is Garmin's server push.

## Harness surprises
- The dev overlay buttons (red accessibility at ~367,695 and blue "Open testing tools" at ~368,756) sit on top of the timeline rows' ⋯ buttons and the Recipes rows' + buttons. Three stray taps: two turned on the accessibility highlight, one opened "UI settings". Scroll the row away from y 650-790 before tapping ⋯ (100-001 is the same overlap).
- `idb ui text` followed quickly by a tap on the next field dropped the last characters twice ("W40-113 decimal f", "W40-113 Offline lo"); read fields back before saving.
- Backspace key-sequence after a tap in the middle of text deletes from the tap point; forward delete (keycode 76) was needed to clear a prefilled builder name.
- Tapping Back twice at (34,90) on the timeline hits "Previous day" (8..40, 72..106): the timeline moved to Sep 25 without notice; the last builder open (not logged) was for Sep 25.
- Remove-then-kill before upload cannot be reached with idb + simctl: the tap itself takes ~1 s and the tombstone is on the server within 1 s.

## What this run left on test@test.com
- Kept (not deleted): W40-113 Huge values (8c8b2645, server is_deleted false; locally removed, tombstone unsent), W40-113 No macros (eb8c7ab8, edited), W40-113 Built bowl (d51be206), saved meal W40-113 Built bowl (85f10c75). W40-113 Offline log exists only on the phone (never uploaded).
- Deleted (is_deleted true): W40-113 Decimal kcal (c3bc3639), W40-113 Twice (4561f7ca).
- Old row changed: a61f94fd "W14-25 Decimal kcal" calories null → 251 (25-005), and protein_g 12.25 → 12.3 as a side effect of Edit Meal (113-003).
- No accounts created.
