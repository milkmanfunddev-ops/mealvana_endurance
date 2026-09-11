# PROD cutover — meal planning (Vana)

**Status: ⛔ NOT RUN. Prepared and verified against live dev + prod on 2026-09-02.**
**Amended 2026-09-11 (meal imagery):** image gate, stale snapshot, dev-storage URLs; see
"Meal imagery" below.
Prod ref `wvmvsodrvbkxfydabqed` · dev ref `vlmtsdzpnjnavdgytcmi`.

This is Phase 5 of `docs/implement_mealplanning/06-sync-schema-envs.md`, made
runnable. Read the deploy playbook first
(`docs/deployment/supabase-deploy-playbook.md`) — its ordering rules, its
`app_config` window and its standing orders govern this directory.

**Standing order carried over from the pre-workout cutover:** prod
`app_config` is written only at Xuan's explicit direction, in default
(non-auto) permission mode, after the read-only check. `95_` is written to
make that impossible to do by accident.

## What is out of parity

Prod has **none** of the meal-planning objects and still has real `jade_*`
tables. Measured 2026-09-02:

| | dev | prod |
|---|---|---|
| migration ledger head | `20260902090000` | `20260811160003` |
| `meal_library` | 1,922 rows (1,675 assembly / 247 recipe), all embedded, all with `method_steps` | absent |
| `meal_plans` / `plan_meals` / `user_memories` / `meal_feedback` / `user_entitlements` | present | absent |
| chat tables | `vana_*` + `jade_*` compat views | real `jade_*` tables |
| `pgvector` | installed | **not installed** (the first migration creates it) |
| `pg_trgm` | installed | installed |
| `dietary_preference_enum` / `allergy_enum` | 8 / 9 labels | **identical** ✅ |
| `app_config.current/latest_schema_version` | 18 (bump to 20 with the shipping build) | 18 |

## What else this push carries (found 2026-09-02, not in 06)

Prod's ledger stops at `20260811160003`, so `supabase db push` also applies
the two **macro-dashboard** migrations from 2026-08-14. Both are idempotent
and both are needed by 1.24 regardless of meal planning:

- `20260814120000_activities_two_time_and_tombstone.sql` — prod already has
  `activities.deleted_at` but **not** `planned_time` / `actual_time` (applied
  out of band, partially). The `add column if not exists` pair fills the gap.
  Note the column type is `timestamp WITHOUT time zone` on purpose: the
  table's convention is naive local. Do not "fix" it to `timestamptz`.
- `20260814121000_plan_recalc_log.sql` — `plan_recalc_log` **already exists**
  on prod but is absent from the ledger, i.e. it was applied by hand. The
  file is idempotent, so the push records it without changing anything.

Neither is meal planning, but both ride this push. Say so on the cut card.

## The riskiest step, stated plainly

`20260827120000_jade_to_vana.sql` **renames the live chat tables**
`jade_conversations` / `jade_messages` / `jade_calls` → `vana_*` and puts
`security_invoker` views back under the old names. The shipped 1.23.x app
reads `jade_*` and keeps working **only through those views**. So:

- The rename and the view creation are in one migration — never apply half.
- `90_verify.sql` asserts all three `jade_*` names are `relkind = 'v'` and
  that `jade_conversations` is still selectable. If any of those is not true
  after the push, the live app's chat is broken and that is the rollback
  trigger, not a follow-up ticket.
- Do not drop the compat views until `min_app_version` is past 1.23.x.

## Run order

Everything is idempotent and re-runnable.

| # | what | how |
|---|---|---|
| 1 | Pre-check (read-only) | `01_pre_check.sql` — compare with §"Expected pre-check answer" |
| 2 | Apply all pending migrations (13 on 2026-09-02, plus six for meal imagery, see "Meal imagery") | `supabase db push --linked` against prod (relink first), in timestamp order — the CLI does the ordering |
| 3 | Gate the images on dev, re-export the snapshot, seed `meal_library` | `03_image_gate.sql` against **dev** must pass (see "Meal imagery" below). Then, in `~/development/mealplanning-prototype/packages/web`: `node scripts/export_meal_library.mjs --env <dev env file>`, then `node scripts/seed_meal_library.mjs --snapshot data/meal-library.snapshot.json --env <prod env file>` |
| 4 | Refresh the pair view | `select public.refresh_meal_library_pairs();` (service_role) |
| 5 | Verify (read-only) | `03_image_gate.sql` against prod must pass; then `90_verify.sql` — paste the row into the status header above |
| 6 | Deploy edge functions to prod | `/deploy-edge` for `vana-chat`, `vana-action`, `vana-day-notes`, `revenuecat-webhook`, `jade-chat` |
| 7 | Secrets | `PRO_GATE_ENABLED=true` on prod; `VANA_*_MODEL` optional |
| 8 | Smoke | `search_meals` as the QA user excludes their allergens; a `vana_calls` row is written; `jade_conversations` still serves the shipped app |
| 9 | **After the 1.24.x binary is LIVE**, and only at Xuan's direction | `95_app_config_schema_20.sql` |

