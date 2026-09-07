# Design SSOT — Surface: Food → Meals (catalog + detail)

**Status:** RECORDED v1 (Lee, 2026-09-03) — PROPOSED, awaiting Xuan.
**Source:** prototype `routes/food.meals.tsx`, `food.meals_.$id.tsx`, `food.meals_.recents.tsx`,
`components/vana/meal-catalog.tsx`.
**Code:** Dart `meals_tab.dart`, `meal_detail_screen.dart`, `recents_screen.dart`.
**Scope:** composes meal-card v1 · cooking-mode v1 · `macro-pill-row`.

**What this file owns:** the Food → Meals surface — Mine/Library browse, filters, semantic search, the detail
page, and Recents (FM-1..FM-6); the card and cooking-mode contracts themselves live in their own component
files.

## Contracts

| # | Contract |
|---|---|
| FM-1 | **Mine \| Library**, meal-type chips, No-recipe / Recipes, context chips; the search box is **semantic** (query → embedding → `search_meals(p_embedding)`) with the trigram fallback offline/without an embedding (MS-8). Browsing passes `p_include_disliked: true` so a thumbed-down meal still shows with the thumb lit (MS-3). |
| FM-2 | **Excluded-by-allergy meals show greyed with the allergen tag** (meal-card MC-1) — visible, never addable. |
| FM-3 | **Add opens a servings sheet (stepper, default ×4)** → `pick_meals` on the week's active plan (no conversation scope). |
| FM-7 | **The catalog browse UI is a shared component, `MealCatalogBrowser`** (added 2026-09-03 evening), reused verbatim by `../../surfaces/vana-browse.md` (`/vana/browse?c=<conversationId>`) with a different Add affordance and write target: this surface's Add writes to the week's active plan (FM-3, no conversation scope); the browse-from-chat surface's Add (`MealAddButton`, `meal_planning.browse_add_<id>`) writes to the calling conversation's draft (`pick_meals {conversationId}`). Same list, same cards, different destination for the write. |
| FM-4 | **Detail:** name, why, full attribution + "see the original recipe" link, image with licence credit, ingredients with tappable swaps, contexts, diets/allergens, macro disclosure, the AI-directions badge, notes (saved meals — `set_saved_meal_notes`), thumb (`set_meal_feedback`), heart "Save to mine" (`save_meal`, idempotent — M-8), "Cook" → cooking mode, Make tonight / Add ×N. |
| FM-5 | **Recents** = meals logged OR planned, most recent first (`recent_meals`), resolved to library/saved refs; unlinked log names match a library row by name or are dropped. |
| FM-6 | **The word is meal.** Never plate. |

Conformance: goldens (catalog, excluded card, detail with badge + credit); widget `meal_detail_controller` /
`meal_catalog_controller` tests; the Dart parser tests over `meal_detail.json` / `recent_meals.json`.
