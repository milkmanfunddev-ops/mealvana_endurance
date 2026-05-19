# Formula Kit — Implementation Plan

> **Branch:** all work lands on a new branch — `feat/formula-kit`, branched from `origin/develop`. We'll create and switch to it as the first step on plan acceptance.

## Status — 2026-05-16

**PR 1 (V1 Browse + Detail) — code complete (incl. pre_workout_templates fix), ready for final commit + PR.**

Already committed on `feat/formula-kit`:
- `463cdbc` docs(formula-kit): add implementation plan
- `14adfa5` feat(formula-kit): browse data layer + library screen (PR 1 partial)
  - Drift mirror of `during_workout_templates` + schema bump v7→v8
  - `DuringWorkoutTemplatesRepository` with on-demand sync + dep-graph wiring
  - Domain: `FormulaFilterState`, `FormulaPhase`, `BeforeSubPhase`, `DuringActivity`/`Duration`/`GutLevel`, `FormulaDigestionSpeed`, `BeforeFormulaView`, `DuringFormulaView`
  - `FormulaLibraryController` (@riverpod AsyncNotifier) with full filter mutations + analytics tracking
  - `FormulaLibraryScreen` with phase tabs, per-phase filter chip rows, list cards, empty states

Uncommitted, ready to land as the PR 1 finishing commit:
- **Before-phase table fix:** switched from legacy `templates` (filtered by `phase='before'`) to `pre_workout_templates` — the actual canonical Before-formula table (29 rows, per-serving macros + serving range).
  - New `lib/shared/database/tables/pre_workout_templates_table.dart` mirroring the 24-column Supabase schema
  - New `lib/features/formula_kit/data/pre_workout_templates_repository.dart` with `SyncableRepository` mixin + on-demand sync
  - Schema bump v8→v9 with `onUpgrade` create-table guard
  - `sync_dependency_graph` entry: `pre_workout_templates` has no deps (component_food_names is a denormalized array, not an FK)
  - `BeforeSubPhase.fromTimeWindow()` derives Meal/Snack/Top-up from `time_window` (no `meal_type` column on this table)
  - `FormulaLibraryController._mapBefore()` rewritten: aggregates `*_per_serving × max_servings` for totals, lowercases `digestion_speed`, reads `component_food_names` ARRAY directly
- `presentation/screens/formula_detail_screen.dart` — read-only Before/During detail
- `lib/shared/core/app_router.dart` — `/settings/food-preferences/formula-library` + `before/:id` + `during/:id` subroutes
- `lib/features/settings/presentation/screens/food_preferences_hub_screen.dart` — 4th tile (flask icon)
- `test/features/formula_kit/` — 22 passing unit tests on filter state + state filtering logic + new `fromTimeWindow` test
- `scripts/run_dev.sh` — convenience runner (see "Dev runner" note below)
- `lib/shared/services/analytics/analytics_tracker.dart` — dev-only debug echo of analytics events

Verification done:
- `dart run build_runner build` clean (0 errors)
- `flutter analyze lib` clean
- `flutter test test/features/formula_kit/` — 22/22 passing
- Manual smoke test on iPhone 17 simulator (pre-table-fix): entry tile renders, library opens, phase tabs + chips filter correctly, detail screen renders for both phases. ✅ — re-smoke after switching to `pre_workout_templates` once the simulator picks up the schema bump.

### Cross-cutting improvements landed during PR 1

These are independent of Formula Kit but were uncovered while smoke-testing it:

1. **`scripts/run_dev.sh`** — `flutter run --flavor dev` alone uses the dev iOS xcconfig BUT defaults to `lib/main.dart`, which loads `.env.prod.local` — so analytics events go to **production** Mixpanel even though the bundle says "dev". The script forces `--target lib/main_dev.dart` so the dev entry point (and `.env.dev.local`) wins. VSCode's `launch.json` was already correct; this brings the terminal experience to parity.
2. **Dev-only analytics debug log** — `MixpanelAnalyticsTracker.track()` now `_logger.info`s `📊 <event_name>` with the properties payload when `config.devModeEnabled` is true. Stripped in prod. Lets us verify event firing without depending on Mixpanel dashboard access.

### Dev Mixpanel project — open question

