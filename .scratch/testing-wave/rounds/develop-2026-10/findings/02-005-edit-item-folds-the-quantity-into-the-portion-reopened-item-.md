# 02-005 · Edit Item folds the quantity into the portion: reopened item shows Quantity 1, doubled numbers, 2 medium banana (~118g)

- kind: bug
- status: triaged
- ticket: 02
- run: w1-20261007T1103Z
- screen: Review & Log (Edit Item)
- decision: 

**Steps.**
1. On Review & Log, tap the Banana row's edit (pencil); it shows Portion "1 medium banana (~118g)", Quantity 1, 105 kcal, C 27.0, P 1.3, F 0.3.
2. Set Quantity 2: the fields scale to 210 / 54.0 / 2.6 / 0.6. Save. The row reads "2 medium banana (~118g) · 210 kcal".
3. Tap edit on Banana again.

**Expected.**
The editor reopens at Quantity 2 over the same base (1 medium banana, 105 kcal), so setting 1 puts it back; and the portion reads as two bananas ("2 medium bananas (~236g)" or "2 × 1 medium banana (~118g)").

**Actual.**
It reopens with Quantity **1**, Portion "2 medium banana (~118g)" and the doubled numbers as the base (210 / 54.0 / 2.6 / 0.6). Setting 1 changes nothing; getting back needed Quantity 0.5. The saved portion text keeps "(~118g)", which now reads as two bananas weighing 118 g in total, and "banana" stays singular. The values did round-trip (0.5 → "1 medium banana (~118g) · 105 kcal", totals back to 404 / 42 / 17 / 20).

**Evidence.**
- runs/02/12-edit-banana-qty2.png — quantity 2, nutrients doubled
- runs/02/13-review-banana-x2.png — row reads 2 medium banana (~118g)
- runs/02/14-edit-banana-reopened.png — reopened at Quantity 1 with doubled base
- runs/02/15-edit-banana-half.png — 0.5 needed to return
- runs/02/16-review-banana-back.png — totals back to 404 kcal
- Old Finding: mealplanning-2026-09 23-004 covered change quantity on Review

**Decision quote.**
> 

**Triage.**
fix ticket: quantity and per-portion base stay separate on an edited item; reopen shows the quantity over the original base (meal-logging ticket with 02-003)
