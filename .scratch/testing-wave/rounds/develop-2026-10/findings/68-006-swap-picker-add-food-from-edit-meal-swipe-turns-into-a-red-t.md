# 68-006 · Swap picker (Add Food, from Edit Meal swipe) turns into a red 'Tried to modify a provider while the widget tree was building' screen when searching

- kind: bug
- status: open
- ticket: 68
- run: w7-20261008T2309Z
- screen: Edit Meal > swipe item right-to-left > swap picker ('Add Food')
- decision: 

**Steps.**
1. Retest of 49-009 (check 10). Logged meal f380f4c8 open in Edit Meal (Timeline card > Edit food).
2. Swiped the only item right to left at 23:28:26Z: the picker opened titled 'Add Food' with My Foods (1) and Recommended Foods (swap_food_screen_viewed {is_swapping: false, category: before_run}).
3. Tapped 'Search for food...', typed 'rice' with idb.

**Expected.**
Search results for rice to pick from.


**Actual.**
The whole screen went to Flutter's red error screen: 'Tried to modify a provider while the widget tree was building. …' Dev Sentry MEALVANA-ENDURANCE-DEV-BX (23:28:38Z, level fatal, handled no, this device): SwapFoodScreen.build -> _seedSearchController (swap_food_screen.dart:128) -> FoodSearchController.updateFoodPool/updateSearch sets provider state during build. The console shows no Flutter line for it after swap_food_screen_viewed. Riverpod's check is a debug assert, so a release build may not show red, but the picker writes provider state during build either way. This blocks check 10's search, pick, quantity and Edit Item steps on the debug testing build.


**Evidence.**
- runs/68/10c-search-rice.png: the red screen.
- runs/68/10b-swap-picker.png: the picker before typing.
- runs/68/sentry-dev-bx-swap-food.txt: the Sentry event and first-party frames.

**Decision quote.**
> 

**Triage.**

