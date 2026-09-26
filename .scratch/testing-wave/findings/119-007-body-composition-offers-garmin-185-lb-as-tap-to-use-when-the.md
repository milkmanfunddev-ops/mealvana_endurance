# 119-007 · Body Composition offers Garmin 185 lb as tap to use when the weight field already reads 185

- kind: bug
- status: open
- ticket: 119
- run: w36-20260926T0031Z
- screen: Body Composition
- decision: 

**Steps.**
1. On test@test.com, Settings > Body Composition (00:41:19Z).

**Expected.**
The same rule as Profile & Preferences' identity chips (Xuan, 2026-09-13): a source value equal to the field shows the plain source pill, not a tap-to-use pill.

**Actual.**
Weight reads 185 lbs with "Manual" and "Garmin · 185 lb — tap to use". Tapping it would change nothing the athlete can see. The code (`nutrition_profile_screen.dart` `_buildBodyCompProvenanceRow`) shows the Garmin chip whenever the weight is not from Garmin, without comparing values; the Garmin reading may differ only after the decimal point, which the label rounds away.

**Evidence.**
- runs/119/24-body-composition.png: Manual + "Garmin · 185 lb — tap to use" under 185

**Decision quote.**
> 

**Triage.**
