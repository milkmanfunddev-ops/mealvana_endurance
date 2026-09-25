# 22-001 · Lee's Kroger shopper login is refused by the certification sign-in page (login-stage.kroger.com)
- kind: bug
- status: open
- ticket: 22
- run: w18-20260925T0127Z
- screen: Kroger sign-in sheet
- decision: 

**Steps.**
1. Sign in as test@test.com, Food > Shopping > Shop with Kroger (01:29 UTC 2026-09-25; location prompt: Don't Allow).
2. The Kroger screen shows "Test mode. Nothing reaches a real Kroger cart." and Connect Kroger (the stored production connection no longer counts under the certification function, so there is no Disconnect to press).
3. Connect Kroger, Continue on the "wants to use kroger.com to sign in" alert (01:30:18 UTC).
4. The sheet opens on `login-stage.kroger.com`. Type Lee's shopper address (`lee.b.martin@gmail.com`, the Kroger row in the credentials file, labelled "certification environment") with the mobile MCP, the password with `cred.mjs type`, Sign In (01:31:2x UTC).
5. Clear the password, type it again with `cred.mjs type`, Sign In (01:32:3x UTC).

**Expected.**
Lee's ruling on 21-001 (2026-09-24): dev uses Kroger's certification environment, and ticket 22 reconnects there with Lee's shopper login. The certification page accepts the login, returns to the app, and `kroger_connections` holds a row with `environment = 'certification'`.

**Actual.**
The environment is right this time: certification line on the screen (09-), sheet on `login-stage.kroger.com` (11-, 12-). The sign-in is refused both times: "The email or password is incorrect. Please try again or click "Forgot password"." (16-, 18-). The same address and stored password signed in on production `login.kroger.com` in ticket 21 last night, so this looks like a separate account system: Kroger's certification (stage) sign-in does not know Lee's production shopper account. The credentials file has no certification shopper account. Nothing was written: `kroger_connections` still holds only ticket 21's production row (updated 2026-09-24 22:39:27 UTC), one unused `kroger_oauth_sessions` row from the Connect tap (expires 01:40 UTC), no new draft, no new export (db-kroger-after-refused-signin.txt). Edge requests: `kroger` 200 at 01:30:18 UTC (connect start), no exchange. Closing the sheet with X returned to the Kroger screen with no message (19-). Ticket stopped here: with no certification connection there is no cart to send to, so the match-and-send scenario cannot run; the fix is a Kroger certification shopper account in the credentials file (or Lee's say-so to test another way).

**Evidence.**
- runs/22/09-kroger-screen.png (certification line, Connect Kroger)
- runs/22/12-sheet-loaded.png (login-stage.kroger.com)
- runs/22/15-sheet-password-typed.png (password masked)
- runs/22/16-after-sign-in.png (refused, first try)
- runs/22/18-sheet-second-try.png (refused, second try)
- runs/22/19-after-closing-sheet.png
- runs/22/db-kroger-before.txt
- runs/22/db-kroger-after-refused-signin.txt
- runs/22/edge-requests-raw.txt

**Decision quote.**
> 

**Triage.**
