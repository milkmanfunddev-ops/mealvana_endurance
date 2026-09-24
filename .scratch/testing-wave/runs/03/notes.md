# Ticket 03, run w3-20260923T1942Z: notes

## Setup
- Worktree env: `.env`, `.env.dev.local`, `.env.prod.local` and `secrets/integration_test.env`
  copied from the main clone (gitignored, not committed). The admin credentials for the later
  runs went into a define file in the session scratchpad, outside the repo.
- Patrol 4.10.0 / patrol_cli 4.8.0. Every run: `--flavor dev --dart-define-from-file=.env.dev.local`;
  from the clean-install runs on, `--bundle-id com.milkman.mealvanaendurance.dev` too.
- Device logs (`device-*.log`) are `simctl log stream` of the Runner process, filtered to
  `flutter:` lines after the first capture.

## What the run changed on dev (writes the flows make by design)
- Flows created and deleted their own rows on the admin account (activities, bricks, events,
  formulas, meal logs). One row is left: meal log "Patrol Build 1790210521428" (admin,
  1 item), from the meal_log_build run that failed before its cleanup (db-meal-log-build-row.txt).
- meal_plan_build confirmed the admin's existing draft plan, which archives the admin's other
  plans for that week (mp-241).
- Two lee+e2e-signup-* accounts left (onboarding_signup does not delete its account); both are
  in the credentials file and sweepable. account_delete's two accounts are gone.

## Console lines and what they are
- `[RevenueCatService] logIn skipped: SDK not configured` in the Patrol runs: RevenueCat is not
  configured inside the Patrol test app on some launches; noted, the gate still answered.
- TrainingPeaks `Token refresh failed (status: 400) invalid_grant` for the admin: a stale
  TrainingPeaks connection on test@test.com; environment, not this ticket.
- Swift Package Manager plugin warnings at build: toolchain noise.
- The `customer info updated {active: true, expires_at: 2027-09-15…}` line while signed out:
  03-002.

## Look-around
Patrol, not a person, visited the screens here: Welcome, onboarding steps through Plan Reveal and
Save My Plan, Sign Up with Email, Log In, Paywall and its ⋯ menu, Timeline, Food (Plan, Shopping),
Vana chat, My Events and the event form, Formulas, Learn, Settings and its sub-screens, Connect
Training. What the run itself turned up is in 03-001 to 03-009; the paths not taken on those
screens are already Follow-up tests from ticket 02 (paywall menu, sign-in errors, delete account)
or are 03-005 and 03-006. No further Follow-up tests were written from Patrol-only visits.
