# 08-003 · Close/Back on deep-linked /pro and /settings/food-preferences-consolidated does nothing

- kind: bug
- status: open
- ticket: 08
- run: w1-20261007T1105Z
- screen: Mealvana Pro (/pro); Food Preferences (/settings/food-preferences-consolidated)
- decision: 

**Steps.**
1. Open xcrun simctl openurl <udid> "com.milkman.mealvanaendurance:///pro" (three slashes), signed in as test@test.com. Tap the X (top left).
2. Open xcrun simctl openurl <udid> "com.milkman.mealvanaendurance:///settings/food-preferences-consolidated" (three slashes), signed in as test@test.com. Tap the back arrow (top left).

**Expected.**
Each closes to the Timeline or the screen it was opened over.

**Actual.**
Both buttons do nothing: the screen stays, no console line. Both call context.pop() (pro_version_screen.dart:27, food_settings_consolidated_screen.dart:239, from code) and the deep link left nothing under them. A left-edge swipe does nothing either. The user is stuck until another deep link or a relaunch. Food Preferences' Save path also ends in context.pop() (line 162), so a save there would strand the user the same way (not tried: read-only ticket). The /pro X also has no accessibility label (idb lists `Button ''`).

**Evidence.**
- runs/08/c01-pro.png /pro opened
- runs/08/c01b-pro-close.png still on /pro after tapping X twice
- runs/08/c03-food-prefs-consolidated.png Food Preferences opened
- runs/08/c03b-food-prefs-back.png still there after Back

**Decision quote.**
> 

**Triage.**
