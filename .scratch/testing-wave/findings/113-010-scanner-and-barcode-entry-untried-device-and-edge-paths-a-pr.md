# 113-010 · Scanner and barcode entry: untried device and edge paths (a product with no nutrition, real scans, other entry points, remove-then-kill before upload)

- kind: followup-test
- status: open
- ticket: 113
- run: w40-20260926T1051Z
- screen: Scan to Add Food; Log Food (scanned); Timeline
- decision: 

**Steps.**
Paths this run could not reach or did not run:
1. Enter barcode 4006381333931: Open Food Facts returns "DiagnosticTest Diagnostic Test Product DELETE ME" with no nutrition, and Log Food offers it with "—" for every value and Log Food enabled. Log it (name it by the ticket) and check what row is saved (all null? 0?) and how the timeline shows it (see 113-004). Not logged here to keep the run's rows named W40-113.
2. A real camera scan from Log a Meal and from Build a Meal (device only). The Enter path already lands correctly: Log a Meal → Log Food (servings + slot), Build a Meal → the item joins the draft.
3. The other scanner entry points (plan Add Food, Swap food, carb-loading, Food preferences): open and pop, and what a result does.
4. Timeline Remove then kill before the immediate upload: with idb the kill came ~2 s after the tap and the tombstone was already on the server (updated_at 11:19:24Z, 1 s after the tap). Needs a faster kill, or run it offline (this run did: removed offline, killed, relaunched offline; the row stayed removed locally).
5. Scanner lock and unlock (device), and back while "Looking up product information..." is up.

**Expected.**
Each ends on athlete-readable text and saves what is shown.

**Actual.**
Not run.

**Evidence.**
- runs/113/12-enter-notfound-result.png
- runs/113/db-remove-then-kill.txt

**Decision quote.**
> 

**Triage.**
