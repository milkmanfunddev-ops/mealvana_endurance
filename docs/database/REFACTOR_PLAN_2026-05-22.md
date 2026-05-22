# DB Cleanup Plan — 2026-05-22

A **conservative** cleanup, scoped after discussion with Lee. This supersedes the
template-merge ambition in `AUDIT_REPORT_2026-05-14.md` (#7) with a smaller,
lower-risk plan.

## Guiding principles (non-negotiable)

1. **Don't break old clients.** Shipped app binaries and the live `v3` edge
   function read table/function names as hardcoded strings. We never delete
   anything server-side (edge function, table, column) on a code reading alone.
2. **No forced upgrades** for cleanliness. Old stuff ages out as the
   `min_app_version` floor rises with normal releases.
3. **Retire by evidence, not by code search.** A server thing is removed only
   after invocation/traffic metrics show it's unused (or its callers are below
   the supported app-version floor).
4. **No views.** (Lee's call — keep it simple.)
5. **Schema is applied by hand via DataGrip**, not `db push`. Every schema
   change ships as idempotent SQL. The single file to run is
   `docs/database/apply_all.sql`. See `supabase/migrations/README.md`.

## Decisions locked

- **Keep 3 template tables** (`pre_workout_templates`, `during_workout_templates`,
  `post_workout_templates`). Do **not** merge into one big null-sprawl table —
  they're already normalized and serve distinct phases.
- **`template_foods`** stays the canonical food catalog. Never merged.
- **`personal_templates`** stays separate (user data); it's being *evolved* for
  Formula Kit PR 4 (additive columns), not merged.
- **Kill exactly one genuine duplicate:** the legacy denormalized `templates`
  table (see "Legacy templates retirement" below) — but carefully, later.

## ✅ Done (verified: 0 analyzer errors, 48/48 formula-kit tests)

- Merged `origin/develop` into `feat/formula-kit`; reconciled the Drift
  schema-version collision (now `schemaVersion = 11`).
- Deleted dead Dart: `llm_nutrition_plan_service.dart`,
  `bulk_nutrition_plan_service.dart` (+`.g.dart`). (Safe — repo-only; shipped
  apps carry their own copy.)
- Fueling-kit bug fixes: removed the dead `FormulaDigestionSpeed.slow` filter
  (DB only has Fast/Medium); fixed analytics `filter_type` to spec
  (`'allergen'`/`'diet'`).
- Made `formula_pins.sql` idempotent; added `personal_templates`
  formula-kit columns (PR 4 prep). **Applied to dev + prod 2026-05-22.**
- Replaced the outdated `supabase/migrations/README.md`.
- **Reverted `custom_foods`** — it duplicated the existing `user_foods` table
  (user-created foods w/ macros, owned + soft-deleted + offline-synced, and
  richer + already wired in). Formula Kit reuses `user_foods`;
  `personal_templates.custom_food_ids` references `user_foods.id`. If formula
  components need allergen/diet/caffeine filtering, add those columns to
  `user_foods` (additive) rather than a parallel table. **Other dev: PR 4's
  `custom_foods` table/repo is dropped — use `user_foods`.**

## Pending schema to apply (DataGrip, dev + prod)

Run **`docs/database/apply_all.sql`** top-to-bottom. Currently:
1. Data-hygiene fixes #27 / #28 (`serving_unit`, "Potato + Salt").
2. `DROP TABLE custom_foods` (+ corrected `custom_food_ids` comment).

All additive/safe for old clients.

## Legacy `templates` retirement (the one real code change — do carefully)

**Goal:** stop using the denormalized `templates` table; freeze it (don't drop —
old clients still read it). Drop only later, by metrics.

**The work is in `client_plan_service._tryTemplateBasedBefore()`**
(`lib/features/nutrition_plan/application/client_plan/client_plan_service.dart:307`).
It currently:
- reads `templates` via `TemplatesRepository.getAllTemplates()`,
- filters on `phase`, `mealType`, `timingMin/MaxMinutes`, `allergens`,
  `excludedDiets`, `foodNames`,
- scales by `totalCarbsG`,
- and **expands `templates.foods` (JSON array of food objects with embedded
  macros + `default_servings`)** into `FoodItemData`.

`pre_workout_templates` has a **different shape**: `component_food_names[]` +
`component_quantities` (name→servings) + template-level per-serving macros +
`time_window` + `min/max_servings`. Migrating means:
- map `targetMealType` → `time_window` (`full_meal`↔`1.5-3 hours`,
  `snack`↔`30-90 min`, `top_up`↔`< 30 min` — logic already exists in
  `BeforeSubPhase.fromTimeWindow`),
- JOIN component names to `template_foods` for per-component macros (the Formula
  Kit browse path already does this — reuse it),
- re-derive scaling from template per-serving macros + `min/max_servings`.

**Risk: HIGH** — this rewrites core client-side Before-phase plan generation.
**Recommendation:** do it as its own focused, test-covered change (run the
pre-workout matrix + algorithm tests before/after and diff outputs). Until then,
`templates` stays in use — it's a harmless duplicate, not an active problem.

## Retire-by-metrics (do NOT delete now)

Confirmed to have no *current-code* callers, but may still be hit by old
binaries. Tag deprecated; delete only after metrics show zero traffic / the
app-version floor passes them:
- Edge functions: `generate-macros`, `generate-macros-v3`,
  `generate-nutrition-plan` (v1), `generate-nutrition-plan-v2`,
  `sync-final-surge`. (Note: `v2` is the last *server-side* reader of legacy
  `templates`.)
- Tables: `feature_survey_responses`, `catalog_sync_runs` (verify with ops).

## Migration / CI cleanup (decision pending)

The "haven't been applied" errors come from CI: `deploy-dev.yml`,
`deploy-prod.yml`, `schema-drift-check.yml` run `supabase db push`/`db diff`,
which fail on issue #29. Options:
- **(A, recommended)** retire those workflows — you deploy schema via DataGrip;
  they only generate failing-run noise. Then tidy the four archive dirs.
- **(B)** repair #29 (`supabase migration repair --status applied <ts>` ×~49) to
  restore automated push.

## Deferred code fixes (tracked, not urgent)

- **`TemplateKind.fromWireValue` crash-safety** — must be made tolerant of
  unknown values **before PR 4** widens `template_kind` to `'personal_template'`,
  or old clients crash reading new pins. (PR 4 prerequisite.)
- **Data hygiene #27** (`template_foods.serving_unit` null → "1 Jam / Jelly")
  and **#28** ("Potato + Salt" lists only potato but shows 300 mg sodium) —
  fix as DataGrip SQL when convenient.

## Explicitly NOT doing

- Merging pre/during/post into one table (null sprawl, lost constraints, big
  edge-function rewrite, frozen-catalog problem — not worth it).
- Forcing app upgrades.
- Creating compatibility views.
