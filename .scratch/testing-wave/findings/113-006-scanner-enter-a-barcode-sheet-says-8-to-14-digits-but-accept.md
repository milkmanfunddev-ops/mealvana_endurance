# 113-006 · Scanner Enter-a-barcode sheet says 8 to 14 digits but accepts 5, then answers Invalid barcode format. Please try scanning again

- kind: bug
- status: open
- ticket: 113
- run: w40-20260926T1051Z
- screen: Scan to Add Food → Enter a barcode
- decision: 

**Steps.**
1. Follow-up 28-005 (invalid-format dialog). Log a Meal → Scan barcode → Enter.
2. The sheet reads "Type the number printed under the barcode." with the hint "8 to 14 digits". Type 12345, Look it up (10:54:3xZ).

**Expected.**
The sheet refuses fewer than 8 digits itself (the hint says so), or the error speaks to typing ("That number is too short, barcodes have 8 to 14 digits").

**Actual.**
Look it up is accepted and the dialog says "Invalid Barcode · Barcode: 12345 · Invalid barcode format. Please try scanning again." with Try Another / Create Manually. The athlete typed it, so "try scanning again" is the wrong advice (especially on a device with no camera, where the sheet is the only way in). Console: `barcode_lookup_failed {reason: invalid_format, ...}`, no exception.

**Evidence.**
- runs/113/09-scanner-enter-dialog.png
- runs/113/10-enter-12345-typed.png
- runs/113/11-enter-12345-result.png
- runs/113/console-redacted.log (barcode_entered and barcode_lookup_failed for 12345, 05:54 local)

**Decision quote.**
> 

**Triage.**
