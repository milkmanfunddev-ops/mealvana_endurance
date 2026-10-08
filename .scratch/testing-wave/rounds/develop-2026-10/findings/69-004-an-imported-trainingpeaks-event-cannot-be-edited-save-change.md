# 69-004 · An imported TrainingPeaks event cannot be edited: Save Changes demands a race distance the import never set

- kind: bug
- status: open
- ticket: 69
- run: w7-20261008T2311Z
- screen: Edit Event
- decision: 

**Steps.**
1. My Events → "IM NC 70.3" (imported from TrainingPeaks, origin training_peaks) → More options → Edit Event.
2. Change only Location (typed "Raleigh", picked "Raleigh, North Carolina").
3. Save Changes.

**Expected.**
The Location change saves (this is what 50-011 asks to try): an imported event that arrived without a race distance can
be edited without the athlete inventing one, or the form fills a sensible distance from the import.

**Actual.**
The form opens with Sport Category Triathlon and an empty Race Distance. Save Changes is refused with the red line
"Please select a race distance". Nothing saved (row unchanged: origin training_peaks, location null). An athlete
cannot fix a typo or add a location on any imported event without also choosing a distance.

**Evidence.**
- runs/69/i01-imnc-edit-form.png edit form, empty Race Distance
- runs/69/i03-location-picked.png Location set to Raleigh, North Carolina
- runs/69/i04-after-save.png "Please select a race distance" after Save Changes
- runs/69/db-imnc-after-x.txt row unchanged after leaving

**Decision quote.**
> 

**Triage.**

