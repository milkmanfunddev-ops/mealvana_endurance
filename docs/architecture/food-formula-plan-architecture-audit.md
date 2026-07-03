# Food / Formula / Plan Architecture Audit & Cleanup Plan

**Date:** 2026-07-03
**Scope:** Terminology, the nutrition-plan generation flow (formulas vs foods), endurance-vs-general data separation, and a dead-code inventory. Produced from four parallel code investigations.

---

## 0. Bottom line up front

- **The big pieces already exist.** System formulas ✓, personal formulas + pinning ✓, AI-coach formula authoring ✓, save-whole-plan-as-reusable ✓, after-phase formulas ✓, during-phase "formula-first, solver-as-fallback" ✓.
- **The confusion is ~90% terminology.** The word **"template" means four unrelated things** and **"formula" means three**.
- **Two real functional gaps:** (a) **onboarding seeds no formulas**, so most users are *effectively still solver-first* despite the formula-first code existing; (b) **before-phase formula pins aren't honored on the primary path** (only the client fallback).
- **Do NOT build v4.** v3 already implements the formula-first order for during/after. Evolve it (see §5).
- **No endurance-vs-general separation.** All scan/search surfaces share one unfiltered pool, so potato salad can appear in plan add/swap and Maurten gels can appear in breakfast logging.

---

## 1. Terminology — the root cause

**"Template" = four things. "Formula" = three.**

| Term in code | What it actually is | Layer |
|---|---|---|
| `template_foods` | Single-ingredient catalog (one food + USDA macros) | atom |
| `pre/during/post_workout_templates` | **System fuel recipes** — the UI calls these **"Formulas"** (Formula Library). `pre_workout_templates` was *renamed from `pre_workout_formulas`* | recipe |
| `personal_formulas` | **User-authored** single-phase fuel recipe (Formula Kit) | recipe |
| `personal_templates` | **User's saved whole plan** — "Save as Template" / "My Templates" / "Use Template" (the 15-mile-run / Ironman idea) | full plan |
| `formula` (column) | A plain display-label string on template rows | field |
| `food_preferences` | like / dislike / willing per food | signal |

### Recommended canonical vocabulary — three user-facing nouns

| Use this | Means | Retire this name |
|---|---|---|
| **Formula** (System / Personal) | a reusable single-phase fuel recipe | "workout_template" as a user/domain word |
| **Plan** | one generated day's nutrition | — |
| **Routine** (or "Saved Plan") | a user-saved, re-appliable whole plan | **"Template"** / "My Templates" ← worst offender |

**Renames, by cost:**
- **Cheap & high-value:** rename all UI strings for `personal_templates` "Template" → **"Routine"**/"Saved Plan". Kills the worst collision, zero DB risk.
- **Cheap:** rename the domain `formula` string column → `displayLabel` in Dart mappers.
- **Deferred (DB table renames, gate behind a min-version bump):** `*_workout_templates` → `*_workout_formulas`, `template_foods` → `food_catalog`. Document the mapping now; rename later.

---

## 2. What's REAL vs MISSING vs DEAD

### ✅ Real and matches the vision (no work needed)
- `personal_formulas` (fork "Make this mine" + from-scratch), AI coach insight authoring (`ai-coach` edge fn, credit-gated, persisted).
- Pinning (`formula_pins`, `template_kind`: `*_system` + `personal_formula`) — a pin bypasses preference/diet/scale filters.
- **During & After: pin-first → solver-fallback already implemented.** In-scope personal-formula pin is scaled to the carb target and returns immediately, bypassing the solver.
- **After-phase formulas are complete** (parity with during + fluid/sodium backfill).
- Save-whole-plan-as-reusable = `personal_templates` ("Routine"), with rescaling on re-apply.

### ⚠️ Missing (the real gaps)
1. **Onboarding seeds no formulas.** Onboarding sets diet/allergies/profile only. Consequence: a new user has zero pinned formulas → every plan falls through to the template solver. **The app is still effectively solver-first for most users.** Highest-leverage fix.
2. **Before-phase personal-formula pins are only honored via the client fallback** (~1% path), applied *last as an overlay* rather than first — before-selection happens in macros-v4.
3. **No endurance-vs-general data separation** (see §3).

### 🪦 Dead / legacy (removal candidates — verify then cut)
- `_shared/nutrition/food-queries.ts` → `getFoodsForPhase` / `getElectrolyteFoods`: defined, never called in v3. Dead.
- `FoodPreferencesScreen` + `/settings/food-preferences` route + `food_preferences_v2_screen`: orphaned (nav removed 2026-06-25). Dead UI.
- Legacy **`foods` table**: down to a single live use — `getEssentialFoods` (water/salt backfill on the pin path). Migrate essentials → `template_foods.is_essential`, then retire (behind version gate).
- `postProcessDuringPhase`: `@deprecated` for the rule path, still used by LP.

### 🔩 Load-bearing — do NOT remove
- `to_exclude_from_solver` — actively filters the solver pool at runtime (`template-food-queries.ts:359/807/1119`).
- `is_deleted` — real soft-delete on foods, pins, and formulas.

### 🤔 The phantom system — food preferences
The preferences UI was removed (steering users to formulas), **but the algorithm still consumes preference data** in before + during (disliked filters the pool; liked/willing drive scoring). No UI to set it, but the solver still weights it.
**DECISION (2026-07-03): rip out the plumbing** — remove preference consumption from before/during selection + scoring; delete orphaned preference code. Allergies + diet filtering stay (safety, not preference).

---

## 3. Endurance vs. general food — the separation problem

