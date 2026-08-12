# PROD cutover — pre-workout food-composition v3

**Status: ✅ RUN ON PROD 2026-08-11.** Steps 1–5 executed ~16:20 UTC (verify
passed: 14/10/5, v3 time windows, food_group 79/93, dangling pin cleared).
Step 7 (force-update flip) executed 2026-08-12 03:13 UTC after 1.23.1 went
live on the App Store (released 19:38 UTC): min_app_version → 1.23.1,
current/latest_schema_version → 17, floor kept at 11. The five applied
pre_workout migrations moved to `../_archived/`. Originally verified against
live dev + prod on 2026-08-11.

Prod ref `wvmvsodrvbkxfydabqed` · dev ref `vlmtsdzpnjnavdgytcmi`.

This directory is the runnable half of what `docs/database/apply_all.sql` §6
describes in prose. §6 is a pointer, deliberately unrunnable; these files are
the guard rails that pointer does not carry.

## What is actually out of parity

Structurally, **nothing**. All 54 public tables — column names, types,
nullability, defaults — hash identically on dev and prod, `onboarding_surveys`
included (applied to prod 2026-08-11, ledger `20260811144825`). Drift is
complete too: `schemaVersion 17`, with `sub_phase`, `fiber_per_serving`,
`food_group` and the `onboarding_surveys` table all present.

What differs is **catalog data**:

| | dev | prod |
|---|---|---|
| `pre_workout_templates` | 29 rows — 14 `full_meal` / 10 `snack` / 5 `top_up` | 30 rows — 11 / 11 / 8 |
| `time_window` labels | `2-4 hours`, `30-120 min` | `1.5-3 hours`, `30-90 min` |
| `template_foods.food_group` | populated | **0 of 93 populated** |

## Run order

Everything is idempotent and re-runnable.

| # | file | notes |
|---|---|---|
| 1 | `00_pre_unlock_sub_phase.sql` | this directory |
| 2 | `../20260805120100_pre_workout_food_composition_v3_data.sql` | the structure migration it depends on is **already applied** to prod (ledger `20260810174523`) |
| 3 | `../20260805143000_pre_workout_drop_standalone_g4b_meal_snack.sql` | |
| 4 | `../20260806153000_pre_workout_drop_ingredient_rows.sql` | |
| 5 | `40_post_relock_and_verify.sql` | this directory — hard-fails unless prod lands on dev's 14/10/5 |
| 6 | **ship 1.23.1 to both stores, wait for approval** | |
| 7 | `50_app_config_force_update.sql` | this directory |

## Two things prod does that dev did not

**1. The data migration will abort on prod unless step 1 runs first.**
Prod applied `sub_phase` *before* the v3 data (dev did the reverse), so
`sub_phase` is already `NOT NULL`. The v3 data file was generated 2026-08-05,
a day before that column existed, and its `INSERT` column lists omit it — all
17 inserts would fail `23502 not_null_violation` and roll back. Step 1 drops
the constraint; step 5 backfills and restores it.

**2. Real prod users have data pointing at rows the cutover deletes.**
The migration headers say "zero formula_pins and zero personal_formulas
reference these rows" — true of dev, false of prod. There is no foreign key on
`formula_pins.template_id`, so the deletes orphan silently rather than erroring:

| | row | owner |
|---|---|---|
| `formula_pins` | `Dates + Banana` | `5c25e7b0-c152-449f-a87f-1c77c6133d15` |
| `personal_formulas` | `Electrolyte Drink Mix` | `5f6ff116-3ccd-40ab-9fc6-9568898f8df0` |
| `personal_formulas` | `Bagel + Peanut Butter` | `e92cb452-0368-4bb3-a888-3e86a65d097f` |

Step 5 clears the dangling **pin** (a pin whose template is gone renders an
empty slot the athlete cannot clear). The two `personal_formulas` are left
alone on purpose: they are independent copies, `source_template_id` is
provenance only, and both keep working after their source row disappears.

## Why step 7 is separated by a store release

`min_app_version` is what strands old clients on `ForceUpgradeScreen`, and that
screen's only exit is the store button. Flip it before 1.23.1 is downloadable
and the button offers the *old* build, which installs and is rejected again —
a closed loop with no way out.

Android gates this, not iOS: the prod Android track is Play **open testing**,
which still needs Google review plus a manual "send for review" in the Play
Console (`changes_not_sent_for_review: true` in `codemagic.yaml`). Wait for
"Available to testers".

## After it lands

1. Move the four applied `.sql` files to `supabase/migrations/_archived/`.
2. Replace `docs/database/apply_all.sql` §6 with an
   `✅ APPLIED to DEV + PROD on <date>` note.
3. Re-run the parity check in this README's first table — prod should read
   14 / 10 / 5.
