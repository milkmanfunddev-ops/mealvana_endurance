# 88-010 · Six library meals' why text lost its first letter and reads his dinner base is

- kind: bug
- status: triaged
- ticket: 88
- run: w29-20260925T1949Z
- screen: Swap
- decision: 

**Steps.**
1. Food > Plan > More on Quinoa, mixed veg & walnuts > Swap (20:12:34Z).
2. Read the candidates' "why" lines; then `SELECT why FROM meal_library WHERE why LIKE 'his %'`.

**Expected.**
"This dinner base is …".

**Actual.**
Wholewheat pasta, mixed veg & avocado (AD-014) and Rice, mixed veg & sunflower seeds (AD-016) read "his dinner base is "rice, quinoa or wholewheat pasta" with…". Six active library meals start "his " (a leading "T" cut off in the data, likely in an import or the nutrition-fill pass).

**Evidence.**
- runs/88/72-61-001-swap-meal-screen.png
- runs/88/db-14-why-text.txt

**Decision quote.**
> 

**Triage.**

Fix ticket 128 (Lee, 2026-09-25): no letter was lost ("his"/"her" is the source athlete); the card fallback to `why` goes (89-003) and a migration names the source in those rows. Closed by the retest after it merges.
