# 31-002 · The water-bottle checkbox on Profile & Preferences tells accessibility nothing about its checked state

- kind: bug
- status: closed
- ticket: 31
- run: w11-20260924T1648Z
- screen: Profile & Preferences
- decision: 

**Steps.**
1. Settings > Profile & Preferences, scroll to Hydration.
2. Read the accessibility tree (idb ui describe-all) with the box unchecked, then checked.

**Expected.**
The "I run with a water bottle" control is exposed as a checkbox or switch with its checked value, like the Settings screen's "Show testing buttons" CheckBox (=1).

**Actual.**
It is exposed only as StaticText "I run with a water bottle | This helps us estimate your hydration needs" with no role and no value in both states, so VoiceOver cannot tell whether it is on. The screenshots show the box unchecked and then checked while the tree stayed the same.

**Evidence.**
- runs/31/07-profile-prefs-scrolled.png: unchecked
- runs/31/12-relaunch-bottle-kept.png: checked; the tree read at the same moment shows the same StaticText (notes.md, 16:52 UTC)

**Decision quote.**
> 

**Triage.**
Fix ticket 51 (Lee, 2026-09-25). Closed by the retest after it merges.
Moved to retest ticket 119 when 93 was split (Lee, 2026-09-25).

Run by retest ticket 119 (run w36-20260926T0031Z, build 72d3723e): pass; the water bottle is a CheckBox with value 0/1.
