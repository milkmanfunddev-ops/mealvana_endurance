# Meal planning — research base (assembled 2026-08-26)

Everything the team has produced or learned about meal planning, pulled into one place so the
next design/prototype iteration starts from evidence rather than memory.

> **2026-09-03:** [`ssot/`](ssot/README.md) is now the full meal-planning SSOT in the QA repo's shape — six
> families (`intent` · `planning` · `selection` · `domain` · `agent` · `design`), 150 executable vectors, three
> conformance runners (edge · prototype · Dart), `DEVIATIONS.md` (D-1..19) and `OPEN-QUESTIONS.md`; every spec
> is RECORDED v1 → PROPOSED, awaiting Xuan.
> **2026-09-02:** `ssot/` added — the meal-planning SSOT (Xuan's design intent for the Vana
> chatbot as a normative spec + deviations register, QA-repo style; status PROPOSED, awaiting
> Xuan). **Implementation plan: [`vana-chatbot-update-plan.md`](vana-chatbot-update-plan.md)** — best-judgment resolution of the Q-register + 5 phases from current code to Xuan's vision. New Notion captures: `notion/ai-scenarios-structured.md` + `notion/ai-scenarios-unstructured.md`
> (Xuan's "AI Scenarios (Lee)" page — the deliverable for the meal-planning design Lee asked for).

**Start here:** [`synthesis-and-recommendations.md`](synthesis-and-recommendations.md) — the
cross-source synthesis and the concrete recommendations for the prototype. Then
[`walkthrough.md`](walkthrough.md) — the turn-by-turn script of what Vana says and what the user can tap.

> **2026-09-01:** the JSON libraries, scrape/direction artefacts and the seven `*.mjs` pipeline scripts moved to
> the prototype repo (`~/development/mealplanning-prototype/packages/web/{data,scripts}/`) so it is self-contained.
> The `.md` libraries, research provenance and specs stay here. Integration plan: `docs/implement_mealplanning/`.

## Layout

| Folder / file | What it is |
|---|---|
| `notion/INDEX.md` | Every Notion page found (60), what it is, where it was saved, what was inaccessible |
| `notion/user-research-synthesis.md` | All user/coach/dietitian research, synthesized; ends with the 10 ranked insights |
| `notion/product-thinking-synthesis.md` | The team's own product discussion: timeline, decisions, open questions, disagreements, scope, tech |
| `notion/*.md` (58 more) | Faithful transcriptions of each Notion page (interviews, meeting notes, specs, prototype briefs, test results) |
| `meal-library-400.md` / `.json` | The 400-meal library (100 per slot) with context/diet/allergen/batch/swaps/why/source tags; raw research in `meal-library-research/` |
| `figma/mealbuddy-figma.md` | Screen-by-screen walkthrough of the "AI Assistant module" Figma (MealBuddy, 27 frames): all copy, widgets, keep/conflict lists |
| `figma/NN-*.png` | Frame captures from that Figma file (see the doc's image list) |
| `figma/archived-2026-07/` | Five earlier captures of the same file from `docs/_archived/mealplanning_prototype/screenshots/figma` |
| `prototype/prototype-analysis.md` | Deep read of `github.com/lbm54/mealplanning-prototype` — architecture, agent design, data model, what's real vs. stubbed, adoption checklist |
| `meal-library-400.md` / `.json` | **The 400-meal library** (100 breakfast / lunch / dinner / snack) endurance athletes actually eat, tagged with the app's exact diet + allergen enums, context (pre-session / recovery / rest-day / race-week / carb-load / travel), swaps, rough macros, and sources. Computed coverage matrix at the top. |
| `meal-library-research/` | Provenance for the library: 17 raw research passes (pro-triathlete diets, publications, dietitians/cookbooks, TrainerRoad + Reddit, Substacks, per-meal-type, vegan, GF/DF, allergen-safe, paleo/keto/Med, international, rest-day/race-week), the two agent briefs, the four per-type selections with their coverage checks, and the validate/extract/merge scripts in `tools/`. |
| `assembly-library.md` / `.json` | **The 1,522-assembly library** (356 breakfast / 398 lunch / 398 dinner / 370 snack) — no-recipe meals (1–6 plain components, no method: "chicken, rice & broccoli", "oatmeal with blueberries") endurance athletes are documented eating, each with a `pattern` (protein + starch + veg…), `frequency` (staple/common/occasional), attributed `source` + `evidence`, and the same diet/allergen/context tags as the 400-library. Coverage matrix + most-common patterns at the top. |
| `supabase/migrations/20260828090000_meal_library_assemblies.sql` + `mealplanning-prototype/packages/web/scripts/seed_meal_library.mjs` | **Applied to DEV 2026-08-28.** `meal_library.kind` (`assembly`\|`recipe`), `pattern`, `frequency`, `evidence`, `shard_id`; `search_meals(... p_kind)` returns kind/pattern/frequency and nudges staple/common up; `meal_library_pairs` materialized view (component co-occurrence, 8.1k pairs) + `library_pair_support(text[])` — the anti-hallucination check (a proposed combination with any 0-count pair is not something athletes eat). Loader upserts both JSON libraries (400 split 153 assembly / 247 recipe by heuristic), embeds new rows via AI Gateway, refreshes the view. Dev now holds 1,922 rows. |
| `assembly-library-research/` | Provenance: `BRIEF.md` (definition of an assembly + record shape), 16 shard files (4 angles × 4 meal types), `tools/lint_merge.py` (enum + ingredient-sanity lint, dedupe, merge) and `tools/fix_tags.py`. |
| `repo/repo-context.md` | What already exists in this Flutter app that a planner can build on (recipes, meal logging, formula kit, ai_coach, credits, events, weather…), schema, edge functions, constraints, and gaps |

## Related material elsewhere in the repo

- `docs/_archived/mealplanning_prototype/` — the July 2026 design corpus (competitive landscape, five UI variants,
  the 30-widget catalog derived from this same Figma, chatbot failure modes). Archived, but the product
  thinking is still the best written record of *why* the current direction exists.
- `docs/features/carb_loading/carb_loading.md` §3 — the pre-existing shopping-list spec.
- `docs/ssot/` — the fuelling SSOT; race-day fueling stays deterministic and outside the planner.
- Design canvas (v2, 2026-08-26 — "Vana", Food tab, diagnose-and-add, cooking-session batch): https://claude.ai/code/artifact/c776e4cd-1e7f-4f7a-8c71-a6a2d332ec21