Step 3 costs ≈1,922 embedding calls through the AI Gateway (~$0.05). The
snapshot carries every column **except** `embedding` and `search_text`
(the script says so at `seed_meal_library.mjs:82`), so the embeddings are
regenerated on prod — there is no way to skip that cost, and `90_verify.sql`
checks `library_embedded = library_rows` precisely because a half-embedded
library still answers `search_meals` (just badly).

## Meal imagery (added 2026-09-11)

The meal-image work (`docs/meal-images/README.md`, `.scratch/meal-imagery/`)
happened after this runbook was written. It changes four things here.

**Six more migrations are pending.** All are applied to dev only, and all are
idempotent. They are `20260909120000_meal_images_schema_and_catalog_paging`,
`20260909170000_meal_image_verdicts`, `20260910140000_meal_image_blocked_reason`,
`20260910180000_meal_dish_photo_sourcing`, `20260910200000_meal_rejected_mosaics`,
`20260911120000_search_meals_photo_source`. The last one redefines
`search_meals` to return `image_source_url`, `image_creator` and
`image_license`, which the app's list de-duplication and card credits read.

**The snapshot is stale.** `data/meal-library.snapshot.json` was exported on
2026-09-01, before any of the imagery work. Seeding from it would ship the old
library: no `image_mode` or `image_tiles`, no verdicts, and the 539 dish photos
the judge later rated wrong. It also has no `image_unlicensed` column, so the
food-blog photographs in it would arrive unflagged and the gate below would
pass without meaning anything. Re-export from dev in step 3, after the gate
passes. The imagery work changed no row's ingredients: `90_verify.sql` on dev
on 2026-09-11 still returned the 2026-09-02 library counts (1,922 rows, 1,922
embedded, 8,106 pairs), so its expected values stand.

**Production gate: no unlicensed pictures.** 30 dev rows (2026-09-11) show a
photograph hotlinked from a food blog with no recorded licence. They are kept
on dev on purpose while the library is a prototype and flagged
`meal_library.image_unlicensed`. They must not reach production.
`03_image_gate.sql` raises while any remain; run it against dev before the
export and against prod after the seed. `90_verify.sql` reports the same count
as `library_unlicensed_images`, and it must be 0.

**Mirrored pictures point at dev storage.** Archive photographs are copied into
the `meal-images` bucket, and every copy so far is in the **dev** project
(`docs/adr/0001-meal-images-mirroring-is-decided-per-provider.md`). The
snapshot copies URLs verbatim, so on 2026-09-11, 506 of the 804 meals showing a
picture would load at least one image from dev storage in production. Before
the seed, either copy the bucket to prod and rewrite the host in
`image_url` and `image_tiles` in the snapshot, or decide explicitly that prod
may read dev's public bucket for now. `90_verify.sql` reports
`library_images_on_dev_storage`; 0 means the bucket was moved. Stock photos
(Unsplash, Pexels) are hotlinked to the provider and need nothing.

## Expected pre-check answer (prod, 2026-09-02)

```
has_pgvector                = false      -- created by migration 1
has_pg_trgm                 = true
diet_enum                   = omnivore,vegetarian,pescatarian,vegan,mediterranean,paleo,keto,low_carb
allergy_enum                = dairy,eggs,fish,gluten,peanuts,sesame,shellfish,soy,tree_nuts
has_vana_conversations      = false
has_meal_library            = false
has_meal_plans              = false
has_plan_meals              = false
has_user_memories           = false
has_user_entitlements       = false
jade_conversations_relkind  = r          -- a TABLE, not yet a view
has_plan_recalc_log         = true       -- out-of-band, see above
activities_two_time_cols    = 0
current/latest_schema_version = 18
min_supported_schema_version  = 11
```

Anything else means prod moved after 2026-09-02: re-derive the runbook
rather than pushing through it.

## Rollback

The DDL is additive apart from the `jade_* → vana_*` rename, and that rename
is covered by the compat views. So the rollback is not "undo the migrations"
— it is:

1. If the views are missing or broken → recreate them immediately
   (the three `create or replace view … security_invoker` statements at the
   foot of `20260827120000`). That restores the shipped app.
2. Leave the new tables in place; they are empty and unreferenced by any
   released binary. The Food tab is dark on prod until `PRO_GATE_ENABLED`
   and an entitlement say otherwise.
3. Do **not** roll `app_config` forward if you are rolling anything back.

> **2026-09-03 addendum (plan Phase 3):** the bundle also carries
> `supabase/migrations/20260903120000_meal_planning_relationship_loop.sql` — `meal_plans.checkin_done_at`,
> `meal_plans.debrief_done_at` and the `plan_debriefs` table (RLS owner policy). Server-only columns; no Drift bump.
> Applied to DEV by hand on 2026-09-03 (Management API — `db push` is still blocked by the phantom-history rows).
