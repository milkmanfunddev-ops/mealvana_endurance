# 30: Retest: auth and account

**Status:** ready (round develop-2026-10, retest)
**Labels:** retest, round:develop-2026-10, area:account
**Branch:** `develop-next` (worktree per ticket, branched from the round's base after the fix wave lands)
**Source:** TRIAGE.md rulings of 2026-10-07: followups 01-007 (rewritten), 01-010, 01-014, 01-015, 01-016,
01-017, 01-018; fix retests for ticket 21 (01-002, 01-003, 01-005, 01-009) and ticket 22 (01-004, 01-006)
**Blocked by:** the fix wave (tickets 21–29) and its rebuild; runs in wave 3
**Next:** `/testing-wave develop-2026-10 --only 30`
**Model:** opus

**What to test:** Part 30a proves the signup fixes on one fresh email signup: a wrong code says it is
wrong, Resend sends a new email, normal signup outcomes stay out of Sentry, the stored email is
lowercase, the `created_at` columns hold UTC, and the first Timeline sends no `DashboardTargetsAnomaly`
error. Part 30b runs the followups from ticket 01: the other ways through Verify your email and
Create account, Delete Account under failure, onboarding back navigation, the daily-plan preview
numbers, the notification prompt after a delete, and the strict-regime consent screen, reached the way
Lee ruled.

**13 checks, more than the ten SPEC.md allows.** 30a (6 fix retests) and 30b (7 followups) share
nothing but the app; the lead may cut them into two tickets (`30a`, `30b`), each with its own
simulator. Run as one ticket, 30a goes first.

**Runs by:** `docs/testing-wave/RUNBOOK.md`. RUNS = `.scratch/testing-wave/rounds/develop-2026-10/runs/30/`,
Findings in `.scratch/testing-wave/rounds/develop-2026-10/findings/`. One slot, console to RUNS, a
look-around on every screen, every problem a Finding, nothing fixed.

**Accounts:** new ones only, `lee+e2e-30-<UTC time>@rightpathprogramming.com`, each made with `CRED new`
before signup: A (30a), B (30b, Verify-your-email paths and the delete failures), C (30b, consent), plus
the anonymous user that "Continue without an account" makes (30b-3). No shared account.

**App data:** cleared by the wave lead (opens signed out on Welcome). The first launch fills the region
cache (01-007 found it survives account delete), so check 30b-7 empties the three region keys itself,
as written there. The agent never clears or reinstalls.

**Cost:** no AI call. (The credits wallet is provisioned on the first wallet read; that is not an AI call.)

**Retest rule.** A check that passes closes the Finding named beside it: write `PASS <id>` in
`RUNS/notes.md` with the evidence, and the lead marks the Finding `closed`. A check that fails files a
new Finding with `findings.mjs new 30 … --round develop-2026-10` whose Evidence cites the old id
(`Retest of 01-NNN`). A fix ticket closes when every check under it passes.

## Read before the run

- Fix ticket 21's file in `ROUND/issues/`. It does not remove the anonymous upgrade and does not fix
  its resend (`OtpType.emailChange`); Lee ruled that path is going away. Build My Plan still signs in
  anonymously, so Create Account normally takes the upgrade. The plain signup (`supabase.auth.signUp`,
  `OtpType.signup`), whose Resend ticket 21 fixes, runs only when no session exists at Create Account.
  30a step 1 forces that by failing the anonymous sign-in. A Resend that sends nothing on the upgrade
  path is the known, out-of-scope half of 01-003: note it, do not file it again.
- Fix ticket 22's file (the `created_at` writes and the transient threshold for 01-006).
- CLAUDE.md's notification rule for 30b-5: `.claude/skills/notification-testing/` and
  `../ops/docs/messaging-relay-and-testing.md` do not exist on develop-next (ticket 17 files that idea;
  do not file it again). Work from the code; nothing here needs a push.

## Screens (from code, unverified; check each on the screen)

| Screen | Route / entry | Code |
|---|---|---|
| Welcome | `/welcome`, "Build My Plan" / "I already have an account" | `lib/features/onboarding/presentation/screens/welcome_screen.dart` |
| Analytics consent | `/privacy-consent?next=/onboarding`, pushed by Welcome when `needsPrompt` | `lib/features/privacy/presentation/screens/privacy_consent_screen.dart` |
| Onboarding pages, ending in "Your daily plan" | `/onboarding` page view | `lib/features/onboarding/presentation/screens/onboarding_pageview_screen.dart` |
| Create account | `/auth/post-onboarding` → "Use Email Instead" → `/auth/email-signup` | `lib/features/auth/presentation/screens/{post_onboarding_auth,email_signup}_screen.dart` |
| Verify your email | pushed by email signup | `lib/features/auth/presentation/screens/verify_email_screen.dart` |
| Timeline | `/main` | `lib/shared/widgets/tabs_screen.dart` |
| Settings → Account → Delete Account; Settings → Privacy | gear on the Timeline header → `/settings` | `lib/features/settings/presentation/screens/settings_screen.dart`, `.../providers/settings_controller.dart` (`deleteAccount`) |

## Expected records (`RUNS/expected.md`, before the first tap)

- Every signup: after the code, `auth.users.email_confirmed_at` set; `public.users.email` equals
  `auth.users.email`, both lowercase (01-009); `public.users.created_at`,
  `daily_macro_targets.created_at` (first row) and `onboarding_surveys.created_at` each within 2 minutes
  of `email_confirmed_at` (01-004). Name the columns; never `SELECT *`.
- Resend: `auth.users.confirmation_sent_at` (plain signup) or `email_change_sent_at` (if an upgrade path
  remains) moves to the resend time, and a second code email arrives within 2 minutes (01-003).
- Console: no `error_reported` with `exception_type` `EmailVerificationRequiredException`,
  `InvalidVerificationCodeException` or `DashboardTargetsAnomaly` (01-005, 01-006). A breadcrumb or
  info line is fine.
- After every delete: `node scripts/testing-wave/sweep-accounts.mjs footprint <user id>` reports no rows;
  the auth user is gone.
- Consent (30b-7): Decline stores `analytics_consent_status=denied`, `analytics_consent_regime=strict`,
  `analytics_consent_at=<ISO time>`, `analytics_consent_version=1` (prefs keys carry the `flutter.`
  prefix on disk). A failed lookup on an empty cache stores `privacy_region_source=device` and no
  `privacy_geo_*` keys.

## Steps, 30a: fix retests (account A)

1. `CRED new lee+e2e-30-<UTC>@rightpathprogramming.com --ticket 30 --run RUN`. Force the plain signup:
   `netcut.sh launch UDID SCRATCH`, `netcut.sh on SCRATCH`, then Welcome → Build My Plan (the anonymous
   sign-in fails; from code, `welcome_screen.dart` continues into onboarding regardless). Once the first
   onboarding page shows, `netcut.sh off SCRATCH`. Check the console for the failed anonymous sign-in.
   If onboarding does not open offline, write that, `netcut.sh off`, and run 30a on the upgrade path
   instead, skipping step 4's verdict (Resend there is out of scope).
   On "Tell us about yourself" type the address with capitals in it (e.g. `Lee+E2E-30-…`). Walk
   onboarding with plausible answers.
2. Create account → Use Email Instead. Type the same mixed-case address; `CRED type` the password.
   SQL for the new id: `is_anonymous`, `email`, `email_change`, `confirmation_sent_at`,
   `email_change_sent_at`. Pass for the setup: `is_anonymous` false and `email` set (the plain signup).
   Write in notes which path this was.
3. **01-002 (ticket 21).** Type a wrong code (the real one with its last digit changed) and tap Verify.
   Pass: refused, and the message says the code is wrong, not expired. Screenshot.
4. **01-003 (ticket 21).** Wait out the Resend countdown, tap Resend. Pass: a second code email arrives
   within 2 minutes (Gmail tool, `to:<address> from:support@mealvana.io`) and the sent-at column moves.
   If the server refuses (rate limit), the screen must say so; success with no email is a fail. Then type
   the newest code.
5. **01-005 (ticket 21).** Read the console from Create Account to here. Pass: no `error_reported` for
   the code-sent or wrong-code outcomes. Also search the dev Sentry project (Sentry MCP, read-only) for
   those two exception types in the run's minutes: none new.
6. **01-009 (ticket 21).** SQL: `public.users.email` is the lowercase address and equals `auth.users.email`.
   Also run one read for rows ticket 21's one-off SQL should have fixed: `select count(*) from public.users
   where email <> lower(email)` (expect 0).
7. **01-004 (ticket 22).** SQL right after landing on the Timeline: the three `created_at` columns vs
   `email_confirmed_at` (simulator time zone is the Mac's, CDT). Pass: all within 2 minutes.
8. **01-006 (ticket 22).** Console for the first Timeline: `[macro_dashboard]` lines. Pass: no
   `error_reported … DashboardTargetsAnomaly` when the transient resolves under ticket 22's threshold
   (record its `duration_ms`).
9. Settings → Account → Delete Account → Delete. Land on Welcome. `footprint` reports nothing.
   `CRED update <A> --state deleted`. A failed delete is a hard stop (`STOPPED.md`).

## Steps, 30b: followups

Order: 7(i) first, then 1-6 (B's signup runs with the region host held), then 7(ii) and the
anonymous pass of step 3.

1. **01-017.** Welcome → Build My Plan (account B). On every onboarding page tap Back once and come
   forward: answers kept? Continue on the sports page with nothing selected: says what is missing?
   Skip every optional field. In the element list: is "Build My Plan" a button with a label; does the
   Last name field keep its label once typed in?
2. **01-018.** On "Your daily plan", record the Workout day and Rest day carbs, protein, fat and kcal for
   the inputs you entered (weight, sports, goal, gut, sweat). Compare with `docs/ssot/` (read
   `PRE-WORKOUT-BUNDLE-DIGEST.md` first, then `spec/` and `vectors/`). A number that contradicts a
   ratified rule is an `ssot-conflict` Finding with the quote; no rule covering these daily targets is
   written as such in notes (the lead closes or rewrites the followup).
3. **01-015.** At Create account: tap Back (answers kept?). Continue with Google, cancel the sheet;
   Continue with Apple, cancel: back on this screen, no error box, no `error_reported`. "Continue without
   an account" still exists (ticket 21 leaves the anonymous path): use it on a fresh pass at the end of
   30b: Timeline as anonymous, then Delete Account; `footprint` on the anonymous id reports nothing, and
   the anonymous auth user is gone.
4. **01-014.** Email signup as B. On Verify your email: (a) "Use a different email" goes back to the form
   and the first address does not stay pending in `auth.users` for this id; (b) close the screen before
   the code: where is the athlete, and can they get back to the code entry; (c) terminate on the code
   screen and relaunch: where it opens, does the code still work; (d) with `netcut.sh on SCRATCH` type
   the code: message and retry after `netcut.sh off`. (e) Expired code: note the first code's send time;
   if 60 minutes pass before the run ends, try it and read the message ("expired" is right here);
   otherwise write "not seen live". Finish the signup.
5. **01-010.** Run this right after the first delete of the run (30a step 9, or 6(b)/(d) when 30b runs
   as its own ticket). After the delete lands on Welcome, terminate and relaunch. Record whether the iOS notification prompt appears on the signed-out Welcome and what the athlete was
   told before it. Leave it up about 10 s, answer Don't Allow. Pass for ticket 22's half: the console's
   `Slow operation: deferred.notifications` (if logged) excludes the prompt's wait and no `SlowOperation`
   `error_reported` follows it. When the prompt appears is the followup's half: a prompt on a signed-out
   relaunch is a bug Finding citing 01-010.
6. **01-016**, on B (signed in): (a) "I already have an account" → sign up again at B's address while B
   is live: clear error, no second account. (b) `netcut.sh launch UDID SCRATCH`, then `netcut.sh on
   SCRATCH`, Settings → Delete Account → Delete. Record what the screen says and where it lands, then SQL:
   does B still exist on the server? From code, unverified: a failed `delete-user` is logged and local
   cleanup continues to Welcome, which would leave B alive with the athlete told nothing; that is a bug
   Finding. `netcut.sh off`. If B survived, sign in as B and delete it properly. (c) On the confirm dialog
   tap Delete twice fast: one delete-user request (edge log through the Supabase MCP `query_logs`, the
   runbook step 6 query), no error. (d) After the delete: "I already have an account" with B's address
   and old password: a clear error.
7. **01-007 (rewritten by Lee).** The consent screen is reached by failing the geo lookup or by a
   strict-country geo answer, never by setting the locale. From code (unverified; `privacy_region.dart`,
   `privacy_region_service.dart`, `analytics_consent.dart`, `welcome_screen.dart`): startup calls
   `ensureResolved()`, which GETs `https://app.mealvana.io/api/region` (`REGION_ENDPOINT` is a build-time
   define, so a run cannot point it elsewhere) with a 2 s timeout. A 200 with a country caches
   `privacy_region_source=geo` and `privacy_geo_country`; a timeout or non-200 on an empty cache stores
   `privacy_region_source=device`, and a warm `geo` cache is never overwritten by a failure. Welcome →
   Build My Plan pushes `/privacy-consent?next=/onboarding` only when the regime is strict and consent is
   unknown. The only host to cut is `app.mealvana.io`.
   - **(i) Failed lookup, empty cache.** Signed out on Welcome. `netcut.sh launch UDID SCRATCH` (if not
     already), terminate the app, and empty the cache `ensureResolved()` filled on earlier launches:
     `xcrun simctl spawn UDID defaults delete com.milkman.mealvanaendurance.dev <key>` for
     `flutter.privacy_region_source`, `flutter.privacy_geo_country`, `flutter.privacy_geo_region` (and
     `flutter.privacy_region_at`). These device-only deletes are named by this ticket; they touch no
     server. Then `netcut.sh slow 3000 SCRATCH --only app.mealvana.io --relaunch UDID` (the lookup times
     out at 2 s; Supabase and everything else answer). Check `SCRATCH/slowproxy.log` shows the region host
     held. Terminate the app, read the prefs key names and the
     `privacy_region_*` values only (python `plistlib` on the container's
     `Library/Preferences/com.milkman.mealvanaendurance.dev.plist`; print nothing else, the file holds the
     session). Expect `source=device`. On this en_US simulator in CDT the fallback resolves `standard`, so no
     consent screen on Build My Plan, and with `source=device` there is no implied grant. Run 7(i) at the
     start of 30b and do steps 1-4 (account B) under it; once B lands on the Timeline, Settings → Privacy
     must show usage data OFF. A consent screen, or ON, is a bug Finding. `netcut.sh off SCRATCH` before
     step 5.
   - **(ii) A strict-country geo answer.** The code reads the regime from the cached geo answer, so the
     run fakes a GB answer in the cache and keeps the region host held so the background refresh cannot
     replace it. App terminated: `xcrun simctl spawn UDID defaults write com.milkman.mealvanaendurance.dev
     flutter.privacy_region_source -string geo`, the same for `flutter.privacy_geo_country -string GB`,
     and `defaults delete … flutter.privacy_geo_region`. This is a device-only write this ticket names; it
     touches no server. Relaunch with `netcut.sh slow 3000 SCRATCH --only app.mealvana.io --relaunch UDID`
     still in force; read the three keys back. Welcome → Build My Plan: the analytics consent screen comes
     before onboarding. Take Decline. Finish signup as C (`CRED new` first). Read the
     `analytics_consent_*` keys; Settings → Privacy shows usage data OFF. Delete C. `netcut.sh off SCRATCH`.
   - If (ii)'s keys do not hold (the app rewrites them, or reads them from somewhere else), write what you
     saw and do not try a locale or a time-zone change instead.

