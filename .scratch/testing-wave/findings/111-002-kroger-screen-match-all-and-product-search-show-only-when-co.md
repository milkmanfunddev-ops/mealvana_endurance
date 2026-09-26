# 111-002 · Kroger screen: Match all and product search show only when connected, so matching cannot run before a Kroger sign-in

- kind: bug
- status: triaged
- ticket: 111
- run: w30-20260925T2103Z
- screen: Shop with Kroger
- decision: 

**Steps.**
1. Retest of follow-up 22-004 (and the Match all half of 21-009). test@test.com, dev (certification), no Kroger connection (the production row was removed at 21:08:50Z).
2. Shop with Kroger on plan 666be167's list: the delivery area filled from the device ("Delivery to 35223", 21:06:24Z); later Set delivery ZIP 35209, Continue (21:09:2xZ): "Delivery to 35209", and `kroger_drafts` for 666be167 holds store 540FC242 (Kroger Birmingham Spoke).
3. Look for Match all, tap a "Not matched yet" line, look for Add to Kroger cart.

**Expected.**
Catalog reads run on the application token (`supabase/functions/_shared/kroger/client.ts`: "The shopper's own token pays for the cart write and for nothing else"; `service.ts`: Locations and Products need no shopper), so once a store resolves, Match all and a line's product search work before any Kroger sign-in. Add to Kroger cart asks the shopper to connect first (22-004). IMPROVEMENTS #52 (Lee, 2026-09-25): "test matching only. Ticket 22 now runs matching unconnected (22-004)".

**Actual.**
No Match all button, no product search on a line (tapping one does nothing) and no Add to Kroger cart, only Connect Kroger. `kroger_screen.dart:280` shows Match all only when `view.connected && draft.store != null`, and `KrogerState.canChooseProduct` requires `connected`, so the screen gates matching on a shopper sign-in the server does not need. With no certification shopper login (#52), matching cannot be tested on dev at all, and a shopper cannot see what their list would cost before signing in to Kroger. 22-004 fails at step 2; its matching record (row, need, product, UPC, size, price, packages) was not made.

**Evidence.**
- runs/111/05-after-allow-location.png
- runs/111/14-after-zip-35209.png
- runs/111/15-tap-line-unconnected.png
- runs/111/db-kroger-draft-after-zip.txt

**Decision quote.**
> 

**Triage.**

Fix ticket 133, Shopping lists and Kroger (Lee, 2026-09-26). Ruling: Kroger matching works once a store is picked, before Kroger login. Login is asked only at Add to Kroger cart (133). Closed by the retest after it merges. Record: `triage-20260926.md`.
