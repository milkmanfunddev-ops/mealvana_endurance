# 119-006 · Choices and filled fields tell VoiceOver nothing: tap-to-use chips, gender and theme options, and text fields named only by their placeholder

- kind: bug
- status: open
- ticket: 119
- run: w36-20260926T0031Z
- screen: Profile & Preferences
- decision: 

**Steps.**
Read `idb ui describe-all` on:
1. Settings > Profile & Preferences (test@test.com), before and after tapping the TrainingPeaks name chip.
2. Settings > Appearance's Theme Mode dialog.
3. Settings > Nutrition Targets.

**Expected.**
Tap targets are buttons, a selected option says it is selected (like the water-bottle checkbox now does), and a text field keeps its name when it holds a value.

**Actual.**
1. The four "… tap to use" chips are `StaticText`, not buttons. The Gender options MALE / FEMALE / NON-BINARY are `StaticText` with no selected state; so are IMPERIAL / METRIC, the gut-training LOW / MODERATE / HIGH and the sweat-rate options. First name and Last name are named by their placeholder only: once they hold "Xuan" / "Huang" the label is empty and the field is nameless. The Email field has no name at all, filled or not; the Birthday field is `StaticText` "1/14/1996".
2. System / Light / Dark are three `Button`s with no selected state; which one is on is shown only by the picture.
3. Every target field is named "Auto" (its placeholder); a filled one (During Run carbs, 50.4) has an empty name, so a reader hears "50.4" with no idea which target it is.

**Evidence.**
- runs/119/tree-profile-prefs.txt: chips and gender as StaticText, Email field unnamed
- runs/119/tree-profile-after-name-chip.txt: First/Last name fields nameless once filled
- runs/119/tree-theme-dialog.txt: the three theme Buttons
- runs/119/25-nutrition-targets.png: the targets screen (tree in notes.md)

**Decision quote.**
> 

**Triage.**