The dev Mixpanel token (`df6e8dd4f3dc1363fa194a156298b16c` in `.env.dev.local`) is not surfacing events on any Mixpanel board Sunshine has access to. Could be: (a) token belongs to a project that was deleted, (b) project exists but Sunshine doesn't have viewer access, (c) project was never created. Not blocking PR 1 — the debug log gives parallel observability. Worth investigating before we start relying on dev Mixpanel for funnel work in PR 4+.

## Context

**What this is.** Formula Kit is a new UI surface for browsing, personalizing, and creating "formulas" (nutrition templates) for the Before and During phases of endurance workouts. It's been prototyped in HTML/React on [claude.ai/design](https://claude.ai/design) across 5 iteration chats and ships as a 5,657-line standalone HTML prototype + bundle of `.jsx` source files. We need to recreate it in the Flutter app pixel-perfectly while wiring it to real backend infrastructure.

**Why it's being built.** Today, Mealvana has a sophisticated template *backend* (pre/during/post-workout templates in Supabase, mirrored to Drift) but no user-facing browse/personalize UI for templates. Templates are applied silently inside `client_plan_service._tryTemplateBasedBefore()` during plan generation. Athletes can't see the catalog, can't pick from it, can't tweak a template, and can't save personal variants. Formula Kit fills that gap.

**Intended outcome.** Athletes can (a) browse the system formula library on Before/During tabs with filters; (b) tap a template to see its breakdown; (c) "Make this mine" to fork it with quantity tweaks, swaps, removals, and AI coach guidance; (d) create personal formulas from scratch; (e) favorite formulas; (f) have all of this persist locally and sync to Supabase like every other Mealvana entity.

## Source material

- **Design bundle:** `/tmp/formula-kit/formula-library-remix-remix/`
  - `README.md` — design handoff guide
  - `chats/chat1-5.md` — five chat transcripts capturing intent and iteration
  - `project/Formula Kit.html` — primary file (standalone offline bundle, the user had this open at handoff)
  - `project/*.jsx` — modular source (app, browser, detail, edit, create, swap, insight, ui, data, tweaks-panel)
  - `project/colors_and_type.css` — Mealvana design tokens
  - `project/screenshots/` — V3 state references
- **Design system reference:** Mealvana Endurance design system at `/projects/c4ad6c0d-189d-4886-888d-d30addf0dfcf/` (referenced in chats but already encoded in current Flutter app)

## Entry point (decided)

**Settings → Food Preferences → Formula Library** (new 4th tile on the Food Preferences Hub).

- Lives at: `lib/features/settings/presentation/screens/food_preferences_hub_screen.dart` — add a new `_buildFormulaLibraryTile()` next to the existing 3 tiles (Dietary Preference, Allergies, Food Likes & Dislikes).
- Route: add `/settings/food-preferences/formula-library` (and its sub-routes for detail + create) to the router config.
- Implication: Formula Kit is treated as a **preferences/configuration surface**, not an inline workout planner. Athletes go there to *manage* their formulas, not to *pick one for today's workout*. This shapes the answer to the two remaining product questions below.

## Plan integration (recommended, given entry point)

**Browse-only for PR 1–5. Defer "user pick overrides silent picker" to V4.**

Reasoning: because the entry point sits under Settings, the user mental model is "this is where I manage my preferences" — not "this is where I pick what I'll eat in 2 hours." So:
- PR 1–5 build the browse + personalize + favorite + create experience as a standalone settings surface.
- `client_plan_service._tryTemplateBasedBefore()` continues to silently pick from the system catalog *plus* the user's personal_formulas (treat them as additional candidates), but doesn't yet honor a "user selected this specific one" signal.
- V4 (out of scope for this work) can add a Formula picker into the New Activity flow that explicitly says "use this formula for this workout."

This keeps PR 1 small and decouples Formula Kit from the plan-generation algorithm.

## PR 1 scope (recommended)

**Just V1 — browse + detail, no personalization. Ships visible — no feature flag on the Food Preferences Hub entry point.** Browse-only delivers sufficient value on its own with the existing template catalog.

- Adds the Formula Library tile to Food Preferences Hub.
- New `formula_library_screen.dart` with phase tabs, filter chips, collapsible header on scroll.
- New `formula_detail_screen.dart` (read-only, no "Make this mine" yet).
- New Drift mirror of `during_workout_templates` + `post_workout_templates` (read-only sync).
- No new Supabase migrations (everything browsed is already on develop).
- No edit state, no personal formulas, no swap, no create, no favorites.

