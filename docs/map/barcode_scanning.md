# Barcode scanning

domain: 4 Log what you ate · folder: `lib/features/barcode_scanning/` (9 files)

"Scan to Add Food" (route `/barcode-scanner`), opened from the barcode icon on "Log a Meal" and from Build a Meal's
food picker; described on `meal_logging.md` ("Scan it"). Lookup through the `lookup-product` function (catalogue,
then the `nutrition_products` cache, then USDA / Open Food Facts); scanned foods are cached in the phone's foods
table. Reuse: `barcode_scanner_screen`, `log_scanned_food_screen`, `barcode_scanner_service`. ops: bug
`barcode-lookup-fails-in-first-logging-session`.
