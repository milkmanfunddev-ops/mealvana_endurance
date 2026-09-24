# 28 run notes

- RUN: w15-20260924T2040Z
- App build: 52c68764b2cde49951a27220a8dbdb3a463116f7 (installed on wave-pool-2, UDID 923D5E4C-FF1D-453A-A936-7D12E86994AE)
- Worktree base: d087d4c6 (main clone `mealplanning` also at d087d4c6)
- Slot claimed 2026-09-24T20:40:07Z (testing-wave-27 also holds one)

## Code read before driving
- Scanner package: `mobile_scanner` ^7.2.0; screen `BarcodeScannerScreen` (route `barcode-scanner`), no manual-entry field, no pick-from-library (`analyzeImage`) button, no `errorBuilder`.
- Lookup: edge function `lookup-product` (USDA + Open Food Facts), no AI model. No COST spend needed.
- Entry points pushing the scanner: Log meal search bar (context `meal_log_discover`), Build a meal (`build_meal_add_food`), Add food (plan), Swap food, Carb-loading food selection, Food preferences.
- Code read: the `barcode-scanner` GoRoute builds `BarcodeScannerScreen` without passing `extra['context']`, so `_isMealLogContext` is always false; a successful scan from meal logging would go to the plan's FoodDetailScreen instead of popping the Food. Filed as a Finding (cannot be proven on a simulator).

## Run (times UTC)
- 20:41 launched with the console stream (`console.log`, redacted to `console-redacted.log` at the end: 4 token lines cut). App opened signed out on Welcome.
- Signed in as test@test.com (email + `CRED type`). What's New sheet (Got it) then the TrainingPeaks sharing sheet (tapped Keep Sharing, which leaves the account's setting as it was). Both sheets are known (12-008, 30-010).
- Timeline → previous day, Wednesday September 23 → + Add Food → "Log — Sep 23" (Describe tab selected by default).
- `db-before.txt` saved (12 rows on 09-23/09-24, none from this run).
- 20:43:15 barcode icon (tapped at 314,153: it has no accessibility element, Finding 28-006) → iOS camera permission alert → 20:43:30 Allow → raw "MobileScannerController is already running" error; Reset, Switch, flash leave it (Finding 28-001).
- Back, reopen at 20:44:20 → "Scanning is not supported on this device. No cameras available." This is the simulator's answer: no camera, so no scan.
- Other paths tried: typed 3017620422003 (Nutella) into the Log search → "No foods found"; typed 00720579120045 (cached on dev in `nutrition_products`, TEXAS RICE) → "No foods found" (Finding 28-004). No typed-barcode field, no photo-pick on the scanner, no paste target. The Describe tab's Gallery is AI photo logging, not a barcode path, so it was not used (no COST spent).
- Build a Meal → + Add food → barcode icon → same no-camera state. Console shows `barcode_scanner_opened {category: add_food, context: null}` for all three opens (Finding 28-002).
- Back to Timeline Sep 23. `db-after.txt`: no row from this run (the only new rows are the 27 run's `W15-27 …`). Edge logs (`edge-lookup-search.txt`): no `lookup-product` call; two `search-catalog` POST 200 at 15:44:42 and 15:45:20 local (my two barcode searches).
- 20:48:22 stream stopped, app terminated, slot released.

## Decisions while running
- Did not call `lookup-product` directly over HTTP to prove the backend half: it writes a cache row to `nutrition_products` and the runbook allows no writes this ticket does not name. The device run (28-003) covers it.
- Did not revoke camera permission to test "Don't Allow": left for 28-005.

## Console
- Known noise: TrainingPeaks token refresh 400 / "Token expired. Please reconnect.", V.O2 "Please reconnect", FinalSurge "Date-range endpoint unavailable (404)", fuelling "No distance data" / "No intensity distribution hints": the dev admin's expired integration tokens and Patrol test activities, seen in tickets 03, 12, 14, 15, 19.
- No Flutter error or exception line on the scanner, Log, or Build a Meal screens. The raw scanner error of 28-001 printed nothing.
- AVFCapture `_defaultDeviceWithDeviceType` lines at 15:43:30 local: the camera lookup finding no device (simulator), known noise.

## Look-around
- Log — Sep 23, Scan to Add Food, Build a Meal → Add food: Finding 28-005 (and 28-006 for labels).
- Welcome, Log In, sign-in sheets, Timeline day switch: covered by earlier Findings (30-010, 12-008, 25-004, 26-001); nothing new seen.

## Rows left on test@test.com
- None. The run logged nothing (no path to a scan on a simulator).
