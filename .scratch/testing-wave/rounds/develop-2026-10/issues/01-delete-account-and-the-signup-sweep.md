# 01: Delete account, plus-address signup and the account sweep

**Status:** in-progress (wave 1, 2026-10-07)
**Labels:** test, round:develop-2026-10, area:account
**Branch:** `develop-next` (worktree per ticket, branched from the round's base)
**Source:** testing-wave 02 (`origin/mealplanning`), paywall-menu steps dropped
**Blocked by:** none.
**Next:** `/testing-wave develop-2026-10 --only 01`
**Model:** opus

**What to test:** A new athlete signs up at a plus address, confirms with the emailed code, reaches the
Timeline and deletes the account from Settings. Afterwards the dev database holds nothing for it.
Signing up again at the same address makes a new user. A third pass with the simulator's region set
to the United Kingdom meets the analytics consent screen first.

**Runs by:** `docs/testing-wave/RUNBOOK.md` on develop-next (until it lands there:
`git show origin/mealplanning:.scratch/testing-wave/RUNBOOK.md`). This round's paths: RUNS =
`.scratch/testing-wave/rounds/develop-2026-10/runs/01/`, Findings in
`.scratch/testing-wave/rounds/develop-2026-10/findings/`. One slot, console to RUNS, a look-around on
every screen, every problem a Finding, nothing fixed.

**Accounts:** new ones only, `lee+e2e-01-<UTC time>@rightpathprogramming.com`, made with `CRED new`
before signup. No shared account.

**App data:** cleared by the wave lead (opens signed out on Welcome).

## Not on develop-next

No paywall, no Pro gate, no redeem codes. The source ticket's "delete from the paywall's ⋯ menu",
"the Gate treats the new user as never paid" and the Patrol-flow criteria are dropped. A paywall,
"Go Pro" upsell or entitlement read seen anywhere in this run is a bug Finding.

## Screens (from code, unverified; check each on the screen)

| Screen | Route / entry | Code |
|---|---|---|
| Welcome | `/welcome`, "Build My Plan" / "I already have an account" | `lib/features/onboarding/presentation/screens/welcome_screen.dart` |
| Analytics consent (UK pass only) | `/privacy-consent?next=/onboarding` | `lib/features/privacy/presentation/screens/privacy_consent_screen.dart` |
| Onboarding pages | `/onboarding` page view: sports, personal info, body composition, goals, sport details, dietary preference, allergies, nutrition settings, pitfalls, daily plan preview, plan reveal | `lib/features/onboarding/presentation/screens/onboarding_pageview_screen.dart` |
| Create account | `/auth/post-onboarding` → "Use Email Instead" → `/auth/email-signup` | `lib/features/auth/presentation/screens/{post_onboarding_auth,email_signup}_screen.dart` |
| Verify your email | pushed by email signup | `lib/features/auth/presentation/screens/verify_email_screen.dart` |
| Timeline | `/main` | `lib/shared/widgets/tabs_screen.dart` |
| Settings → Account → "Delete Account" | gear on the Timeline header → `/settings` | `lib/features/settings/presentation/screens/settings_screen.dart` |

## Expected records (write to `RUNS/expected.md` before the first tap)

- Before signup: no `auth.users` row for the address.
- After the code: `auth.users.email_confirmed_at` set; one `public.users` row with that id. Record whether
  a `token_wallets` row appears (the credits wallet is provisioned on first wallet read).
- After delete: `node scripts/testing-wave/sweep-accounts.mjs footprint <user id>` reports no rows; the
  auth user is gone.
- RevenueCat: `delete-user` on develop-next makes no RevenueCat call (from code:
  `supabase/functions/delete-user/index.ts`). If the app created a customer for this user id (the credits
  service logs in to RevenueCat with the user id), it stays. Look it up by API and record its state.
  The earlier round filed this as 02-005; cite it if it recurs.
- Second signup, same address: a new user id, no rows carried over from the first.

## Steps

1. `CRED new lee+e2e-01-<UTC>@rightpathprogramming.com --ticket 01 --run RUN`.
2. Welcome → Build My Plan. Walk every onboarding page with plausible answers (run + bike, a real
   weight). On each page note what is prefilled; a field prefilled from another person is a bug (the
   earlier round's 02-001).
3. At account creation choose email, type the address, `CRED type` the password.
4. Before typing the code, SQL: `email_confirmed_at` is empty. Read the code with the Gmail tool
   (`to:<address> from:support@mealvana.io`, newest first). Note arrival time, subject, sender.
5. Type the code. Land on the Timeline. SQL: `email_confirmed_at` set, `public.users` row present.
6. Settings → Account → Delete Account. Cancel once on the confirm dialog: the account stays (SQL).
   Then Delete. Land on Welcome. SQL and `footprint`: nothing left. RevenueCat lookup.
   A failed delete is a hard stop: write the Finding, `STOPPED.md`, go to Exit.
7. Sign up again at the same address (`CRED update <address> --new-password` first if the old one is
   refused, or reuse it). New user id by SQL. Delete it again the same way.
8. UK pass: set the simulator's region (`xcrun simctl spawn UDID defaults write -g AppleLocale en_GB`),
   terminate and relaunch the app. Welcome → Build My Plan. The analytics consent screen comes before
   onboarding (read `lib/shared/services/privacy/privacy_region.dart` and
   `analytics_consent.dart` first and write what Accept and Decline should store). Take Decline, finish
   signup at a third `lee+e2e-01-…` address, check what was stored, delete the account. Set the region
   back (`defaults write -g AppleLocale en_US`).
9. `node scripts/testing-wave/sweep-accounts.mjs list`: no `lee+e2e-01-*` account from this run remains.

## What counts as a Finding

- Any screen that shows a paywall, entitlement or Pro wording.
- A code email over 2 minutes late or missing; a wrong code accepted; a resend that does nothing.
- Rows left after delete, a delete that reports success while the server account remains (the earlier
  round's 121-007), a delete with no confirmation, Cancel that deletes.
- A consent screen missing in the UK pass, or shown in the US pass.
- Console errors on any visited screen (or "known noise: <why>" in notes).
- Look-around paths on each screen as followup-test Findings.

**Earlier Findings for the source ticket:**
`git ls-tree --name-only origin/mealplanning .scratch/testing-wave/findings/ | grep '/02-'`. Read the titles
first. Most of that round's fixes never reached develop-next, so a recurrence cites the old id under
Evidence.

## Exit

- [ ] Findings filed with `node scripts/testing-wave/findings.mjs new 01 "<one line>" --round develop-2026-10 --kind bug|ssot-conflict|followup-test|idea --run RUN`, every field filled; `findings.mjs index --round develop-2026-10 --out "$TMPDIR/tw-01-index.md"` exits clean.
- [ ] Every account this run made is deleted in the app and marked `CRED update <address> --state deleted` (`delete-failed` if it failed). An address that never finished signup goes under "Leftover accounts" in `RUNS/notes.md` with its auth user id.
- [ ] Background processes stopped by PID, log stream stopped, app terminated, `LOCK release slot testing-wave-01`. The simulator is left for the wave lead to drop.
- [ ] Console redacted (runbook § 9.4); only `console-redacted.log` is kept.
- [ ] `findings/01-*.md` and `runs/01/` committed on the ticket branch, explicit paths only.
