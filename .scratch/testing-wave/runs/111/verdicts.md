# Ticket 111 verdicts (run w30-20260925T2103Z, app e3367d2c, test@test.com)

## Findings retested

| id | verdict | evidence | new Finding |
|---|---|---|---|
| 20-008 | pass | edge-kroger-run.txt (26 `POST /functions/v1/kroger` in the run window, all 200, none 400), edge-kroger-20-008.txt; Shopping opens at 21:05:50Z, 21:10:27Z (cold restart), 21:14:3xZ (netcut relaunch), notes.md | |
| 21-002 | pass | 04-location-prompt.png: reason names the weather forecast and "to find the Kroger store that can deliver your groceries" | |
| 21-003 | pass | 17-connect-system-alert.png: "“Endurance Dev” Wants to Use “kroger.com” to Sign In". The sign-in itself cannot finish (no certification shopper, IMPROVEMENTS #52) | |
| 21-010 | pass | 09-disconnect-confirm.png (asks "Disconnect Kroger? Connecting again means signing in at kroger.com."), 10-after-disconnect-cancel.png + db-kroger-after-disconnect-cancel.txt (Cancel keeps the row), 11-after-disconnect-confirmed.png + db-kroger-after-disconnect.txt (confirm deletes it). Run on the production row at 22-005, the only connection this run had | |
| 22-003 | pass | 03-shopping-tab-open1.png (list read once 21:06:05Z: Avocado 2, Mixed vegetables 1.8 lb, Wholewheat pasta 12 oz), 05-after-allow-location.png (Kroger: Need 2, Need 1.8 lb, Need 12 oz), db-shopping-list-22-003.txt (stored 800 g, 344 g). Kroger half run without a connection: the Need lines show unconnected | |
| 22-005 | pass | 04-/08-22-005-other-environment-shown.png ("A Kroger account connected in another version of the app is still saved…" + Disconnect Kroger), db-kroger-before.txt (production row), db-kroger-after-disconnect.txt (row gone). Connect-replaces-it not checked (no shopper login); no call used the production token (every call after is status/location/connect, all 200) | |

## Follow-up tests

| id | verdict | evidence | new Finding |
|---|---|---|---|
| 21-005 | fail | 18-after-alert-cancel.png, 21-after-sheet-x.png, db-kroger-after-alert-cancel.txt, db-kroger-after-sheet-x.txt | 111-001 |
| 21-006 | not run | Wrong half run with a made-up address (no-such-shopper-111@example.com) and a dummy password: Kroger's "The email or password is incorrect" inside the sheet, app waits (23-21-006-wrong-password.png), X after it gives 111-001's message. Right-password half needs a certification shopper login; only Lee's exists and is never used | |
| 21-007 | pass | Offline: 27-21-007-offline-connect-retry.png ("Kroger could not be reached. Your draft is saved on this device.", no sheet, not busy). Double tap: one alert, one sheet (29-, 30-), one `connect` request at 21:16:32Z (edge-kroger-run.txt), one `kroger_oauth_sessions` row (db-kroger-end.txt). First offline tap reached the server over an open socket (harness limit, 111-004) | 111-004 (idea) |
| 21-008 | not run | Needs a live certification connection whose access token expires; no connect can finish without a certification shopper login (IMPROVEMENTS #52). The only stored row was production and was removed by 22-005 | |
| 21-009 | fail | Allow: "Delivery to 35223" (05-after-allow-location.png, pass); Settings Never then reopen: "Set delivery ZIP", no error (06-, 07-, pass). "Match all appears once a store resolves" fails: no Match all while unconnected | 111-002 |
| 22-004 | fail | Set delivery ZIP 35209 resolves store 540FC242 (14-after-zip-35209.png, db-kroger-draft-after-zip.txt); Match all, line search and Add to Kroger cart are hidden without a connection (15-tap-line-unconnected.png) | 111-002 |
