# 88-014 · Browse cards overflow at large accessibility text sizes

- kind: bug
- status: triaged
- ticket: 88
- run: w29-20260925T1949Z
- screen: Browse meals
- decision: 

**Steps.**
1. Retest of 18-008 step 6. Browse meals open in `449da56d`. `xcrun simctl ui <udid> content_size accessibility-large` (20:20:20Z). Restored to `large` after.

**Expected.**
Cards grow or wrap; no overflow; Done reachable.

**Actual.**
Every visible card shows Flutter's "BOTTOM OVERFLOWED BY 7.0 PIXELS" stripe (one by 37 px) over its tag chips; Done stays reachable.

**Evidence.**
- runs/88/93-18-008-browse-large-text.png

**Decision quote.**
> 

**Triage.**

Fix ticket 130 (Lee, 2026-09-25). Closed by the retest after it merges.
