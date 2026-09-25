# 24-004 · Photos picker says Location Is Included: log a geotagged photo and check the stored object has no GPS

- kind: followup-test
- status: triaged
- ticket: 24
- run: w14-20260924T2015Z
- screen: Photos picker (system) from Log a Meal
- decision: 

**Steps.**
1. Add a photo with GPS EXIF to the simulator library (`simctl addmedia`).
2. Log it through Describe, Gallery.
3. Download the object from the `meal-photos` bucket and read its EXIF.

**Expected.**
The stored photo carries no location (the app resizes it on pick; check the re-encode drops GPS), or the
product decides it may keep it.

**Actual.**


**Evidence.**
- runs/24/06-photo-picker.png: the system picker's "Location Is Included" footer.

**Decision quote.**
> 

**Triage.**

Picked for retest ticket 91 (Lee, 2026-09-25: every open follow-up test folded into the planned runs, cap of ten lifted for this pass).
Moved to retest ticket 114 when 91 was split (Lee, 2026-09-25).
