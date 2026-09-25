# 112-017 · Log a Meal Saved meals: trash while offline, trash the last saved meal, and a saved meal with no numbers

- kind: followup-test
- status: open
- ticket: 112
- run: w34-20260925T2320Z
- screen: Log a Meal (Recent → Saved meals)
- decision: 

**Steps.**
1. On a throwaway saved meal, tap trash offline, then restore the network: does the delete reach the server?
2. Trash the only saved meal left: does the "Saved meals" header disappear cleanly?
3. Log a saved meal whose totals are null offline and check the row once uploaded.

**Expected.**
Delete syncs when back online; empty state is clean; totals come from items.

**Actual.**


**Evidence.**
- runs/112/76-after-trash-tap.png

**Decision quote.**
> 

**Triage.**
