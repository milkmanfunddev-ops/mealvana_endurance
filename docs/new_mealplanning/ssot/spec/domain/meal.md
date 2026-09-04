# SSOT — Meal (catalog and reference rules)

**Status: RECORDED v1 (Lee, 2026-09-03) — PROPOSED, awaiting Xuan.**
**Owners in code:** `meal_library` (schema `20260827090000` + `20260828090000` + `20260901*`), `saved_meals`,
`meal_feedback`; `MealRef` / `MealDetail` in `contracts.ts` (frozen `contract-v1`).

## Definitions

- **Meal** — a named thing an athlete eats at one sitting, typed by one of `breakfast · lunch · dinner · snack`.
- **Assembly** (`kind = assembly`, 1,675 rows) — 1–6 plain components with **no method** ("chicken, rice &
  broccoli"); carries a `pattern` ("protein + starch + veg") and a `frequency` (`staple · common · occasional`).
  Rendered "No recipe". Source: `../../assembly-library.md` (1,522) + the heuristic split of the 400-library.
- **Recipe** (`kind = recipe`, 247 rows) — has a method; `method_steps[]` with provenance (below).
- **Saved meal** — the athlete's own row in `saved_meals`, optionally linked to a library row
  (`library_meal_id`); inherits the linked recipe's method, media, swaps and why.
- **Library ref** — `MealRef.source = library`, id like `D-048`. **Saved ref** — `source = saved`, id = uuid.
  A log-only staple that matched nothing is a synthetic saved ref with id `log:<name>` (never persisted).

## Rules

- **M-1 · The catalog vocabulary is the app's.** `contexts ⊂ {everyday, pre-session, recovery, rest-day,
  race-week, carb-load, travel}`; allergens and diets use the app's `allergy_enum` / `dietary_preference_enum`
  exactly (`meal-search.md` MS-1/2). A tag outside the enums is a lint failure at seed time
  (`assembly-library-research/tools/lint_merge.py`, `meal-library-research/tools/validate.py`).
- **M-2 · Macros are per athlete serving and approximate.** `kcal / carbs_g / protein_g / fat_g` are library
  estimates, "not catalog-grounded" (prototype README). They feed coverage per-day averages and the macro pills;
  they are never presented as targets. **No fiber, no sugar, no sodium on a meal** — a surface may not
  synthesise them (design `macro-pill-row.md` MP-4).
- **M-3 · Every library meal carries a `why` and a `source`.** `why` is one honest line specific to the meal;
  `source` is the full attribution; `attributionShort` (≤ 40 chars) is what cards and the model see.
- **M-4 · Directions carry provenance.** `directions_origin ∈ {source, alt_source, ai_generated,
  assembly_simple}`; `directions_verbatim` is the narrower claim "these are the publisher's words". The UI
  badges `ai_generated` (197 rows, unreviewed) — [`../design/components/cooking-mode.md`](../design/components/cooking-mode.md).
  `origin` says where the idea came from; `verbatim` says whose sentences these are. Never conflate.
- **M-5 · Images are hotlinked and licensed.** `image_url` + `image_license/creator/credit/source_url`; CC-BY
  requires the visible credit, so the caption is load-bearing. 708 of 1,922 have one; the rest render the icon —
  never a vaguer photo (`../../recipe-directions-and-cooking-mode.md` §5).
- **M-6 · The meal name is the house style.** Lowercase joiners, components first ("chicken, rice & broccoli",
  not "Rice bowl with chicken"). The word is **meal**, never plate (walkthrough rule).
- **M-7 · Feedback is one thumb per athlete per meal.** `meal_feedback.vote ∈ {−1, 1}`, written only through
  `set_meal_feedback()` (partial unique indexes — never a PostgREST upsert); the same vote again clears it; 0
  clears outright. Effect on search: MS-3 / MS-5.
- **M-8 · "Save to mine" is idempotent.** `saveLibraryMeal` returns the existing saved row for the same
  `(user, library_meal_id)`; a fresh save copies name, items (from `ingredients_json`), macros, type, batch,
  icon, and links `library_meal_id`.
- **M-9 · An ingredient swap creates a saved variant** (edge, Phase 6). `swap_ingredient(planMealId, from, to)`
  clones the meal into `saved_meals` as `<name> (<to>)` with the component replaced (substring match on the
  normalised name; error if `from` is not in the meal), swaps it into the plan in place, records
  `swaps_applied`, and the shopping list rebuilds. Recipes and assemblies alike; the catalog's `swaps` strings
  ("water→milk (+10g protein)") are the offered options.
- **M-10 · Icon.** Every meal has a `MealIconKey` — [`../planning/meal-icon.md`](../planning/meal-icon.md).

## `MealRef` (wire, camelCase — frozen)

`source id name mealType contexts[] batch prepMinutes kcal carbsG proteinG fatG allergens[] dietsOk[] swaps why
attribution attributionShort ingredients libraryMealId score kind? pattern? frequency? icon? myVote?` — the
Zod `MealRefZ.strict()` in the edge `schemas.ts` is the executable form; the Dart `MealRef.fromJson` reads the
same keys; `tests/fixtures/*.json` are the truth.

## Open questions

| Q | Question |
|---|---|
| Q-ML1 | The 197 `ai_generated` direction rows are unreviewed. Who reviews, and does a review flip `origin`? |
| Q-ML2 | Library macros are approximate; should a meal ever show a macro it cannot stand behind (M-2), or should assemblies show none? |

## Conformance

Contract fixtures (`tests/contract.test.ts` → `tests/fixtures/`), validated by `schemas.ts` in
`supabase/functions/tests/vana/contract.test.ts` (88/88 on 2026-09-02). Catalog lint at seed time. No vectors.
