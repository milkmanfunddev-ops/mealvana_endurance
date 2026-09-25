# 18-002 · Picking a meal in Browse builds a shopping list for the unconfirmed draft, and the Shopping tab then shows that draft's list instead of the confirmed plan's

- kind: ssot-conflict
- status: triaged
- ticket: 18
- run: w16-20260924T2100Z
- screen: Browse meals, then Food (Shopping sub-tab)
- decision: mp-244

**Steps.**
1. Sign in as test@test.com (confirmed plan be6abf2f for week 2026-09-20, no list, 19-001; the Shopping tab showed archived draft 54a02440's list 9bdc9556).
2. Open planning conversation 0401b3d8 from Conversations > Meal plans (no plan row before), plus > Browse meals.
3. Add two meals (Sweet rice cake with jam, Quinoa porridge), Done, back out to Food.
4. Food > Plan, then Food > Shopping.

**Expected.**
The list is built when the athlete confirms (mp-244), so an unconfirmed draft has no list on the Shopping tab. The Shopping tab keeps showing the list of the plan the athlete is on (Plan tab: the confirmed be6abf2f), or its empty state.

**Actual.**
The first Add created draft 173cebb2 (week 2026-09-20, conversation 0401b3d8) and, at the same moment, shopping list 813df86f "Week of 2026-09-20" for it (5 items, then 11 after the next two adds). Food > Plan still shows the confirmed 4-meal plan, but Food > Shopping now shows the draft's list: 11 items for two breakfasts (Banana 4, Mixed berries 320 g, Strawberry jam 16 tbsp, Egg 8, Short-grain rice 1.6 kg ...), headed "Week of 2026-09-20" with Shop with Kroger. Nothing on the tab says this is an unconfirmed draft's list. Any browse pick in any old planning conversation therefore replaces the athlete's shopping list. The list-at-first-edit comes from plan.ts addMeal -> refreshShopping on a draft; the tab choice is the one 19-001 describes.

**Evidence.**
- runs/18/db-00-before.txt: no plan or list for 0401b3d8; newest list 9bdc9556.
- runs/18/db-01-after-card-add.txt: draft 173cebb2 and list 813df86f created at 21:09:24-25Z.
- runs/18/db-03-final.txt: 813df86f with 11 items; be6abf2f still confirmed, 4 meals, empty shopping.
- runs/18/43-food-plan-after.png: Plan tab still on the confirmed plan.
- runs/18/44-shopping-after.png: Shopping tab showing the draft's list.

**Decision quote.**
> The server adds up the list by fixed rules when the athlete confirms, Confirm waits until the server says it is done, and the list is rebuilt after every plan edit; the phone never works it out itself. The tab shows nine aisle groups, each row with a checkbox and a quantity, in imperial units unless Settings says metric; a row used by more than one meal carries a count that opens a list of those meals, which is also the way back to their recipes. Items marked as had are hidden and only Vana's "Add back" brings them back; there is no per-row "have it" switch and no pickup button, and Share sends plain text. Example: two meals in the plan both use onions, so the list shows one onion row with a count of 2 in imperial units, and tapping the count lists both meals and leads back to either recipe.

**Triage.**
Fix ticket 35 (Lee, 2026-09-25). Closed by the retest after it merges.
