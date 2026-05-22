# Supabase migrations — how this repo actually works

> **Read this before touching anything in `supabase/migrations/`.**
> (Replaces an older README that described a `db push` / GitHub-Actions flow we
> no longer use.)

## We apply schema by hand, not with `supabase db push`

Schema changes are applied to dev and prod by **pasting SQL into DataGrip**.
We do **not** run `supabase db push` as part of the normal workflow. The `.sql`
files here are a **historical record / source-of-truth for review**, not an
automated pipeline.

When you make a schema change:
1. Write the SQL as an idempotent `.sql` file in this folder (use
   `IF NOT EXISTS`, `DROP ... IF EXISTS`, etc. so it's safe to re-run).
2. Paste it into DataGrip against **dev** and **prod**.
3. Track what's pending in `docs/database/formula_kit_sql_to_apply.md` (or a
   similar per-feature "SQL to apply" doc).

## Folder layout

| Folder | Meaning |
|--------|---------|
| `*.sql` (root) | **Pending** changes not yet applied. Paste into DataGrip (dev + prod), then move the file into `_archived/`. (Currently none — all applied.) |
| `_archived/` | Every historical migration, in one place: applied migrations, former data-seed migrations, the disabled pre-Oct-2025 base-schema attempts (`.sql.skip`), and the two `20250114_expand_category_enum*` files that were drafted but never applied. |

## ⚠️ `supabase db push` will fail (issue #29)

The dev project's `supabase_migrations.schema_migrations` table contains ~49
timestamps from **before** the early migrations were moved into `_archived/` —
those timestamps have no matching file in the root folder anymore. So
`supabase db push` aborts with *"Remote migration versions not found in local
migrations directory."*

If you ever need `db push` to work again, pick one:
- `supabase migration repair --status applied <timestamp>` for each of the ~49
  phantom timestamps (marks them applied without running SQL), **or**
- backfill the missing `.sql` files from git history / `_archived/`, **or**
- keep using the DataGrip workflow and don't run `db push` at all (current
  approach).

This mismatch does **not** affect dev/prod data — both DBs are correct; only the
CLI's migration-history comparison is out of sync.
