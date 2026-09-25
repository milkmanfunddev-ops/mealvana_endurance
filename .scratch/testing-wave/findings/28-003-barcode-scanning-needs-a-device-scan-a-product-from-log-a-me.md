# 28-003 · Barcode scanning needs a device: scan a product from Log a meal and Build a meal and check the logged row

- kind: followup-test
- status: triaged
- ticket: 28
- run: w15-20260924T2040Z
- screen: Scan to Add Food (barcode scanner)
- decision: 

**Steps.**
Scanning cannot work on a simulator: with camera access granted, the scanner shows "Scanning is not supported on this device. No cameras available." (the mobile_scanner package finds no AVCaptureDevice). The screen has no typed-barcode field and no pick-from-photo button, and the Log search does not match barcode numbers, so no path on the simulator reaches the `lookup-product` edge function (no `lookup-product` request in the edge logs for the run). Run this on an iPhone with the dev build, signed in as test@test.com, logging on a past day so it does not disturb other runs:

1. Fresh install or camera access reset (Settings → Endurance Dev → Camera off, then delete/reinstall): Timeline → a past day → + Add Food → barcode icon. Allow camera. Check whether the raw "MobileScannerController is already running" error of 28-001 appears on a real phone.
2. Scan a packaged product with a known Open Food Facts / USDA barcode (e.g. Nutella 3017620422003 or any US grocery item). Note the "Barcode Detected / Looking up product information..." dialog and the time.
3. Check which page follows: by the code (28-002) it will be the plan's food page with a Before/During/After Run picker instead of the meal-log servings + slot page (`LogScannedFoodScreen`). Record which one and whether the athlete can finish the log.
4. Finish the log (1 serving, a slot). Check the day's timeline shows it, then SELECT the `meal_logs` row (name, slot, log_date, calories, carbs_g, protein_g, fat_g, sodium_mg, items) and compare with the confirm page. Check `nutrition_products` gained or re-used a row for that barcode (hit_count, source).
5. Edge logs: one `lookup-product` POST 200 at the scan time, no AI call.
6. Scan the same product again (DetectionSpeed.noDuplicates): does a second scan work after Reset?
7. From Build a Meal → + Add food → barcode: scan, check the food lands in the meal draft.
8. Scan a barcode Open Food Facts does not know and a QR code: check the not-found and invalid-format dialogs, and their "create food" path.
9. Switch camera and the flash button on a phone.

**Expected.**
Each scan ends on the meal-log confirm page and one `meal_logs` row whose numbers equal what the page showed; no raw error text anywhere.

**Actual.**
Not run: needs a device with a camera.

**Evidence.**
- runs/28/14-scanner-second-open.png
- runs/28/19-build-scanner.png
- runs/28/edge-lookup-search.txt
- runs/28/db-after.txt

**Decision quote.**
> 

**Triage.**

Picked for ticket 13 (Lee's iPhone session) (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
