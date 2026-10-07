# 08-005 · Sport Settings renders in the light theme inside the dark app, and its FTP value is nearly invisible

- kind: bug
- status: open
- ticket: 08
- run: w1-20261007T1105Z
- screen: Sport Settings (/settings/sport-settings)
- decision: 

**Steps.**
1. Dark app theme (as the rest of the run). Open xcrun simctl openurl <udid> "com.milkman.mealvanaendurance:///settings/sport-settings" (three slashes), signed in as test@test.com.

**Expected.**
The screen follows the app's dark Kyle theme and the stored FTP reads clearly.

**Actual.**
Cream background with black headings while every other screen is dark; the FTP field's value '180' is pale on white and hard to see; a teal 'TrainingPeaks' chip (idb also lists 'stale'). Water Bottles shows none of 1/2/3+ selected.

**Evidence.**
- runs/08/c02-sport-settings.png

**Decision quote.**
> 

**Triage.**
