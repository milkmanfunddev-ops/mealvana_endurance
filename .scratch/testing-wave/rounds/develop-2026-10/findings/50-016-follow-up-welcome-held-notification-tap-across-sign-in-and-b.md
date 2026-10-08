# 50-016 · Follow-up: Welcome — held notification tap across sign-in, and Build My Plan over a live session on a disposable account

- kind: followup-test
- status: triaged
- ticket: 50
- run: w5-20261008T1720Z
- screen: Welcome
- decision: 

**Steps.**
1. Signed out, background the app, deliver and tap a reminder notification (simctl push, payload
   `reminder:<id>`): expect `HELD … (startup not routable)`. Then log in in the same session: is the held tap
   replayed (`REPLAY id=…`), dropped, or kept? (50-001 suggests the startup provider never re-resolves after login.)
2. Signed in on Welcome (`/welcome`), tap Build My Plan on a disposable account: does onboarding start over the live
   session and what does it write?

**Expected.**
A held tap routes after sign-in or is dropped with a trail line; a signed-in athlete is never sent into onboarding.

**Actual.**
Not run.

**Evidence.**
- runs/50/l01-welcome-signed-in.png Welcome while signed in
- runs/50/d03-after-banner-tap-2.png a HELD tap after an in-session login

**Decision quote.**
> 

**Triage.**

