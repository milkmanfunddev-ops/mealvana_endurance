# 88: Retest: auth and onboarding after wave 8, part 2 (test@test.com: write-back notice and Food Likes & Dislikes)

**Status:** ready (round develop-2026-10, test wave 9, after the wave-8 rebuild)
**Labels:** retest, round:develop-2026-10, area:account, area:settings, area:sync, area:integrations
**Branch:** `develop-next` (worktree per ticket, branched from the round's base after fix wave 8 lands)
**Source:** TRIAGE.md rulings of 2026-10-09 (wave 7 triage) and the wave-8 fix tickets' retest lines: followup 69-014 (retest ticket A, overflow from ticket 85); fix retest for ticket 78 (68-001)
**Blocked by:** fix wave 8 (landed 4b146f27) and its rebuild, and 78's close SQL (done 2026-10-09: test@test.com holds 9 rows, no `fig_bar`); runs in wave 9 only if the three-simulator cap allows (85, 86 and 87 take the three slots first), else in the next test wave
**Next:** `/testing-wave develop-2026-10 --only 88`
**Model:** opus

**Runs by:** `docs/testing-wave/RUNBOOK.md`. RUNS = `.scratch/testing-wave/rounds/develop-2026-10/runs/88/`, Findings in `.scratch/testing-wave/rounds/develop-2026-10/findings/`. One slot, console to RUNS, a look-around on every screen capped at ONE followup-test Finding per screen (IMPROVEMENTS #115), every problem a Finding, nothing fixed.

**Retest rule.** A check that passes closes the Finding named beside it: `PASS <id>` in `RUNS/notes.md` with evidence; a fix ticket closes when every check under it passes (78: checks 2 and 3). A check that fails files a new Finding citing the old id (`Retest of NN-NNN`). Every UI line and console line quoted below was read from code at `4b146f27`; a screen that shows other words is a fail, not a paraphrase. Food names on Food Likes & Dislikes come from `template_foods`; match each by its key (`sports_drink`, `granola_bar`), not by the words this ticket uses.

**Secrets (#112).** Before every `CRED type`, a fresh screenshot shows the focused field is the password field; nothing fetched from the web; no personal address in any header.

**Accounts:** the dev test account (`CRED type test@test.com --udid UDID`): both checks need its existing rows (its TrainingPeaks connection and its nine `food_preferences` rows). Ticket 86 logs meals and ticket 87 works Connected Apps on the same account in the same wave; check only rows this run writes, and if ticket 87 has TrainingPeaks disconnected when check 1 starts, check 1 is "not run" with the `integrations` read as the reason. Sign Out here is local to this simulator (the client's `signOut()` uses the local scope). No RevenueCat writes. **App data:** cleared by the lead. **Cost:** none. **Dev reads:** `SELECT` with named columns only (RUNBOOK §6); on `integrations` never a token column.

## Checks (3)

1. **69-014.** Before signing in, read test@test.com's TrainingPeaks row (`select id, provider, is_active, last_sync_status, updated_at from integrations where user_id = … and provider = 'training_peaks'`). From the cleared app, I already have an account → Log in with email → test@test.com. Record whether "Your fuel plan goes to your coach" shows on the first Timeline. If it shows, close it with its X (the sheet reads "Closing this leaves sharing on."), terminate, and read `flutter.tp_writeback_notice_shown` and `flutter.tp_writeback_enabled` from the plist. Relaunch: record whether it shows again. Settings → Sign Out → Sign out, Log In again as test@test.com on the same simulator: record whether it shows. Read the TrainingPeaks row again. Passes when the sheet shows at most once on this install, Close leaves `flutter.tp_writeback_enabled` true, and the row's `is_active` and `updated_at` are unchanged. From code the notice is per install: `TabsScreen` shows it when `tp_writeback_notice_shown` is unset and TrainingPeaks is active, and sets the flag after any answer, Close included; an app clear resets it. Write that down; whether it should be per athlete instead is Lee's call (see Lead notes), so a sheet after the clear is not by itself a fail.
2. **78 / 68-001, one food moved.** Read `food_preferences` for test@test.com (`id, food_name, preference, preference_level, created_at, updated_at`; expect 9 rows, no `fig_bar`) into `RUNS/db-food-preferences-before.txt`. Settings → Diet, Allergies & Formulas → Food Likes & Dislikes. Move `sports_drink` one level, leave Show more food options closed, Save Changes. Read again. Passes when the server still holds 9 rows; only `sports_drink` changed (new level, new `updated_at` at `+00` equal to the save's UTC wall clock), its `id` and `created_at` are unchanged, every other row's `id`, `created_at` and `updated_at` are unchanged, and no `fig_bar`, `carb_drink_mix`, `energy_chews_mini_pack`, `granola_bar` or `high_carb_drink_mix` row appears. The console's `📊 [ANALYTICS] food_preferences_saved` carries `changed_foods: 1` beside `total_foods`.
3. **78 / 68-001, no-op and a new food.** Open Food Likes & Dislikes again and Save Changes without moving anything. Passes when nothing on the server changes (read again) and `food_preferences_saved` carries `changed_foods: 0`. Then move `granola_bar` (no row) to Like, Save Changes. Passes when exactly one new row appears (`granola_bar`, `preference like`), the other nine rows are untouched, and `changed_foods` is 1. Then put `sports_drink` back to its check-2 level, Save, and read the rows once more into `RUNS/db-food-preferences-end.txt`. `granola_bar` stays as a leftover row; name it in notes for the lead's close SQL.

## Exit
- [ ] Findings filed with `node scripts/testing-wave/findings.mjs new 88 … --round develop-2026-10`; `findings.mjs index --round develop-2026-10 --out "$TMPDIR/tw-88-index.md"` exits clean.
- [ ] `RUNS/notes.md` lists each check with `PASS <id>`, the new Finding's id, or "not run" with its reason.
- [ ] `sports_drink` restored (row read); `granola_bar` named as a leftover row by user and food key.
- [ ] Helpers stopped by PID; log stream stopped; app terminated; `LOCK release slot testing-wave-88`; simulator released.
- [ ] Console redacted (runbook § 9.4). `findings/88-*.md` and `runs/88/` committed on the ticket branch, explicit paths.

## Lead notes
1. **69-014 needs a product call.** From code the write-back notice is per install, and it comes back for an already-connected athlete after every app clear or reinstall. The Finding asks per device or per athlete. Should Lee rule on it at the wave-9 triage, whatever check 1 records?
2. **Shared account with 86 and 87.** If ticket 87 disconnects TrainingPeaks before check 1 runs, check 1 cannot show the sheet. Should 88 start before 87's Connected Apps section, or should the lead order the slots?
3. **The `granola_bar` row.** Check 3 leaves one new row on test@test.com. Should the lead delete it at the close (by user and food key, as 78's Deploy SQL does), or keep it as part of the account's set?
4. **Wave fit.** 85, 86 and 87 fill the three simulators. If 88 has to wait for a later test wave, 78 and 69-014 stay open until then. Is that acceptable, or should 88 replace a lower-priority ticket in wave 9?

## Lead rulings at the wave-8 close (2026-10-09)

- Runs in wave 10 (the cap), after 85, 86, 87; so no collision with 86 or 87 on test@test.com in wave 9.
- Note 1: Lee rules on per-device vs per-athlete at the triage after the run.
- Note 3: the lead deletes the new `granola_bar` row at the close, by user and food key.
- Note 4: 78 and 69-014 stay open until wave 10; accepted.
