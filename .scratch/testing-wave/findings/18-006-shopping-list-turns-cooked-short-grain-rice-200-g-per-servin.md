# 18-006 · Shopping list turns Cooked short-grain rice 200 g per serving into Short-grain rice 1.6 kg for eight servings, dropping cooked

- kind: bug
- status: triaged
- ticket: 18
- run: w16-20260924T2100Z
- screen: Food (Shopping sub-tab), after Browse adds
- decision: 

**Steps.**
1. From Browse, add Sweet rice cake with jam twice (8 servings, see 18-001). Its detail lists "Cooked short-grain rice 200g" per serving.
2. Open Food > Shopping (the draft's list, 18-002).

**Expected.**
The list asks for rice the athlete can buy: either "Cooked short-grain rice 1.6 kg" or the dry amount (about a third of the cooked weight).

**Actual.**
The list reads "Short-grain rice 1.6 kg": the per-serving cooked weight times 8 with "cooked" dropped, so an athlete would buy about three times the rice needed. Other rows scale plainly (Egg 8, Milk 400 ml, Strawberry jam 16 tbsp). The detail also says "batch — 30 min, 4–5 servings" and "Cut into 4 pieces" while the amounts are treated as one serving (grocery.ts: library portions are per athlete serving), which may or may not be right; not checked.

**Evidence.**
- runs/18/33-second-tap-on-ticked.png: detail with "Cooked short-grain rice 200g" and "4–5 servings".
- runs/18/db-03-final.txt: list 813df86f item "Short-grain rice" qty "1.6 kg".
- runs/18/44-shopping-after.png: the list on the Shopping tab.

**Decision quote.**
> 

**Triage.**
Fix ticket 37 (Lee, 2026-09-25). Closed by the retest after it merges.
Moved to retest ticket 110 when 90 was split (Lee, 2026-09-25).
