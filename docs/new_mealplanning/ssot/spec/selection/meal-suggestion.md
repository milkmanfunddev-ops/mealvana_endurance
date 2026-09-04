# SSOT — Meal Suggestion (what a picker, a draft and a staples card may contain)

**Status: RECORDED v1 (Lee, 2026-09-03) — PROPOSED, awaiting Xuan.**
**Engine:** `suggestMeals` · `draftWeek` (edge) · `diagnoseStaples` · `checkCombination` · `weekContexts` ·
`planDayPart` — prototype `server/vana/tools.ts`, edge `_shared/vana/tools.ts`. The edge twin is ahead
(`ingredientsOnHand`, `draftWeek` — D-12).
**Authority for the candidate set:** [`meal-search.md`](meal-search.md). This file owns what happens **around**
the search: which contexts, what is excluded, how many, in what order, and the anti-hallucination gate.

## Vocabulary

- **Shown** — every meal id that has appeared in this conversation's `meal_picker` or `staples` parts
  (`shownMealIds(messages)`, rebuilt from the persisted parts on every turn).
- **In the draft** — `libraryMealId ?? savedMealId` of every meal in the conversation's draft plan.
- **Week contexts** — the tag pair derived from the athlete context, [`vectors/selection/week-contexts.json`]:

| Condition (first match) | contexts |
|---|---|
| `race.daysOut ∈ [0, 7]` | carb-load · race-week |
| character matches /rest\|recovery\|easy/ | rest-day · everyday |
| character matches /high/ | recovery · pre-session |
| otherwise | everyday · recovery |

## Contracts

- **SG-1 · A picker is exactly ONE meal type, up to 3 meals.** `suggestMeals(mealType)` searches with the
  model's `contexts` or the week contexts, excluding *in the draft* ∪ *shown*, and returns the first 3. The
  model never chooses among more than it is shown.
- **SG-2 · "Other options" never repeats.** Because *shown* accumulates across the conversation, a rerun for the
  same type yields new meals or fewer than 3, never a repeat.
- **SG-3 · Filter chips map to search inputs, never to model judgment:** `No recipe only` → `kind: assembly`;
  `Under 20 min` → `maxPrepMinutes: 20` (the search widens to 12 and filters `prepMinutes ≤ 20` — rows with
  null prep are dropped); `Different protein` → a `query` naming another protein; "something with X" → `query X`.
- **SG-4 · Ingredients on hand re-rank, they do not filter** (edge). With `ingredientsOnHand`, the search widens
  to 12 (query = the items joined), each result is scored by how many on-hand items its `ingredients` or `name`
  contain, sorted by that count, and its `why` becomes `Uses your X, Y · <original why>`; meals using none
  still appear after those that do.
- **SG-5 · Staples are suggested, never added.** `diagnoseStaples` = the 5 most-logged meal names in 30 days
  (each matched to the library by embedding when `match_library` score ≥ 0.82, else the log row itself as a
  `saved` ref with id `log:<name>`), then saved meals not already listed, up to 6. `ticked` = currently in the
  draft. Tapping is the only way in (changed from auto-add on 2026-09-02).
- **SG-6 · An ad-hoc combination must pass the pair check.** For components the athlete names that did not come
  from a tool result, `checkCombination` asks `library_pair_support`; if any pair of normalised components has
  0 co-occurrences in the library the combination is "not something athletes eat" and the persona offers
  library options instead. The model may never propose an unsupported combination.
- **SG-7 · Draft-my-whole-week selects nothing by model** (edge). `draftWeek(scope)` fills each uncovered type in
  the coverage scope from the search by week contexts: dinners 3 × 2 servings; lunches 2 × 3; for `all` also
  breakfast 2 × 3 and snack 2 × 3; skips a type the draft already covers; excludes *shown* ∪ *in the draft*.
  At most once per conversation (persona rule 8).
- **SG-8 · Day guidance picks one dinner + one snack** by the day's contexts with no query, snack excluding the
  dinner id ([`../planning/day-guidance.md`](../planning/day-guidance.md)).
- **SG-9 · The day planner fills empty slots from the plan first, then the library.** `planDay`: for each of
  breakfast·lunch·dinner·snack without a slot, the plan meal of that type with the most `servingsLeft` not yet
  used today; else the first library hit for the day's contexts whose name is not already used today (saved
  rows count only when their type matches). `planWeek` = 7 × `planDay` from the week start.
- **SG-10 · Compact is what the model sees.** Tool results carry `compactMeal` (id, source, name, type, kind,
  pattern, why, short attribution, batch, prep, contexts, kcal/carbs/protein) — never the full source string,
  never allergens (the tools already enforced them).

## Invariants (conformance must assert)

1. `|picker.meals| ≤ 3`, all of one `mealType`, none in the draft, none previously shown.
2. Two consecutive `suggestMeals` for the same type in one conversation share no id (SG-2).
3. Nothing enters the draft from `diagnoseStaples`, `suggestMeals` or `dayGuidance` — only `pick_meals`,
   `updateBatch add`, `draftWeek`, `swapMeal`.
4. `checkCombination.supported == false` whenever any pair count is 0.
5. `weekContexts` is total over the two inputs (`week-contexts` vectors).

## Tripwire

`race-week-character-without-event-row` — a race detected from an activity **title** but no `events` row gives
no carb-load tags; the two race signals are not joined. **Q-WC3.**

## Deviations

- **D-12** — `ingredientsOnHand`, `askPantry`, `draftWeek`, `planWeek` exist on the edge twin only.

## Conformance

Vectors: `vectors/selection/week-contexts.json` (9, prototype arm; the edge tools module imports `npm:ai`).
SG-1…SG-9 are DB-bound: covered by the contract fixtures (`meal_picker.json`, `staples.json`,
`day_guidance.json`), the smoke, and `scripts/vana-eval` (SG-2 via the "Other options" conversation). A pure
`rankOnHand(meals, onHand)` extraction would make SG-4 vectorable (Q-SG1).
