# 68-011 · Barcode lookup shows Nutella's per-100 g values as '1 serving' (539 kcal), so logging one serving counts 539 kcal

- kind: bug
- status: triaged
- ticket: 68
- run: w7-20261008T2309Z
- screen: Log a Meal > Scan barcode > Enter > Log Food
- decision: 

**Steps.**
1. Scan barcode > Enter > 3017620422003 > Look it up (23:40:37Z). lookup-product: cache hit nutrition_products 'Nutella', origin open_food_facts.

**Expected.**
A real serving (Nutella's label serving is 15 g or 37 g, ~80-200 kcal), or the basis named honestly (per 100 g) with a grams input.


**Actual.**
Log Food shows 'Nutella, Ferrero, Yum yum Nutella', 'Per serving: 1 servings', 'For 1 serving' 539 kcal, 58 g C, 6 g P, 31 g F, 43 mg sodium: Open Food Facts' per-100 g values labelled as one serving. Not logged. 'Per serving: 1 servings' also reads oddly. The same layout showed 'McEnnedy Double burger' 277 kcal for 12345670, likely also per 100 g.


**Evidence.**
- runs/68/12f-known-barcode-result.png: the Log Food screen.
- runs/68/edge-check12-barcode.txt: the cache hit.

**Decision quote.**
> 

**Triage.**
- triaged · fix ticket 74 (swap picker search crash, Create Food button state, barcode per-100 g shown as a serving), fix wave 8 · Lee, 2026-10-09
