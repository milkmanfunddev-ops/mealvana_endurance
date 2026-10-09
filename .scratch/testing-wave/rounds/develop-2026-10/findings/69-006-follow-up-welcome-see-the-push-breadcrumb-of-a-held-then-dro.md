# 69-006 · Follow-up: Welcome, see the push breadcrumb of a held-then-dropped tap on a Sentry event, and a tap held across a cancelled login

- kind: followup-test
- status: triaged
- ticket: 69
- run: w7-20261008T2311Z
- screen: Welcome
- decision: 

**Steps.**
1. Signed out on Welcome, push `reminder:<id>`, tap: tape `HELD … (no session)`. Log in, tape `DROPPED … (session
   changed: signed in)`. Then, in the same process, send one Debug console → "Sentry pipeline" probe and read that
   event's breadcrumbs in dev Sentry: the HELD and DROPPED lines should be there with category `push`. (Run 69 saw both
   tape lines, but no later Sentry event came from that process, so the breadcrumb itself was not seen.)
2. Held tap, then open Log In and go Back to Welcome without logging in, then sign up a new account instead: is the
   held tap dropped with `session changed: signed in` too?
3. Held tap, then kill the app before logging in: the next launch should show no replay (tape `previous` has the HELD
   line, `current` none).

**Expected.**
Every held tap ends in exactly one DROPPED or REPLAY line, and each tape line also reaches Sentry as a `push`
breadcrumb on the next event.

**Actual.**
Not run (step 1's tape half passed in check 2; the breadcrumb was not observable).

**Evidence.**
- runs/69/plist-after-tap-coldstart.txt HELD then DROPPED in launch_trail_previous
- runs/69/sentry-dev-23-16-to-23-31.txt no later event from that process

**Decision quote.**
> 

**Triage.**
- triaged · retest ticket A (auth, startup, Welcome, Sign Out; with fix ticket 53), cut after fix wave 8 for test wave 9 · Lee, 2026-10-09