- **One universal scanner** for every context (`BarcodeScannerScreen`). It takes `category`/`context` strings, but the router doesn't forward `context` and the lookup is identical regardless of why you scanned. Everything lands in `user_foods` with `product_type` defaulting to `'import'`.
- **One shared, unfiltered search pool** across all surfaces (`FoodSearchController` → user_foods + template_foods + The Feed + OpenFoodFacts). Plan add/swap and meal-logging Discover seed from the same `getPrimaryFoodsForPreferences()`. The catalog search *supports* a `product_type` filter — it's never passed (`shared_food_search_service.dart:120-122`).

**The separation signal already exists: `product_type`** (gel/chew/drink_mix/bar/… = fuel; `real_food`/`import` = general). It's classified at scan time — it's just not used to filter.

**Answers to the raised questions:**
- **Two separate scanners?** No. A food's identity is the same regardless of why it was scanned. Fix is **context-aware display/search filtering by `product_type`**, not two scan flows.
- **Doritos on a run?** Logged via meal logging (shows everything); excluded from plans (import/general types excluded from fuel selection); explicit opt-in if they truly want it as planned fuel.
- **Different process per surface?** Yes — filter the shared pool by `product_type`:
  - **Plan add/swap** → restrict to fuel types + The Feed + endurance user foods (no potato salad).
  - **Meal logging** → general foods; deprioritize pure fuel.

**Design principle:** the boundary is `product_type`, enforced at the search/display layer per surface. Add a derived **`is_fuel`** predicate (whitelist over `product_type`) so it's one clean check instead of ad-hoc lists.

---

## 4. Plan-generation flow — current vs the vision

Ideal per phase: **pinned formula → default formula → solver → generic.** Reality:

| Phase | Actual order | Matches vision? |
|---|---|---|
| **During** | personal-formula pin → template solver → rule → LP → greedy | ✅ (no default-formula tier exists) |
| **After** | personal-formula pin → post-template solver → LP | ✅ |
| **Before** | template solver (Algo C) → user-substitution → **formula pin overlay LAST** | ❌ pin should be first |

- The **"default formula" tier doesn't exist** — because nothing seeds default formulas. Fixed by onboarding + safety-net auto-pin (§6). Once users have pins, the existing pin tier *is* the "use the formula" step.
- **Before is inconsistent** — pin applied last, edge honoring only partial.
- **Hydration/electrolytes** is not a uniform step — path-specific, deficit-triggered (pin path backfills from legacy `foods` essentials; during-solver uses `template_foods` electrolytes; after-template does nothing). Consolidation candidate.

---

## 5. v3 or v4? → **Evolve v3. Do not build v4.**

- The hard part — formula-first ordering with solver fallback — already exists for during/after. A v4 would re-achieve it at huge risk.
- The "cleaner" comes from four incremental changes, not a rewrite:
  1. **Seed formulas at onboarding + safety-net auto-pin** → flips the app from *effectively solver-first* to *actually formula-first*. Highest leverage.
  2. **Wire before-phase pin-first** to match during/after.
  3. **Rip out the phantom preferences.**
  4. **Enforce product_type filtering per surface** (data separation).
- v4 is only justified to change the macro math — which nobody is asking for.

---

## 6. Auto-pin design (decided 2026-07-03)

**Decision: auto-pin SYSTEM formulas**, in two placements calling one shared selector.

```
selectDefaultFormula(phase, activityType, diet, allergies):
  candidates = system formulas WHERE activity matches
                 AND passes diet filter
                 AND contains no user allergens
  if candidates empty  -> return null   # graceful: no pin, solver handles it
  else                 -> pick best-fit (selection_priority) system formula
```

- **At onboarding** → write **real pin rows** (setup moment; user gets owned, editable formulas per phase for their sport).
- **Safety net before generation** → catches existing users, uncovered sports/activities, and unpinned users. **Recommended: ephemeral** — select + honor a system formula for that run and tag the result via `PinDecision` ("used System Formula X"), optionally nudge "Pin this?", **without silently writing pin rows** into existing users' data. *(OPEN: confirm ephemeral vs persist-real-pins for the safety net.)*
- **Constraints honored:** sport type (activity match), diet + allergies (filter). **"No formula for this activity" is handled by design** — selector returns null, no pin, solver runs. Auto-pin is best-effort and never blocks a plan.

---

## 7. Prioritized action plan

**P0 — realizes the formula-first vision:**
1. `selectDefaultFormula` selector + **safety-net auto-pin** in v3 (universal formula-first flip).
2. **Onboarding auto-pin** (writes real pins for new users).
3. Terminology: rename `personal_templates` UI → **"Routine"** (near-zero risk).

**P1 — consistency & correctness:**
4. **Before-phase pin-first** (honor before personal-formula pins on the edge path).
5. **Rip out food preferences** (remove solver consumption + orphaned screens; keep allergy/diet).
6. **Endurance/general data separation** (`is_fuel` predicate; filter plan add/swap to fuel + Feed; keep logging general; pass the existing catalog `product_type` filter).

**P2 — cleanup (low urgency, behind the version gate):**
7. Delete confirmed-dead code (`getFoodsForPhase`/`getElectrolyteFoods`, orphaned preference screens).
8. Migrate `foods`-table essentials → `template_foods`, then retire `foods`.
9. DB table renames (`*_workout_templates`→`*_workout_formulas`, `template_foods`→`food_catalog`) gated behind a min-version bump.

**Do NOT touch:** `to_exclude_from_solver`, `is_deleted` (load-bearing).

---

## 8. Open decisions

- Safety-net auto-pin: **ephemeral** (recommended) vs persist-real-pins.
- Build start point: centerpiece (#1 selector + safety net) vs a lower-risk contained piece first (#5 preference rip-out or #6 data separation).

All P0/P1 changes land on the **primary, deployed** `generate-nutrition-plan-v3` — build dev-first, verify before prod.
