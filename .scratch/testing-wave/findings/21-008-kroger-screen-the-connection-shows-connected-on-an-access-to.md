# 21-008 · Kroger screen: the connection shows connected on an access token expired a week, prove the refresh path
- kind: followup-test
- status: open
- ticket: 21
- run: w17-20260924T2233Z
- screen: Shop with Kroger
- decision: 

**Steps.**
1. Before this run the stored connection's access token had expired on 2026-09-17 14:44 UTC, and the screen still showed connected (Disconnect, Add to Kroger cart; no Connect).
2. After this run's connect (expires 23:09:27 UTC 09-24), wait past expiry, open Shop with Kroger, set a ZIP and Match all (search needs the user token or app token).

**Expected.**
The function refreshes the token with the refresh token (`expires_at` moves, `updated_at` moves) and the match works; if the refresh token is dead, the screen shows reconnect-required rather than "connected".

**Actual.**
Not run. Ticket 22 runs on this connection and will likely hit the expiry, so it can record this.

**Evidence.**
- runs/21/db-kroger-before.txt (expired access token, shown as connected)
- runs/21/11-kroger-screen-bottom-connected.png

**Decision quote.**
> 

**Triage.**