This is shippable in ~1-2 days of focused work, immediately useful to athletes (they can finally *see* the catalog), and zero risk to plan generation. PR 2+ add personalization on top.

## Branching strategy

**Recommendation: branch `feat/formula-kit` off `origin/develop`.**

Rationale:
- `develop` is the active integration branch (~60 commits ahead of `main`). Recent feature branches (`feat/macro-iter5-garmin`, `feature/garmin-brand-compliance`) merged here, not into main.
- Formula Kit depends on `during_workout_templates` and `template_foods` tables that exist **only on `develop`** via migrations `20260406320000_during_workout_templates_complete.sql` and dependencies. Branching off `main` would mean reimplementing or backporting those migrations.
- The pre_workout_templates table is already on main; the pending vegan/GF migration (`20260506100100_add_vegan_gf_pre_workout_templates.sql`) is on develop too.

```bash
git fetch origin
git checkout -b feat/formula-kit origin/develop
```

**Do NOT branch off:**
- `main` — missing during/post-workout template tables.
- `feat/patrol-integration-tests` — massive divergence, mid-flight test infrastructure work.
- `fix/preworkout-bundle-may2026` (current branch) — that's a small bugfix branch on its own trajectory.

## Scope (recommended phasing)

Formula Kit shipped across **5 iterations** in design. Recommend shipping the same way in Flutter — each iteration is a mergeable PR that adds a coherent slice. Don't try to land the whole thing at once.

| PR | Slice | Approx scope |
|----|-------|--------------|
| **PR 1** | V1 Browse + Detail (read-only) | Library screen, phase tabs, filter chips, collapsible header, detail view with components. No personalization. |
| **PR 2** | V3 iter 1 — "Make this mine" edit state (Before only) | Edit-state UI on Before detail, quantity stepper, placeholder swap sheet, real-time macro recompute. |
| **PR 3** | V3 iter 2 — Real Swap sheet + Your formulas + persistence + During edit + **legacy personal_templates UI deprecation** | Wires up real swap sheet (reusing existing `swap_food_screen` patterns), adds Your Formulas section, Drift+Supabase persistence via the **evolved `personal_templates` table** (see schema section), During edit variant. Also removes the old "My Templates" UI entry points from Settings (the data backbone is the same table — just the UI gets retired). |
| **PR 4** | Coach insight + Add Food | AI-coach guidance panel (calls Claude API via multi-mode edge function — see Coach Insight section), Add Food button in edit state. |
| **PR 5** | Create-from-scratch flow + Favorites | New formula from blank, "+ New" entry on Your Formulas, star toggle on cards, "Favorites only" filter. Final polish (during-card descriptors). |

PR 1 is shippable on its own — it provides immediate user value (browse the existing catalog) before any personalization lands.

## Architecture

### New Flutter feature module

```
lib/features/formula_kit/
├── application/
│   ├── formula_library_controller.dart        # @riverpod AsyncNotifier — browses system + personal
│   ├── formula_personalizer_controller.dart   # edit/create draft state machine
│   ├── formula_swap_controller.dart           # wraps existing swap_food infrastructure
│   ├── coach_insight_service.dart             # calls ai-coach edge function
│   └── favorites_controller.dart              # @riverpod AsyncNotifier
├── data/
│   ├── personal_formulas_repository.dart      # thin wrapper around evolved personal_templates_repository — filters/writes only formula-provenance rows
│   ├── custom_foods_repository.dart           # offline-first writes to CustomFoodsTable, identical sync pattern to personal_templates
│   ├── favorites_repository.dart              # local-only Drift (per design — no Supabase sync in V1)
│   └── ai_coach_client.dart                   # remote-only edge function client (mode: 'insight' for now)
├── domain/
│   ├── personal_formula.dart                  # value type — provenance: forked | from_scratch (filters from personal_templates rows)
│   ├── custom_food.dart
│   ├── coach_insight.dart                     # { insight, staleMarker }
│   └── formula_filter_state.dart
└── presentation/
    ├── screens/
    │   ├── formula_library_screen.dart        # browser (phase tabs + filter chips + collapsible header)
    │   ├── formula_detail_screen.dart         # read + edit state (single screen, state-driven)
    │   └── formula_create_screen.dart         # create-from-scratch (full-screen)
    └── widgets/
        ├── phase_tab_bar.dart
        ├── formula_card.dart                  # system + personal variants
        ├── filter_chip_row.dart
        ├── more_filters_sheet.dart
        ├── collapsible_header.dart
        ├── components_panel.dart              # read + edit (with stepper, swap, remove)
        ├── macros_panel.dart                  # live-updating
        ├── coach_insight_panel.dart
        ├── add_food_button.dart
        ├── delete_confirmation.dart
        └── favorite_star.dart
```

