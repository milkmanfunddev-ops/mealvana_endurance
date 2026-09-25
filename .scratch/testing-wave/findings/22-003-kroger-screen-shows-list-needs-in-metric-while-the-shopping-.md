# 22-003 · Kroger screen shows list needs in metric while the Shopping tab shows the same rows in US units
- kind: bug
- status: triaged
- ticket: 22
- run: w18-20260925T0127Z
- screen: Shop with Kroger
- decision: 

**Steps.**
1. Sign in as test@test.com, Food > Shopping: read the list (list 813df86f, plan 173cebb2).
2. Tap Shop with Kroger and read the "Not matched yet" lines.

**Expected.**
The same row reads in the same units on both screens (the Shopping tab uses US units on this account).

**Actual.**
Shopping tab: Mixed berries 11.5 oz, Milk 13.5 fl oz, Water or oat milk 1.3 qt, Quinoa 11.5 oz, Short-grain rice 3.5 lb. Kroger screen, same rows: "Need 320 g", "Need 400 ml", "Need 1.2 l" (and the rest below the fold). The Kroger screen shows the stored metric quantity (`shopping_items.qty`: 320 g, 400 ml, 1.2 l, 320 g, 1.6 kg) without the conversion the Shopping tab applies. A shopper comparing the need with Kroger's package sizes (sold in oz, fl oz, lb) has to convert by hand.

**Evidence.**
- runs/22/07-shopping-tab.png
- runs/22/09-kroger-screen.png
- runs/22/db-shopping-list-before.txt

**Decision quote.**
> 

**Triage.**
Fix ticket 37 (Lee, 2026-09-25). Closed by the retest after it merges.
