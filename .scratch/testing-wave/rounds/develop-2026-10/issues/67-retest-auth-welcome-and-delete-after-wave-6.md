# 67: Retest: auth, Welcome and delete after wave 6

**Status:** ready (round develop-2026-10, retest, wave 7)
**Labels:** retest, round:develop-2026-10, area:account
**Branch:** `develop-next` (worktree per ticket, branched from the round's base after fix wave 6 lands)
**Source:** TRIAGE.md rulings of 2026-10-08 (wave 5 triage): followups 48-004, 48-005, 48-006, 50-016; fix retests for tickets 55 (48-001), 56 (49-001, 50-005), 57 (48-003)
**Blocked by:** fix wave 6 (55, 56, 57) and its rebuild; runs in wave 7
**Next:** `/testing-wave develop-2026-10 --only 67`
**Model:** opus

**Runs by:** `docs/testing-wave/RUNBOOK.md`. RUNS = `.scratch/testing-wave/rounds/develop-2026-10/runs/67/`, Findings in `.scratch/testing-wave/rounds/develop-2026-10/findings/`. One slot, console to RUNS, a look-around on every screen capped at ONE followup-test Finding per screen (IMPROVEMENTS #115), every problem a Finding, nothing fixed.

**Retest rule.** A check that passes closes the Finding named beside it: `PASS <id>` in `RUNS/notes.md` with evidence; a fix ticket closes when every check under it passes. A check that fails files a new Finding citing the old id (`Retest of NN-NNN`).

**Secrets (#112).** Before every `CRED type`, a fresh screenshot shows the focused field is the password field; nothing fetched from the web; no personal address in any header.

**Accounts:** new ones only, `lee+e2e-67-<UTC time>@rightpathprogramming.com`, via `CRED new`: A (signed up and verified, deleted at the end) and B (left on Verify for check 5). Not here: 55's V.O2 Cancel half (50-007) runs in ticket 69; the Apple-relay half of ticket 36 stays with ticket 51 (Lee's phone); the held notification tap across sign-in (50-016 step 1) runs in ticket 69 check 2. **App data:** cleared by the lead. **Cost:** none.

**Start state for consent.** As ticket 48 reached it (runs/48/notes.md check 8): app terminated; `xcrun simctl spawn UDID defaults write <data container>/Library/Preferences/com.milkman.mealvanaendurance.dev flutter.privacy_geo_country -string GB` and `defaults delete … flutter.privacy_geo_region`, then `netcut.sh slow 3000 SCRATCH --only app.mealvana.io --relaunch UDID`. Write through `defaults`, never by editing the plist while cfprefsd holds it. `netcut.sh off SCRATCH` once Your privacy shows.

## Checks (10)

1. **48-005, first half.** From the consent start state, Build My Plan → Your privacy: switch Share usage data ON, Continue. Passes when prefs read `analytics_consent_status=granted` and the console sends `📊 [ANALYTICS]` events from the ON tap on.
2. **48-006.** Walk onboarding with `idb ui describe-all` saved on Tell us about yourself, Basic body composition and Nutrition Settings. Passes when each choice tile (MALE / FEMALE / NON-BINARY, Imperial / Metric, LOW / MODERATE / HIGH, LIGHT / MEDIUM / HEAVY) is a Button with a selected state, not StaticText. No wave-6 ticket touches these, so expect the 48-006 picture; a confirmed one is a bug Finding with the describe-all lines. VoiceOver itself is a device check (ticket 51).
3. **55 / 48-001.** On Create Your Account (the simulator has no Apple account), Continue with Apple, then Close on the iOS "Sign in to your Apple Account" sheet. Passes with no snackbar, no `error_reported`, an `expected_failure` (or breadcrumb) line in the console, and nothing new in the dev Sentry project (read-only) for that minute.
4. **Signup A.** Sign up with Email as A, verify with the mailed code, reach the Timeline. Then **48-005, second half:** Settings → Privacy shows the usage switch ON. Switch it OFF: prefs read `denied` and no further `📊 [ANALYTICS]` send follows over two screens. Mixpanel read-only for the run's distinct id if the lead has it open; the console otherwise. Leave it OFF.
5. **57 / 48-003.** Sign out → Welcome. Build My Plan → onboarding → Sign up with Email as B → Create Account → Verify your email → the hint's Log in. Change the address to A's, type A's password, Log In. Passes when the app lands on the Timeline signed in as A (no Sign Up form, no Create Your Account), and the pending-signup record is gone from the container plist (read it after a terminate; runs/48/prefs-pending-signup-before-relaunch.txt shows its keys). Record B's anonymous auth user id for the leftover sweep.
6. **56 / 50-005.** Signed in as A on the Timeline, `xcrun simctl openurl UDID "com.milkman.mealvanaendurance:///welcome"` → Open. Passes when the Timeline shows, not Welcome, so Build My Plan cannot be reached over the live session. This also answers 50-016 step 2: say so in notes and close that half.
7. **56 / 49-001.** Signed in, `openurl …:///settings/connected-apps`, then the top-left back arrow. Passes when it lands on the Timeline (trail `back fallback: canPop=false` is fine) and the session is the same one.
8. **56, signed-out half.** Settings → Sign Out → Sign out: lands on Welcome. Then `openurl …:///welcome` signed out: Welcome renders with Build My Plan. Both must still pass after the redirect change.
9. **48-004.** Delete-user answering a real 500: `netcut.sh slow` is not safe (no client timeout on `functions.invoke('delete-user')`, so a slowed reply deletes for real), and the slow proxy passes TLS through untouched, so it cannot rewrite a status. Write "needs a server-side fault injection, not run" unless the lead names a dev-only fault switch before the run. Expired code: only if a code this run has not used is still reachable on Verify 60 min after it was sent; the run lasts about 30 min, so expect "not seen live" and leave that half open with the reason.
10. **56, delete half.** Sign in as A, Settings → Delete Account → Delete. Passes when the app lands on Welcome, A's auth user is gone and the footprint read shows no rows (as runs/48/footprint-A.txt).

## Exit
- [ ] Findings filed with `node scripts/testing-wave/findings.mjs new 67 … --round develop-2026-10`; `findings.mjs index --round develop-2026-10 --out "$TMPDIR/tw-67-index.md"` exits clean.
- [ ] `RUNS/notes.md` lists each check with `PASS <id>`, the new Finding's id, or "not run" with its reason.
- [ ] A deleted in the app and `CRED update … --state deleted`; B's anonymous user named with its id for `sweep-accounts.mjs delete --id … --apply`, `CRED update … --state leftover`.
- [ ] Geo prefs removed from the container plist; `netcut.sh off SCRATCH`; helpers stopped by PID; log stream stopped; app terminated; `LOCK release slot testing-wave-67`; simulator released.
- [ ] Console redacted (runbook § 9.4). `findings/67-*.md` and `runs/67/` committed on the ticket branch, explicit paths.

Next: /testing-wave develop-2026-10 (wave 7)
