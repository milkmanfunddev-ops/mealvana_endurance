# 28-005 · Scan to Add Food untried paths: denied permission, background and return, not-found and invalid dialogs, offline, other entry points

- kind: followup-test
- status: triaged
- ticket: 28
- run: w15-20260924T2040Z
- screen: Scan to Add Food; Log — Sep 23; Build a Meal → Add food
- decision: 

**Steps.**
Look-around on the screens ticket 28 visited. Not run.
1. Scanner, permission: tap "Don't Allow" on the first open (reset with `xcrun simctl privacy <udid> revoke camera com.milkman.mealvanaendurance.dev`, simulator-safe). What does the scanner show, and is there any way to Settings?
2. Scanner, lifecycle: open the scanner, send the app to the home screen and back (resumed calls `_safeStartScanner` again); lock and unlock. Look for the 28-001 raw error without the permission alert.
3. Scanner, double tap Reset quickly (the code comments name a `controllerInitializing` race, Sentry MEALVANA-ENDURANCE-79).
4. Scanner, back while the "Looking up product information..." dialog is up (device only): does the pop close the dialog or the scanner, and does a late result pop the wrong route?
5. Not-found and invalid-format dialogs and their "create food" path (`_openCreateFoodScreen`, a `MaterialPageRoute` push invisible to the router); offline lookup (netcut) shows "Unable to connect to nutrition database."?
6. The other five entry points into the same route, each with its own `category`: plan Add Food (before/during/after run), Swap food ("Scan to Swap …" title), Carb-loading food selection, Food preferences (`/barcode-scanner` by path). Each opens and pops cleanly on a simulator; on a device each lands where its caller expects.
7. Log — Sep 23: the barcode icon while the search field has text and the keyboard is up; the result when the Log screen was opened for today vs. a past day (the scanned log should keep the Log screen's day).
8. Build a Meal → Add food: back from the scanner keeps the draft's items.

**Expected.**
Each path ends on an athlete-readable screen, never a raw exception, and never strands the athlete.

**Actual.**
Not run in ticket 28.

**Evidence.**
- runs/28/06-add-food-sep23.png
- runs/28/14-scanner-second-open.png
- runs/28/18-build-add-food.png

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 91 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
Moved to retest ticket 113 when 91 was split (Lee, 2026-09-25).
