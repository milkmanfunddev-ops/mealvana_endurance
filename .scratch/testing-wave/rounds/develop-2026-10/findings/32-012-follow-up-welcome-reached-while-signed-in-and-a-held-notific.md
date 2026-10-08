# 32-012 · Follow-up: Welcome reached while signed in, and a held notification tap after sign-in

- kind: followup-test
- status: open
- ticket: 32
- run: w3-20261008T1256Z
- screen: Welcome
- decision: 

**Steps.**
1. Signed in, reach Welcome through Page Not Found → Go Home (32-002). Tap Build My Plan, and I already have
   an account: does onboarding start over a live session, does a second sign-in work, what happens to local data?
2. Signed out, cold launch with a notification payload pending (this run: `HELD id=wave32-killed-probe
   type=carb_event (startup not routable)` on Welcome at 13:02:46Z), then sign in: is the held tap replayed
   to `/events/<id>` after sign-in, dropped, or kept for a later launch?

**Expected.**
A signed-in athlete is never offered onboarding; a held tap either routes after sign-in or is dropped with a trail line.

**Actual.**
Not run. In this run the held tap's process was terminated before sign-in.

**Evidence.**
- runs/32/i05-after-go-home-25s.png Welcome while signed in
- runs/32/a13-killed-legacy-payload-launch.png the held tap on Welcome

**Decision quote.**
> 

**Triage.**
