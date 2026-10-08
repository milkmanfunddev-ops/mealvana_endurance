# 08-004 · Seven deep-linked route-only screens have no Back or close control at all

- kind: bug
- status: closed
- ticket: 08
- run: w1-20261007T1105Z
- screen: Sport Settings, Log a Meal, Photo, Describe to Mealvana, Recent & Saved, Choose a Recipe, AI Credits
- decision: 

**Steps.**
1. Open each by deep link (xcrun simctl openurl <udid> "com.milkman.mealvanaendurance:///<path>" (three slashes), signed in as test@test.com): settings/sport-settings, meal-log/manual, meal-log/photo, meal-log/describe, meal-log/recent-saved, meal-log/recipe, buy-credits.
2. Look for a Back, close or swipe-back way out.

**Expected.**
Every screen offers a way back to the app.

**Actual.**
None shows a Back or close control (idb element lists: heading only; no Button 'Back'). With the deep link as the whole stack, the only way out is another deep link or killing the app. (Add Food and Coach Messages, by contrast, have a Back that lands on the Timeline.) Each of these screens normally sits on a pushed stack, so in-app use may be fine; the deep-link entry is what strands the user.

**Evidence.**
- runs/08/c02-sport-settings.png
- runs/08/c06-meal-log-manual.png
- runs/08/c07-meal-log-photo.png
- runs/08/c08-meal-log-describe.png
- runs/08/c09-meal-log-recent-saved.png
- runs/08/c10-meal-log-recipe.png
- runs/08/c12-buy-credits.png

**Decision quote.**
> 

**Triage.**
fix ticket (orphans): comment out the routes and move the screens to _archived, never delete (Lee): /pro, /settings/sport-settings, /settings/food-preferences-consolidated, /settings/food-preferences/add-food, the five standalone /meal-log/* screens, plus the never-built classes. Carefully: mealplanning and a paywall are coming, so /pro will likely be needed again ; /buy-credits and the meal-log screens' Back: see the orphan ticket; /buy-credits itself is ruled separately below

**Closed (wave 3, 2026-10-08).** retest passed in ticket 32 (runs/32/notes.md)
