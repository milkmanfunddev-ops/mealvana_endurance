# 119-011 · Appearance: pick System and switch the simulator between light and dark

- kind: followup-test
- status: open
- ticket: 119
- run: w36-20260926T0031Z
- screen: Settings
- decision: 

**Steps.**
1. Settings > Appearance > System.
2. `xcrun simctl ui UDID appearance light`, then `dark`, with the app open; relaunch in each.
3. Put Dark back.

**Expected.**
System follows the device live and across a relaunch.

**Actual.**
Not run: 31-009 was run with Light only (it survives a relaunch and carries across accounts on the same device).

**Evidence.**
- runs/119/tree-theme-dialog.txt: the three options

**Decision quote.**
> 

**Triage.**
