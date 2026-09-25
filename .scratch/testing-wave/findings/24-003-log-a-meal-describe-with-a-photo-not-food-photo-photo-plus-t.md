# 24-003 · Log a Meal, Describe with a photo: not-food photo, photo plus text, remove photo, cancelled picker, Camera, offline, double Analyze

- kind: followup-test
- status: triaged
- ticket: 24
- run: w14-20260924T2015Z
- screen: Log a Meal (Describe)
- decision: 

**Steps.**
1. Pick a photo that is not food (the simulator library has waterfalls and flowers) and Analyze.
2. Pick a food photo and also type a description, then Analyze (the text rides along with the photo).
3. Attach a photo, tap Remove photo, then Analyze with and without text.
4. Open Gallery and cancel the picker; open Camera on a simulator (no camera).
5. Attach a photo and Analyze with the network off; tap Analyze twice fast.
6. A photo that is uploaded but missing from storage: the function returns 500 at the download step
   after reserving budget (`analyze-meal-photo/index.ts`, storage error branch returns without
   `hold.refund()`); check whether the reservation is refunded and the call-log row completed.

**Expected.**
1: the not-food answer, no invented macros, the call debited once. 2: one call, items reflect the text.
3: no photo sent. 4: back on Describe with nothing attached; Camera says it is unavailable. 5: an error
message, no charge kept, one call only. 6: the reserved amount comes back to the wallet.

**Actual.**


**Evidence.**
- runs/24/07-photo-attached.png: the Photo attached card with Remove photo.

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 91 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
