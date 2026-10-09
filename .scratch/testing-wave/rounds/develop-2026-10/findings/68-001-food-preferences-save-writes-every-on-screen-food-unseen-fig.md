# 68-001 · Food Preferences Save writes every on-screen food: unseen Fig Bar lands on the server as dislike 0, and every row's id and created_at are rewritten

- kind: bug
- status: triaged
- ticket: 68
- run: w7-20261008T2309Z
- screen: Settings > Diet, Allergies & Formulas > Food Likes & Dislikes (Food Preferences)
- decision: 

**Steps.**
1. Signed in on a cleared app as test@test.com; server held 9 food_preferences rows (all created 17:23:53Z).
2. Opened Food Preferences, dragged Sports Drink 4 -> 3, never opened 'Show more food options', tapped Save Changes at 23:16:20-22Z.
3. Read food_preferences (named columns) and a copy of the Drift file.

**Expected.**
Save changes the one row the athlete moved (sports_drink). Foods the athlete never saw or touched keep no row (or their old one), and existing rows keep their id and created_at.


**Actual.**
The server went from 9 rows to 14. Five rows were inserted that the athlete never touched: carb_drink_mix, energy_chews_mini_pack, granola_bar, high_carb_drink_mix at willing_to_try 2, and fig_bar at **dislike 0**. Fig Bar sits under the collapsed 'Show more food options' and was never on screen; the athlete now 'dislikes' it on the server. Every existing row got a new id and created_at: on-screen rows took 23:16:23, and rows not on the screen (Bagel (plain), Bananas, oatmeal_cooked, toast) took 23:12:05, the time the screen pulled them, so their 17:23:53 created_at was lost. food_preferences_saved reports total_foods 10. The sports_drink part of the save is right (see notes: PASS 49-010 save).


**Evidence.**
- runs/68/db-food-preferences-before.txt: 9 rows, created_at 17:23:53, no fig_bar.
- runs/68/db-food-preferences-after-save.txt: 14 rows, fig_bar dislike 0, new ids and created_at.
- runs/68/drift-food-preferences-after-save.txt: the same 14 rows locally.
- runs/68/02-sports-drink-moved-to-3.png: the one move made.

**Decision quote.**
> 

**Triage.**
- triaged · fix ticket 78 (Food Preferences Save writes only changed foods, keeps row ids; five stray dev rows deleted at the close), fix wave 8 · Lee, 2026-10-09
