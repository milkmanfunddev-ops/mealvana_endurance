# 21-001 · Kroger connects to production, not the certification environment the spec names
- kind: bug
- status: open
- ticket: 21
- run: w17-20260924T2233Z
- screen: Shop with Kroger
- decision: 

**Steps.**
1. Sign in as test@test.com, Food > Shopping > Shop with Kroger (22:36 UTC).
2. Disconnect Kroger (22:37), then Connect Kroger through the system sign-in sheet with Lee's shopper login (22:38-22:39).
3. Read `kroger_connections` for the user by SQL (no token columns).

**Expected.**
The spec (`.scratch/testing-wave/spec.md`, Implementation Decisions, "Kroger." bullet): "Runs against Kroger's certification environment with Lee's shopper login." The ticket says the same ("against Kroger's certification environment"). The screen would show the certification line (`kroger_screen.dart` shows `krogerCertification` when `environment == 'certification'`), the sheet would be on Kroger's certification login, and the stored row would say `certification`.

**Actual.**
The connection is to Kroger production. The sheet opened on `login.kroger.com` (screenshots 17-, 18-, 20-). The Kroger screen shows no certification line before, after disconnecting, and after connecting (10-, 13-, 23-), so the `kroger` function's `status` does not report `certification` even with no connection row, which means the dev function's own config is production (`client.ts`: production only when `KROGER_USE_CERTIFICATION` is `"false"`). The new row: `environment = 'production'`, `updated_at 2026-09-24 22:39:27 UTC`, `expires_at 23:09:27 UTC`, refresh token present. All six earlier exports and drafts are production too. No mp decision covers the environment, so this is filed as a bug against the spec line; triage decides whether the spec or dev's secret is wrong. Ticket 22 (checkout hand-off) will run on this production connection, so a "Send to Kroger" there adds to Lee's real Kroger cart.

**Evidence.**
- runs/21/db-kroger-after-connect.txt (environment production, updated 22:39:27 UTC)
- runs/21/db-kroger-before.txt (the 09-17 row was production too)
- runs/21/17-sheet-02-kroger-page.png (login.kroger.com)
- runs/21/13-disconnected-top.png (no certification line while disconnected)
- runs/21/23-connected-after-refresh.png

**Decision quote.**
> 

**Triage.**
Lee, 2026-09-24: dev uses Kroger Certification. The wave lead switched dev's secrets back (`scripts/kroger-dev-admin.mjs secrets` + `enable`, `verify-enabled` reports certification; docs/kroger/DEPLOYMENT.md). The retest is ticket 22: reconnect first, then check that the stored row says `certification`.