### Drift schema additions

```
lib/shared/database/tables/
├── personal_templates_table.dart         # EVOLVE — already exists; add formula-kit columns (see below)
├── custom_foods_table.dart               # NEW — mirrors mealvana.kit.custom_foods
├── favorites_table.dart                  # NEW — mirrors mealvana.kit.favorites
├── during_workout_templates_table.dart   # NEW — sync from existing Supabase table
└── post_workout_templates_table.dart     # NEW — sync from existing Supabase table (for later After-phase work)
```

**Personal templates table evolution (not a parallel table).** The existing `personal_templates_table` already stores user-owned saved nutrition plans with offline-first sync. Rather than create a parallel `personal_formulas` table, evolve this one to serve both legacy "saved plan" rows and new Formula Kit rows. Columns to add:

- `provenance` — enum: `legacy_plan` | `forked_formula` | `from_scratch_formula` (default `legacy_plan` for backfill)
- `phase` — enum: `before` | `during` | nullable (only meaningful for formula rows; null for legacy plans)
- `source_template_id` — nullable foreign-key-style reference to `pre_workout_templates.id` or `during_workout_templates.id` (only set when `provenance = forked_formula`)
- `sub_phase` — nullable, mirrors design's Meal / Snack / Top-up for Before formulas
- `digest_speed` — nullable
- `activities` — nullable JSON array (During only)
- `durations` — nullable JSON array (During only)
- `gut_training` — nullable (During only)
- `custom_food_ids` — nullable JSON array (links to `custom_foods` rows used as components)
- `is_pinned_to_workout` — bool, defaults false (reserved for V4 "use this formula for this workout" feature — not used by V1–V5, but the column avoids a future migration)

Old `personal_templates` UI surface continues to work unchanged during PR 2 — the backfill maps every existing row to `provenance = legacy_plan` so nothing breaks. Legacy UI entry points removed in PR 3.

The design prototype uses `localStorage` for `mealvana.kit.favorites`. In Flutter, favorites stay Drift-only initially (per design — no cross-device sync needed for V1); `personal_templates` (now the formulas backbone) and `custom_foods` sync to Supabase.

### Sync + conflict resolution

Match the existing pattern in `lib/features/personal_templates/data/personal_templates_repository.dart` (`_upsertRemoteTemplatesPreservingDirty`):

- Local writes set `needs_upload = true` and are pushed to Supabase by the existing sync orchestrator.
- On `syncFromRemote`, rows where the local copy has `needs_upload = true` are skipped — local changes are preserved until pushed.
- Otherwise, remote rows upsert over local. Effectively **last-write-wins between users, with local-dirty-protection during the push window.** No vector clocks, no merge.
- `updated_at` is set server-side on insert/update via trigger (existing pattern — confirm in the migration).
- `custom_foods` follows the identical pattern: same `needs_upload` flag, same dirty-preserving upsert.

State this conflict policy explicitly in the new `custom_foods_repository.dart` doc comment so the next engineer doesn't have to spelunk.

### Supabase additions

```
supabase/migrations/
├── 2026MMDDhhmmss_personal_templates_formula_kit_columns.sql   # ALTER TABLE — add columns + backfill
├── 2026MMDDhhmmss_custom_foods.sql                              # user-owned, RLS scoped to owner
├── 2026MMDDhhmmss_llm_usage.sql                                 # token usage log (see Coach Insight section)
└── (favorites stays Drift-only for V1)

supabase/functions/
└── ai-coach/                                                     # NEW multi-mode edge function (insight, chat-future)
```

