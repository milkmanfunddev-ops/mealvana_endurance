# 112-013 · The Recent quick log sheet starts on "Any time" instead of the source meal's type

- kind: idea
- status: triaged
- ticket: 112
- run: w34-20260925T2320Z
- screen: Log a Meal (Recent) → quick log sheet
- decision: 

**Steps.**
1. Recent → "W14-25 Built bowl" (source slot dinner): the sheet preselects "Any time". Re-logs at 2 and 1.5 servings kept the default and saved slot null. Idea: preselect the source's slot on a re-log (fix 58 copies the source's items and source; the slot is the one field that falls back).

**Expected.**
Triage decides.

**Actual.**


**Evidence.**
- runs/112/09-recent-builtbowl-sheet.png

**Decision quote.**
> 

**Triage.**

Fix ticket 135, Meal upload and quick logging (Lee, 2026-09-26). Ruling: a Recent re-log starts on the source log's slot (135). Closed by the retest after it merges. Record: `triage-20260926.md`.
