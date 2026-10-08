# 50-005 · Welcome renders for a signed-in athlete and offers Build My Plan and Log In over the live session (32-012)

- kind: bug
- status: closed
- ticket: 50
- run: w5-20261008T1720Z
- screen: Welcome
- decision: 

**Steps.**
1. test@test.com signed in (signed-in cold start), on Event Details.
2. `xcrun simctl openurl UDID "com.milkman.mealvanaendurance:///welcome"` → Open.
3. Tap "I already have an account"; then Back.

**Expected.**
A signed-in athlete is never offered onboarding (32-012): `/welcome` with a session redirects to the Timeline,
or at least offers no Build My Plan.

**Actual.**
Welcome renders in full ("Get more out of every session.", Build My Plan, I already have an account). "I already
have an account" opens Log In (Apple / Google / Log in with email) while signed in; Back returns to Welcome, and
nothing on the screen leads back to the Timeline (left by deep-linking `/main`). Build My Plan was not tapped: from
code (unverified) it reuses the live session (`onboarding_session_controller.dart:80-98`) and starts onboarding,
which writes onboarding drafts on this shared account. From code (unverified): `/welcome` is a public route that the
router never redirects (`app_router.dart:245-266`) and `WelcomeScreen` does not check the session. Page Not Found's
Go Home no longer leads here when signed in (check 4 passed), so the remaining way in is a link or a `go('/welcome')`.

**Evidence.**
- runs/50/l01-welcome-signed-in.png Welcome while signed in
- runs/50/l02-login-while-signed-in.png Log In offered while signed in

**Decision quote.**
> 

**Triage.**
- closed · retest passed or ran in wave 7 (ticket 67 check 6) · lead, 2026-10-09