## What counts as a Finding

- A 30a check that fails: a new bug Finding citing the old id.
- A wrong code accepted; a code email over 2 minutes late; Resend that reports success and sends nothing.
- Rows left after any delete; a delete that reports success while the server account remains; a double
  delete; Cancel that deletes.
- A consent screen in 7(i), none in 7(ii), or stored values that differ from the expected records.
- Console errors on any visited screen (or "known noise: <why>" in notes). Look-around paths as
  followup-test Findings.

## Exit

- [ ] Findings filed with `node scripts/testing-wave/findings.mjs new 30 "<one line>" --round develop-2026-10 --kind bug|ssot-conflict|followup-test|idea --run RUN`, every field filled; `findings.mjs index --round develop-2026-10 --out "$TMPDIR/tw-30-index.md"` exits clean.
- [ ] `RUNS/notes.md` lists each check with `PASS <id>` or the new Finding's id, so the lead can close or keep each old Finding.
- [ ] Every account this run made is deleted in the app and marked `CRED update <address> --state deleted` (`delete-failed` if it failed). An address that never finished signup (01-014's "different email" pass may leave one) goes under "Leftover accounts" in `RUNS/notes.md` with its auth user id.
- [ ] `netcut.sh off SCRATCH`; background processes stopped by PID (the slow proxy's PID is in `SCRATCH/slowproxy.pid`), log stream stopped, app terminated, `LOCK release slot testing-wave-30`. The simulator is left for the wave lead to drop.
- [ ] Console redacted (runbook § 9.4); only `console-redacted.log` is kept. Prefs reads saved as key names and the named values only.
- [ ] `findings/30-*.md` and `runs/30/` committed on the ticket branch, explicit paths only.
