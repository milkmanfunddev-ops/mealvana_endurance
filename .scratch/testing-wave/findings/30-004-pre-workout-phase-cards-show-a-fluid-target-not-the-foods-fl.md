# 30-004 · Pre-workout phase cards show a fluid target, not the foods' fluid, so they do not add up to the Before header

- kind: bug
- status: open
- ticket: 30
- run: w10-20260924T1615Z
- screen: Activity detail (fuelling plan, BEFORE)
- decision: 

**Steps.**
1. Timeline, Monday 21 September, tap "12 mi Run". Read BEFORE and its two phase cards.
2. Compare with the stored `sections[before_run].subPhases` foods.

**Expected.**
Each phase card's fluid is the fluid in its own foods, and the cards add up to the BEFORE header.

**Actual.**
BEFORE header: 107 g carbs, 17 oz fluids, 660 mg sodium. These equal the stored foods (carbs 44+11+27+25 = 107; fluids 6+20+480 mL = 506 mL = 17 oz; sodium 602+7+1+50 = 660). Stored target 101 g sits as the triangle marker, band 88-113 g, 0-29 oz. So far consistent.
Pre-Workout Snack card: 82 g carbs (its foods: 82, right), 16 oz fluids. Its foods (bagel, jam, banana) hold 6 mL; 16 oz matches the stored snack fluid tier target (`fluidTiers.snack 477.6 mL`), not the foods. Top-Off card: 25 g carbs and no fluid figure, though it holds 2 cups of water (480 mL). The cards read 16 oz + nothing against a 17 oz header, and the water sits under the card that shows no fluid.
Same on today's Patrol H5: BEFORE 9 oz (foods 274 mL), its only card (Top-Off) reads 10 oz (target 297 mL).

**Evidence.**
- runs/30/08-12mi-run-tap.png
- runs/30/09-12mi-run-topoff-during.png
- runs/30/screen-12mi-run-labels.txt
- runs/30/db-fuel-plans-summary.txt
- runs/30/screen-patrol-h5-labels.txt

**Decision quote.**
> 

**Triage.**
