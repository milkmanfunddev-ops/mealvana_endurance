# Wave 2 (fix wave) handoff — paused 2026-10-07 by Lee; resumed and closed out 2026-10-08

## Close-out (2026-10-08, lead)
- Review fixes committed (`c22ff8d1`) and merged `--no-ff` (`b24c1242`); gates on the fix tree: codegen clean, analyze 977 (baseline), touched folders 1132 + 516 tests green, Deno 17 green. Worktree and branch removed.
- Dev deploys done from the merged tree (13 functions, exit 0). `REVENUECAT_SECRET_KEY` was already on dev with the same digest as `secrets/revenuecat.env`. One real Describe call (test@test.com, 02:15Z): 200, wallet 2494→2493, `ai_usage` row written, `query_logs` shows no "Failed to log ai usage" and no error.
- Lead Findings filed: 22-001 (consumeLegacyResumeTap uncalled, bug), 22-002 (pullNative never reloads, followup-test → ticket 32), 29-001 (override save wiped profile fields, bug, fixed by 29).
- Tickets 21–29: "fixed, awaiting retest (wave 2, 2026-10-07)"; 24 → retest home 31; 25 return-rows box accepted.
- IMPROVEMENTS #108–#111 added.
- The ops repo (`../ops`) is not checked out on this machine, so the current bundle runbook status header could not be read before the deploys; the deploys were dev-only function redeploys named by this handoff.
- Still owed: Lee's go for the push; `/design-sync`; Xuan's prod blocker; the 13 product questions below; wave 3.

Resume with `/testing-wave develop-2026-10` (continue wave 2; do NOT open a new wave). Lead on Fable, agents on Opus.
Everything lives in the develop-next worktree `../mealvana_endurance-waves/branch-split/develop-next` (branch `develop-next`); the main clone is on `sentry`, leave it alone.

## Done (all merged into develop-next, HEAD `4337d17e` + whatever follows)
- 29 backport (34 items, 16 predecessors, Drift v22→v23→v24), 25, 24, 28, 26+27 (jade-chat source → `supabase/functions/_archived/`, deployment kept), 21+22, 23. Per-item record: `runs/29/notes.md`.
- Dev wallet SQL (23 item 1) RUN on dev: 17 wallets `credit`, test@test.com 2,494. Ticket 21's email-lowercase SQL is a no-op on dev (nothing to run).
- Gates on the merged tree: codegen committed; `flutter analyze` 977 issues (baseline 988, nothing new); Deno 268 green on touched functions; ONE full suite: 5149 pass / 7 skip / 1 fail → fixed test-side (`4337d17e`, macro_dashboard folder re-run green). No second full suite (rule).
- `/security-review` on discard-signup, delete-user, Garmin backend: no findings.
- `/mattpocock-skills:code-review` since `ab437b7d`: report given in the terminal 2026-10-07 (Standards: 3 hard + 10 judgement; Spec: 1 real miss + 4 minor).

## In flight when paused
- Opus agent applying the review fixes on branch `testing-wave/develop-2026-10/review-fixes`, worktree `../mealvana_endurance-waves/testing-wave/develop-2026-10/review-fixes` (7 numbered fixes: FOA key move, content keys for literals, analytics out of two widgets, 3 D9 lines, after-Resend code text). On resume: `git log testing-wave/develop-2026-10/review-fixes -1`; if it has the `fix(review): …` commit, merge `--no-ff` into develop-next, run the touched folders + `test/shared` + Deno garmin/discard-signup, codegen if annotated files changed; then remove the worktree + branch. If it has no commit, check `git status` there and finish by hand or respawn.

## Still owed by the lead (in order)
1. Merge review fixes (above).
2. Dev deploys from the final tree, `./scripts/deploy_dev.sh <fn>`: discard-signup (new), delete-user, garmin-user-mapping, garmin-backfill, garmin-push, garmin-ping, garmin-deregistration, generate-nutrition-plan-v3, generate-macros-v4, ensure-credits, describe-meal, analyze-meal-photo, ai-coach. Set `REVENUECAT_SECRET_KEY` on dev first (key in `secrets/revenuecat.env`) or delete-user skips the RevenueCat customer delete (logged). Then: one Describe call (ticket 31 retest) and `query_logs` shows no "Failed to log ai usage"; one real read for any changed PostgREST select.
3. Lead-filed Findings (`FINDINGS new …`): (i) `NotificationService.consumeLegacyResumeTap()` has no caller → backgrounded taps never collected, `ios_un_response_payload`/`ios_legacy_resume_payload` never cleared; (ii) `pullNative()` never calls SharedPreferences `reload()` → iOS writes during a session may never be seen (unverified; retest 32); (iii) develop's `saveNutritionTargetOverrides` silently wiped body fat / lifestyle / training phase / sweat test / Garmin timestamps on every override save (fixed by `e663c3bb` brought in 29; record it in BUGS via the Finding).
4. Ticket statuses: 21–29 stay `in-progress` until their retests pass on a simulator (30–33, wave 3); write "fixed, awaiting retest (wave 2, 2026-10-07)" into each. Mark 24's retest home = 31; 25's "return rows" box accepted (real zero, no push sent that day).
5. IMPROVEMENTS.md: what wave 2 taught (sequential agents by area for a backport; `--allow-all` vs `--allow-sys`; tearDown runs after the pending-timer check; agents report product questions in commit bodies).
6. Commit everything with explicit paths. Push waits for Lee's go (a develop push cuts a build).
7. Next wave = wave 3 (test wave): rebuild (lib changed), tickets 30–33 + untouched 03–07, 09–19, at the simulator cap.

## Owed by Lee / Xuan
- Lee: `/design-sync` (kyle_design: kyle_input_field, kyle_date_header, materials/glass, kyle_sheet_header, segmented_control, kyle_source_chip; theme/kyle_design: app_materials, app_theme, me_surface_tokens).
- Xuan (cutover, BLOCKER for prod): `meal_logs.servings` migration + `app_config` schema 23 then 24 before any v24 build talks to prod.

## Product questions for Lee (from agents' commit bodies and the review; none resolved)
a. Sign-out/delete confirms now read `settings.*` keys with mealplanning's text (delete body differs from develop's old text).
b. Log In on an unconfirmed account that is then verified finishes as a login keeping the onboarding draft (mealplanning picks signup/login by draft).
c. RevenueCat `logOut` still runs before the Supabase sign-out; and delete-user now deletes the RevenueCat customer (t95) — develop wants this? (review: undecided)
d. A device that ran mealplanning's Drift v23/v24 never gets develop's `activities.duration_source` step.
e. OneSignal opt-out heal now runs only once signed in (was every launch).
f. First permission answer before a local profile exists is not stored (a Note is written).
g. Profile save no longer sends `email` (e3d5e3f5).
h. After a Resend, a refused code text (review fix changes it to "not right, or from an earlier email"); wording unapproved. No `error_rate_limited` key (429 = silent countdown). `error_resend_failed` / `error_generic` wording unapproved.
i. Rule-based formula-kit insight stays free; only a model call costs 1.
j. Learn's Notify Me promises "We'll let you know"; nothing reads the event.
k. Stored sync-error text (`plainSyncErrorMessage`, Garmin reauth text) lives in code and on the server row: needs a key-based design (ticket).
l. 24: the swap path and `MealItemsEditor` still fold quantity into the portion text.
m. Naive timestamps still sent by coach, food_preferences, feedback, user foods, carb loading, activities, events, nutrition_plans, personal templates (ticket 22 closing note).
