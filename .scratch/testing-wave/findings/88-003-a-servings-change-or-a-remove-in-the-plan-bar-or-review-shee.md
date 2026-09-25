# 88-003 · A servings change or a remove in the plan bar or Review sheet does not rebuild the shopping list

- kind: ssot-conflict
- status: triaged
- ticket: 88
- run: w29-20260925T1949Z
- screen: Vana chat (plan bar, Review plan sheet)
- decision: mp-244

**Steps.**
1. Conversation `1a24f2bf` (confirmed f2c0bc78, week of Sep 13, list 77fd387c). Expand the plan bar, tap + on "Rice, seitan & roasted broccoli bowl" (19:59:45Z): servings 4 to 5.
2. Read the plan's list (Seitan row) at 20:00:02Z and 20:00:16Z. Restore with − (20:01:11Z).
3. Conversation `0401b3d8` (draft 173cebb2, list 813df86f): Browse adds "Toast with peanut butter & honey" (list rebuilt to 14 rows at 20:04:35Z); Review plan > Remove on Toast (20:05:33Z); read the list at 20:05:45Z.
4. Same in the new draft 8ebeb6da: Review > Remove Egg & Veggie Scramble (20:20:59Z), list 2aeb8156 read at 20:21:03Z.

**Expected.**
mp-244: the list is rebuilt after every plan edit. After step 1 the Seitan row is 750 g; after step 3 the peanut butter and honey rows are gone; after step 4 the egg, pepper and spinach rows are gone.

**Actual.**
The plan rows change on the server but the lists do not: 77fd387c keeps Seitan 600 g with updated_at 2026-09-17; 813df86f keeps "Peanut butter 4 tbsp; Honey 4 tsp" and its 14 rows (updated_at still the 20:04:35 pick); 2aeb8156 keeps Bell pepper, Spinach and Egg. The edge log shows no vana-action call for these edits, only `get_plan`: the stepper and Remove are local-first writes replayed through the `plan_set_servings` / `plan_remove_meal` RPCs (`meal_plan_repository.dart`), which touch plan_meals only, while the list is built in `refreshShopping` on the server. Confirm rebuilds the list (8ebeb6da's confirmed list had the right 5 rows), so a draft's list is only wrong until confirm, but a confirmed plan's list stays wrong after every stepper or remove edit.

**Evidence.**
- runs/88/db-05-15-005-f2c0bc78.txt: servings 4 -> 5, list 77fd387c unchanged (Seitan 600 g).
- runs/88/edge-01-after-stepper.txt: only get_plan at 14:59:47 local.
- runs/88/db-09-09-006-after-remove.txt: Toast gone from plan_meals, still in list 813df86f.
- runs/88/edge-03-09-006-remove.txt: no remove call.
- runs/88/db-20-09-006-remove-egg.txt: Egg gone from plan_meals, egg/pepper/spinach still in 2aeb8156.

**Decision quote.**
> The server adds up the list by fixed rules when the athlete confirms, Confirm waits until the server says it is done, and the list is rebuilt after every plan edit; the phone never works it out itself. The tab shows nine aisle groups, each row with a checkbox and a quantity, in imperial units unless Settings says metric; a row used by more than one meal carries a count that opens a list of those meals, which is also the way back to their recipes. Items marked as had are hidden and only Vana's "Add back" brings them back; there is no per-row "have it" switch and no pickup button, and Share sends plain text. Example: two meals in the plan both use onions, so the list shows one onion row with a count of 2 in imperial units, and tapping the count lists both meals and leads back to either recipe.

**Triage.**

Fix ticket 127 (Lee, 2026-09-25): build to mp-244 as approved. Closed by the retest after it merges.
