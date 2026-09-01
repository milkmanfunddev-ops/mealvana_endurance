# Assembly library — scout brief (2026-08-28)

## What we are collecting

An **assembly** is a meal that is *put together*, not *cooked from a recipe*: 2–6 plain components, each
prepared (or not) on its own, combined on the plate / in the bowl / in the bag. You can describe it in one
line with no steps: "chicken, rice & broccoli", "oatmeal with blueberries", "Greek yogurt, granola & honey",
"rice cakes with peanut butter". Snacks may be a single component ("banana").

**Not an assembly** (exclude): anything with a method — casseroles, bakes, curries/stews built from a sauce,
homemade sauces or dressings, pancakes/waffles/muffins from batter, anything where the quantities have to be
right. If it would be on a recipe card, it is a recipe, and we already have those.

The point of this library is **anti-hallucination**: the meal-planning agent must only offer combinations
real endurance athletes are documented eating. Common beats clever. "Oatmeal with butternut squash and pork
tenderloin" is not a breakfast anyone eats; do not let anything like that in.

## Record shape (JSON array, one object per assembly)

```json
{
  "id": "L-a-001",
  "name": "Chicken, rice & broccoli",
  "meal_type": "lunch",
  "components": [
    {"food": "chicken breast", "qty": "200 g", "role": "protein"},
    {"food": "white rice, cooked", "qty": "250 g", "role": "starch"},
    {"food": "broccoli, steamed", "qty": "150 g", "role": "veg"},
    {"food": "olive oil", "qty": "1 tbsp", "role": "fat"}
  ],
  "pattern": "protein + starch + veg",
  "context": ["everyday", "recovery"],
  "cuisine": "general",
  "diets_ok": ["omnivore", "pescatarian", "mediterranean", "paleo"],
  "allergens": [],
  "swaps": "chicken→tofu (vegan, soy); rice→quinoa (same profile)",
  "approx_macros": "~650 kcal · 80g C · 50g P · 14g F",
  "prep": "10 min",
  "batch": true,
  "frequency": "staple",
  "source": "https://... ; Name, publication",
  "evidence": "\"my go-to lunch five days a week\" — quote or close paraphrase showing how common this is",
  "reconstructed_from_snippet": false
}
```

- `id`: `<B|L|D|S>-<shard letter>-<3-digit>` — the brief tells you your shard letter.
- `components[].role`: one of `protein` `starch` `veg` `fruit` `fat` `dairy` `sauce` `drink` `other`.
  `food` should be a plain catalog-style name (the thing you would search for in a food database), not a
  dish name. `qty` is an athlete-sized single serving, rough is fine.
- `pattern`: the roles joined with ` + ` in the order they matter (`protein + starch + veg`, `grain + fruit +
  dairy`, `bread + spread + fruit`). This is what lets the planner see what "normal" looks like.
- `context`: subset of `everyday` `pre-session` `recovery` `rest-day` `race-week` `carb-load` `travel`.
- `diets_ok` / `allergens`: **exact** tokens from `lib/features/onboarding/domain/dietary_preference.dart`
  and `lib/features/onboarding/domain/allergy.dart` — read those files first. Judge as written, before swaps.
- `frequency`: `staple` (source says daily / go-to / most common), `common` (multiple sources, or "often"),
  `occasional` (one source, no frequency language). Aim for ≥60% staple+common.
- `approx_macros`: rough estimate, labelled with `~`. Not catalog truth.
- `source` is mandatory. No source, no record.

## Dedupe

`docs/new_mealplanning/meal-library-400.json` already holds 400 meals (many of them component-style). Grep it
for your candidate's protein/starch/main components; if the same protein + same starch + same veg (or the same
main + same topping for breakfast/snacks) is already there, skip it or make it a genuinely different assembly
(different starch, different veg). Also do not duplicate within your own file.

## Output

Write **100 records** to the file path in your brief. Then reply with: count, coverage (per `diets_ok`
value, per allergen-free, per context), your 3–5 strongest sources, and anything you could not satisfy.
