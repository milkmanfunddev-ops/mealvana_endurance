# 18-005 · Browse accessibility: a ticked Add has no label and the filter menu marks the active filter by colour only

- kind: bug
- status: closed
- ticket: 18
- run: w16-20260924T2100Z
- screen: Browse meals
- decision: 

**Steps.**
1. Browse meals, tap "+" on a card so it ticks; read the element list (idb ui describe-all).
2. Open Filters with Dinner and Recipes active; read the menu's element list.

**Expected.**
The ticked button carries a label ("Added", the screen's own mpBrowseAdded tooltip) and the active filter items report a selected state, so VoiceOver can tell what is added and which filters are on.

**Actual.**
After the tick the button has no accessibility element at all: the card lists "Add to plan" for every other card and nothing for the ticked one. In the filter menu all seven items read as plain buttons with no selected value; the active ones differ only by colour (Dinner and Recipes in green). The debug overlay also reported "7 accessibility issues found" on the menu.

**Evidence.**
- runs/18/32-add-tap-2s.png: ticked card (no label in the element list at that time, notes.md).
- runs/18/22-filter-menu-with-two-active.png: active filters shown by colour only.
- runs/18/notes.md: the element-list readings.

**Decision quote.**
> 

**Triage.**
Fix ticket 51 (Lee, 2026-09-25). Closed by the retest after it merges.
Moved to retest ticket 118 when 93 was split (Lee, 2026-09-25).

Run by retest ticket 118 (run w36-20260926T0031Z, build 72d3723e): pass; a ticked "+" is a button labelled "In your plan" and active filters report Selected.
