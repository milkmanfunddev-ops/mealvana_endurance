# 29-003 · Cold start untried paths: signed in with no network, and with an expired session; every tab and the console

- kind: followup-test
- status: open
- ticket: 29
- run: w16-20260924T2100Z
- screen: Welcome, Timeline, Food, Events, Learn
- decision: 

**Steps.**
1. With test@test.com signed in, cut the app's network (`netcut.sh launch`, then `on`) and cold start it; visit every tab.
2. Separately, make the stored session expire (wait out the access token with the refresh token revoked, or sign the account out on the server), then cold start.
3. Read the console after each.

**Expected.**
Offline: every tab's first screen renders from the local database with no exception line; nothing spins forever. Expired session: the app lands on Log In (or refreshes silently) without a red screen or an unhandled exception.

**Actual.**
Not run. This run covered only online cold starts (signed out with an empty database, then signed in). Earlier offline runs (20) restarted the app offline but only looked at Shopping.

**Evidence.**
- runs/29/notes.md

**Decision quote.**
> 

**Triage.**