The migration:
1. Adds the new columns described above to `personal_templates`.
2. Backfills every existing row with `provenance = 'legacy_plan'`, `phase = NULL`.
3. Adds CHECK constraint validating provenance + phase combinations (e.g., `forked_formula` requires `phase NOT NULL` and `source_template_id NOT NULL`).
4. Keeps existing RLS policy unchanged — user-owned, scoped via `user_id`.

### Reused components (do not rebuild)

- **Swap sheet pattern** — `lib/features/nutrition_plan/presentation/screens/swap_food_screen.dart` is the existing source-of-truth for IMG_7922's pattern. Refactor it so Formula Kit can call into the same sheet (with mode=`swap` | `add_food`) rather than building a parallel sheet. If refactor scope is too big in PR 3, build a feature-local sheet and unify later.
- **Templates repository** — `lib/features/nutrition_plan/data/templates_repository.dart` already reads pre_workout_templates from Drift with on-demand sync. Extend (don't replace) to add during_workout_templates.
- **Personal templates pattern** — `lib/features/personal_templates/` has the precedent for user-owned templates that sync to Supabase. Follow the same offline-first + `needsUpload` flag pattern.
- **Food preferences** — `lib/features/food_preferences/` for allergen + dietary filters in More Filters sheet. The filter state must respect the same `excluded_diets`/`allergens` schema that templates already encode.
- **MealvanaSnackbar** — for "Created in Your formulas." / "Swap [component]" toasts. Never raw Flutter SnackBar (per CLAUDE.md).
- **AsyncNotifier + AsyncValue.guard** — every controller, per FOA rules.

### AI coach — multi-mode edge function (`ai-coach`)

The design uses Claude to generate ~15-28 word coach-tone guidance based on current draft macros. Build as a **multi-mode edge function** so the same function can serve future surfaces (MealBuddy chat, etc.) without restructuring.

**Envelope** (request shape):
```jsonc
{
  "mode": "insight",                    // "insight" today; "chat" reserved for MealBuddy
  "context": { /* mode-specific structured payload */ },
  "tools": []                           // empty for insight; reserved for chat tool-calling
}
```

**Coach insight uses pre-computed structured context injection — NOT live tool calling.** All algorithmic outputs (solid:liquid ratio, fiber load, estimated digestion speed, etc.) are computed *inside the edge function* before the LLM call, and injected into the prompt as a structured nutrition state block. The LLM never makes tool calls in `insight` mode. Tool-calling support stays in the envelope (the `tools` array) for future `chat` mode but is unused in PR 4.

**Edge function responsibilities for `mode: "insight"`:**
1. Receive draft components (food id + quantity) + phase + workout duration + user dietary context.
2. **Compute** structured nutrition state:
   - Total carbs / protein / fat / sodium / fluid (sum from `template_foods.*` per quantity)
   - Solid:liquid ratio (g of solid food : mL of fluid)
   - Fiber load (g, summed from food catalog)
   - Estimated digestion speed (derived from `template_foods.digestion_speed` weighted by quantity)
   - Sub-phase fit indicator (does the load match the selected Meal / Snack / Top-up?)
3. Build prompt with system message + structured state block + minimal user message.
4. Call `claude-haiku-4-5-20251001` (latency-sensitive, low-stakes content, cheap).
5. Log token usage to `llm_usage` table (see below).
6. Return `{ "insight": "<15-28 word string>", "stale_marker": "<hash of components>" }`.

**No per-user rate limiting** — Foundational metrics first, abuse protection later. If a user generates thousands of insights, that shows up in `llm_usage`.

**Token usage log (`llm_usage` table):**
```
id | user_id | function | mode | model | input_tokens | output_tokens | cost_usd | created_at
```
- Inserted on every successful LLM call across all future edge functions (foundational metrics, not Formula Kit-specific).
- Index on `(user_id, created_at)` for per-user cost queries.
- Index on `(model, created_at)` for cost-by-model reporting.
- Indexed for analytics SQL but no Supabase realtime / no app-side reads — write-only from edge functions.

### PR 4 prerequisite — coach insight prompt template

Before PR 4 implementation, ship this prompt design (it's part of PR 4's scope but called out as a prerequisite for clarity):

**System prompt (draft):**
```
You are a coach for endurance athletes using the Mealvana Endurance app.
You review a draft nutrition formula and give one short, direct piece of
guidance. Voice: athlete-to-athlete, no fluff, no wellness-influencer tone,
grounded in science. Output 15-28 words, one or two sentences. End with a
period, not an exclamation point. Never use emoji. Reference specific
numbers from the structured state when relevant.

If the formula is well-balanced for its phase and sub-phase, say so plainly.
If something is off — too low sodium for the duration, too much fiber for a
"top-up", solid:liquid skewed for during-workout — name the issue and one
concrete fix ("consider adding a pinch of salt to the oatmeal").
```

**User message template (draft):**
```
PHASE: {before | during}
SUB_PHASE: {meal | snack | top_up}    (before only)
WORKOUT_DURATION_MIN: {n}              (during only)

DRAFT COMPONENTS:
- {food_name}: {quantity} {unit}
- ...

COMPUTED MACROS:
  carbs:     {n} g
  protein:   {n} g
  fat:       {n} g
  sodium:    {n} mg
  fluid:     {n} mL

DERIVED:
  solid_liquid_ratio:    {n}:1
  fiber_load_g:          {n}
  digestion_speed_est:   {fast | medium | slow}
  sub_phase_fit:         {good | warn | poor}

Give your guidance.
```

**Output shape:**
```json
{ "insight": "string, 15-28 words", "stale_marker": "hash" }
```

Client caches `(stale_marker, insight)` per draft. When any component changes, the new local hash differs from the cached `stale_marker`, the panel goes "Outdated — refresh", and a fresh call is triggered on tap.

## Analytics (Mixpanel)

All events follow the existing convention in the codebase: `controller.trackEvent('snake_case_event_name', { ...payload })`. Inspected precedents: `workout_saved`, `workout_completed`, `swap_food_tapped`, `add_food_tapped`, `workout_saved_with_template` (all in `activity_detail_screen.dart`).

Fire from controllers (FOA: not from screens). Add the events listed below in the PR they're introduced — do not stockpile events ahead of features.

**PR 1 — Browse + Detail:**
| Event | Payload |
|---|---|
| `formula_library_opened` | `{ source: 'food_preferences_hub' }` |
| `formula_phase_switched` | `{ from: 'before' \| 'during', to: 'before' \| 'during' }` |
| `formula_filter_applied` | `{ filter_type: 'diet' \| 'allergen' \| 'sub_phase' \| 'activity' \| 'duration' \| 'gut_training', value: <string>, active_filter_count: <int> }` |
| `formula_detail_viewed` | `{ template_id: <string>, phase: 'before' \| 'during', is_personal: false }` |

**PR 2 — Make this mine (Before):**
| Event | Payload |
|---|---|
| `make_this_mine_tapped` | `{ source_template_id: <string>, phase: 'before' }` |
| `personal_formula_saved` | `{ provenance: 'forked_formula', source_template_id: <string>, phase: 'before', component_count: <int>, edit_duration_sec: <int> }` |
| `personal_formula_edit_cancelled` | `{ source_template_id: <string>, phase: 'before' }` |

**PR 3 — Swap sheet + Your formulas + During edit:**
| Event | Payload |
|---|---|
| `formula_swap_opened` | `{ phase, component_id, source: 'edit' \| 'add_food' }` |
| `formula_swap_completed` | `{ phase, from_food_id, to_food_id, to_food_source: 'system' \| 'my_foods' \| 'created' }` |
| `custom_food_created` | `{ category: 'solid' \| 'gel' \| 'fluid' \| 'drink_mix' \| 'tablet' }` |
| `personal_formula_deleted` | `{ formula_id, phase, provenance }` |
| `personal_formula_saved` | (extend with `phase: 'during'` rows) |

**PR 4 — Coach insight + Add Food:**
| Event | Payload |
|---|---|
| `coach_insight_generated` | `{ phase, mode: 'insight', cached: bool, latency_ms: <int>, input_tokens: <int>, output_tokens: <int> }` |
| `coach_insight_refresh_tapped` | `{ phase }` |
| `add_food_tapped` | `{ phase, draft_component_count: <int> }` (note: name collides with existing nutrition-plan event — qualify with new payload `surface: 'formula_kit'`) |

**PR 5 — Create-from-scratch + Favorites:**
| Event | Payload |
|---|---|
| `formula_created_from_scratch` | `{ phase, sub_phase \| activities, component_count }` |
| `formula_favorited` | `{ formula_id, formula_kind: 'system' \| 'personal', phase, action: 'add' \| 'remove' }` |
| `favorites_only_filter_toggled` | `{ enabled: bool, source: 'header_star' \| 'more_filters' }` |

## Verification

End-to-end test plan, per slice:

**PR 1 (browse):**
- Run `flutter run --flavor dev` on iOS simulator.
- Open Settings → Food Preferences → confirm the new **Formula Library** tile appears as the 4th tile alongside Dietary Preference, Allergies, and Food Likes & Dislikes. Tap it.
- Tap into library, swipe between Before/During tabs, scroll the list, observe collapsed header on scroll.
- Open More Filters, apply diet + allergen filters, confirm list updates.
- Tap a card, see detail with components, hit back.
- Run `flutter test test/features/formula_kit/` (unit + widget tests for filter logic + card rendering).

**PR 2 (Make this mine):**
- On a Before template detail, tap "Make this mine".
- Tweak quantities, watch macros tween. Save. Confirm a Personal formula appears.
- Verify offline-first: enable airplane mode mid-edit, save, re-enable network, confirm sync.

**PR 3 (real swap + persistence + During):**
- Open swap sheet, add a custom food, save. Confirm it appears in My Foods on next open.
- Pull-to-refresh / quit app / relaunch — confirm everything persists from Drift and reconciles with Supabase.
- Verify During edit variant has no quantity stepper (per spec).
- Run integration tests via Patrol (if the patrol branch has merged by then) or via existing integration_test harness.

**PR 4 (insight + add food):**
- Confirm Coach insight panel renders shimmer → returns text from edge function in <2s.
- Test edge function via `supabase functions invoke ai-coach --body '{"mode":"insight","context":{...}}'`.
- Verify `llm_usage` table has a new row with non-zero input/output tokens after each call.
- Add Food button opens swap sheet in add mode; selecting appends component.

**PR 5 (create + favorites):**
- Create from scratch, confirm validation (toasts on muted Save), save, confirm landing on detail.
- Star toggle on every card, persist across relaunch, "favorites only" filter ANDs with phase/diet filters.

## Risks & open questions

1. **Patrol branch widget keys.** PR 1 will land while `feat/patrol-integration-tests` is in flight. If patrol merges first, Formula Kit screens need ValueKeys for the new test suite. Coordinate timing or add keys preemptively.
2. **Custom food deduplication.** If a user creates "Banana 100g" custom food and we already have a system "Banana" — do they collide? Design defers this. Likely V2 cleanup.
3. **Coach insight cost monitoring.** No per-user rate limiting (intentional — foundational metrics first). Monitor `llm_usage` table for outliers; if any user generates >100 insights/day, that's a signal to revisit. Cost itself is bounded by Haiku pricing × short prompts × short outputs.
4. **PR 2 timing — when do personal formulas need to feed back into plan generation?** Current plan keeps them user-only-visible until V4. The new `is_pinned_to_workout` column on `personal_templates` is wired but unused — V4 can flip it on without another migration.
5. **Migration backfill correctness.** The `provenance = 'legacy_plan'` backfill must run after the column is added but before any client reads the new column. Test on a Supabase branch first.

## Critical files to read before PR 1

- `lib/features/nutrition_plan/application/client_plan/client_plan_service.dart` — to understand how templates are silently applied today.
- `lib/features/nutrition_plan/data/templates_repository.dart` — sync pattern to extend.
- `lib/features/personal_templates/data/personal_templates_repository.dart` — precedent for user-owned + Supabase-synced data.
- `lib/features/nutrition_plan/presentation/screens/swap_food_screen.dart` — what to reuse / refactor for the design's Swap sheet.
- `supabase/migrations/20260406320000_during_workout_templates_complete.sql` — during-template schema (only on develop).
- `/tmp/formula-kit/formula-library-remix-remix/project/Formula Kit.html` — pixel reference for every PR.

## Out of scope (per design)

- After phase (separate work — backend exists, no design)
- AI coach algorithm integration into plan generation (V4 in design)
- Sharing personal formulas with a coach (separate work)
- Importing recipes from external sources
- Photo upload
- Reordering components
- Renaming personal formulas beyond the auto "From [Source]" eyebrow
