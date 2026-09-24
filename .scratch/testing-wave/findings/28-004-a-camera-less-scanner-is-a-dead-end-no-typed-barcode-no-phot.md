# 28-004 · A camera-less scanner is a dead end: no typed barcode, no photo pick, and search does not match barcode numbers

- kind: idea
- status: open
- ticket: 28
- run: w15-20260924T2040Z
- screen: Scan to Add Food; Log — Sep 23 (search)
- decision: 

**Steps.**
1. On the scanner with no camera (a simulator, an iPad without a rear camera, or a denied permission), the only actions are Reset, Switch, flash and Back. The message is the package's English default text ("Scanning is not supported on this device. No cameras available."), not from the content system, and nothing offers another way in.
2. Idea: add "Enter barcode" (a numeric field that calls the same `lookup-product` path) and "Scan from photo" (mobile_scanner's `analyzeImage` on a picked image) to the scanner, and an app-written message with a link to search or Manual when the camera is unavailable or denied. The typed field would also let a simulator run test the whole lookup → confirm → log path end to end.
3. Related: typing a barcode number into the Log search returns "No foods found" even for a barcode already cached in `nutrition_products` (00720579120045, TEXAS RICE, source usda_fdc). `search-catalog` (POST 200 twice in the edge logs) matches names only. Matching a 8/12/13/14-digit query against `nutrition_products.barcode`, or routing such a query to `lookup-product`, would give a typed path for free.

**Expected.**
An athlete with no working camera can still log a packaged product by its barcode.

**Actual.**
No path: runs/28/14-scanner-second-open.png, runs/28/15-search-barcode-number.png (3017620422003), runs/28/16-search-cached-barcode.png (00720579120045).

**Evidence.**
- runs/28/14-scanner-second-open.png
- runs/28/15-search-barcode-number.png
- runs/28/16-search-cached-barcode.png
- runs/28/edge-lookup-search.txt

**Decision quote.**
> 

**Triage.**
