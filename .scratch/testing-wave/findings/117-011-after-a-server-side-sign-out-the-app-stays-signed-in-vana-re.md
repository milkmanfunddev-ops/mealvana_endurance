# 117-011 · After a server-side sign-out the app stays signed in; Vana reads get 401 unauthenticated and the Vana card stays on Looking at your day

- kind: bug
- status: triaged
- ticket: 117
- run: w40-20260926T1052Z
- screen: Food (Plan), every tab
- decision: 

**Steps.**
1. 29-003 step 2 on this run's own account A (never test@test.com): signed in and paid, app terminated.
2. Sign the account out on the server: password grant for A, then `POST /auth/v1/logout?scope=global` (11:40:10Z, 204). `auth.sessions` and live `auth.refresh_tokens` for A: 0.
3. Cold start the app (11:40:19Z), visit Timeline, Food, Events, Learn; read the console.

**Expected.**
29-003: "Expired session: the app lands on Log In (or refreshes silently) without a red screen or an unhandled exception." A session the server has ended should send the athlete to Log In once the app notices.

**Actual.**
The app opens signed in and every tab renders (Timeline from the local database with the meal and the planned run; RevenueCat still answers "active"). Food's Vana card stays on "Looking at your day…" while the console logs eleven `[VANA_TRANSPORT] Vana HTTP 401: {"error":"unauthenticated"}` error boxes (06:40:29 to 06:41:13 local; the retry pattern of 117-009). Nothing routes to Log In or tells the athlete the session ended. The access token (1 h, from the 11:38:53Z sign-in) is still valid for PostgREST, so only vana-action (which checks the session) refuses. The true expiry leg (wait until the access token runs out with the refresh token revoked, then cold start) was not run: it needs about an hour's wait.

**Evidence.**
- runs/117/97-A-revoked-session-cold-start.png
- runs/117/98-A-revoked-food.png
- runs/117/console-redacted.log
- runs/117/notes.md

**Decision quote.**
> 

**Triage.**

Fix ticket 139, Sign-in, sign-up, sign-out, delete, admin (Lee, 2026-09-26). Closed by the retest after it merges. Record: `triage-20260926.md`.
