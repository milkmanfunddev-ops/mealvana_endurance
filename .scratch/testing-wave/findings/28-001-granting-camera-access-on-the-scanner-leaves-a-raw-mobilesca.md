# 28-001 · Granting camera access on the scanner leaves a raw 'MobileScannerController is already running' error that Reset cannot clear

- kind: bug
- status: triaged
- ticket: 28
- run: w15-20260924T2040Z
- screen: Scan to Add Food (barcode scanner)
- decision: 

**Steps.**
1. Signed in as test@test.com on a simulator that had never granted the app camera access.
2. Timeline → previous day (Sep 23) → + Add Food → Log — Sep 23 → the barcode icon in the search bar.
3. iOS asks "“Endurance Dev” would like to access the Camera." Tap Allow (20:43:30 UTC).
4. Tap Reset, then Switch, then the flash icon.

**Expected.**
After Allow, the scanner starts (on a simulator: the "No cameras available" state it shows on every later open), or at least a message written for an athlete.

**Actual.**
The scan area shows the mobile_scanner package's own error widget with developer text: "The MobileScannerController is already running. Stop it before starting again. The scanner was already started." The first line runs off both edges of the screen. Reset, Switch and the flash icon leave it unchanged. Backing out and opening the scanner again shows the normal "Scanning is not supported on this device. No cameras available."

Likely cause (code read, not fixed): the permission alert makes the app inactive and then resumed; `didChangeAppLifecycleState(resumed)` calls `_safeStartScanner()` while the first `start()` is still waiting on the permission. The second start fails with `controllerAlreadyInitialized`; `_safeStartScanner` catches the exception, but the controller keeps the error in its state and `MobileScanner` (no `errorBuilder`) renders it. The `_isStartingScanner` guard does not help because the first start is still in flight in a different call path. On a phone the same alert fires on the first-ever scan, so a real athlete's first scan likely hits this too; ticket 28-003 asks the device run to confirm.

No Flutter error line was printed; the console shows only the TCC camera grant at 15:43:31 local.

**Evidence.**
- runs/28/07-scanner-t3s.png (permission alert over the scanner)
- runs/28/09-scanner-after-allow.png (raw error after Allow)
- runs/28/10-scanner-after-reset.png
- runs/28/11-scanner-after-switch.png
- runs/28/12-scanner-after-flash.png
- runs/28/14-scanner-second-open.png (second open: the normal no-camera state)
- runs/28/console-redacted.log (TCC kTCCServiceCamera Allowed, 15:43:31 local)

**Decision quote.**
> 

**Triage.**
Fix ticket 44 (Lee, 2026-09-25). Closed by the retest after it merges.
