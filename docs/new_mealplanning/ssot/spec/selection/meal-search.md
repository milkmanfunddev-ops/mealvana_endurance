# SSOT — Meal Search (the `search_meals` contract)

**Status: RECORDED v1 (Lee, 2026-09-03) — PROPOSED, awaiting Xuan.**
**Engine:** `public.search_meals(...)` (SQL, `supabase/migrations/20260828090000_meal_library_assemblies.sql` +
the vote columns from `20260901120000_recipe_directions_media_feedback.sql`) called through `searchMeals(opts)`
(prototype `server/vana/meals.ts`, edge `_shared/vana/meals.ts`). ONE implementation — the database — so there
is no twin to drift. **Consumers:** every picker, the Meals tab, day guidance, staples matching, `draftWeek`.

> Like `generate-plan.md` in the QA repo this is an **invariant contract**: it says what any correct search must
> guarantee, not how Postgres ranks.

## Inputs

| Param | Meaning |
|---|---|
| `p_user_id` | whose allergies / diet / saved meals / votes apply |
| `p_query` · `p_embedding` | free text and/or its `text-embedding-3-small` vector (the model's `query`, the Meals-tab search box) |
| `p_meal_type` · `p_contexts[]` (any-of) · `p_batch` · `p_kind` (`assembly` \| `recipe` \| null) | filters |
| `p_include_saved` (default true) · `p_include_disliked` (default false) | scope |
| `p_exclude_allergens[]` · `p_require_diet` | **query-time** narrowing on top of the profile ("without nuts", "vegan tonight") |
| `p_limit` | the caller adds `|excludeIds|` then filters client-side |

## Hard invariants — MUST hold

- **MS-1 · Allergies are a hard filter.** No library row whose `allergens` intersects `users.allergies` (or
  `p_exclude_allergens`) is ever returned. There is no override, no warning path — a meal the athlete cannot eat
  does not exist for the selector. (The allergen enum: dairy, eggs, fish, gluten, peanuts, sesame, shellfish,
  soy, tree_nuts.)
- **MS-2 · Diet is a hard filter.** A row is excluded when `excluded_diets @> {users.dietary_preference}`; with
  `p_require_diet` it must also carry that diet in `diets_ok`. (Enum: omnivore, vegetarian, pescatarian, vegan,
  mediterranean, paleo, keto, low_carb.)
- **MS-3 · A thumbs-down is never suggested again.** `meal_feedback.vote = −1` removes the row from every
  suggestion path; browsing (`p_include_disliked: true`, the Meals tab) still shows it with the thumb lit.
- **MS-4 · Saved meals rank first.** A saved meal's score carries a +0.15 offset over the same similarity, so
  "what you already eat" beats the library at equal fit. Saved rows are not allergy/diet filtered — they are
  the athlete's own (MS-1 applies to the library).
- **MS-5 · Common beats clever.** Library rows get +0.04 for `frequency = staple`, +0.02 for `common`; a
  thumbs-up adds +0.10.
- **MS-6 · Saved meals with no `meal_types` match every type.** (`s.meal_types = '{}'` passes any
  `p_meal_type`) — which is why day guidance excludes the dinner pick from the snack search.
- **MS-7 · One result set, one order.** Saved ∪ library, ordered by score desc, limited once. The caller may
  drop `excludeIds` afterwards but never re-rank.
- **MS-8 · Similarity without an embedding is trigram.** `p_embedding` null + `p_query` → `greatest(similarity(name),
  word_similarity(query, search_text))`; neither → a flat 0.5 so filters and nudges alone decide.

## Soft invariants — SHOULD hold (quality, not correctness)

- **S-1** the `why` line is honest and specific to the meal (it is catalog data, `../domain/meal.md`).
- **S-2** `attributionShort` ≤ 40 chars names a person or source, never a URL (`attribution-short` vectors).

## What the caller adds (`searchMeals`)

- Embeds `query` unless `embed: false`; on embedding failure falls back to trigram silently (MS-8).
- Requests `limit + |excludeIds|`, filters `excludeIds` client-side, slices to `limit`.
- Shapes rows into `MealRef` (`rowToMealRef`): `libraryMealId` = id for library rows; `attributionShort`
  computed when the row lacks it; `icon` resolved (`../planning/meal-icon.md`); `myVote` from the row.

## Conformance

The prototype's `contract.test.ts` and smoke exercise MS-1 (a picker never contains an allergen the QA user has)
and the two-suggestion rule against dev. **No pure vectors exist** for a SQL function; the QA repo's precedent
for DB-shaped truth is a *producer-shaped seam test* (ship-bundle rule). Proposed: a Deno test that seeds one
athlete with `allergies = {gluten}`, `dietary_preference = vegan`, one −1 vote, one saved meal, and asserts
MS-1…MS-6 against dev — `conformance/README.md` §Not yet covered.
