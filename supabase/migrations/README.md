# Supabase migrations — how this repo actually works

> **Read this before touching anything in `supabase/migrations/`.**
> (Replaces an older README that described a `db push` / GitHub-Actions flow we
> no longer use.)

## We apply schema by hand, not with `supabase db push`

Schema changes are applied to dev and prod by **pasting SQL into DataGrip**.
We do **not** run `supabase db push`. The `.sql` files here are a **historical
record / source-of-truth for review**, not an automated pipeline.

**The one file you actually run is `docs/database/apply_all.sql`** — it holds
whatever schema is currently outstanding, written idempotently
(`CREATE ... IF NOT EXISTS`, `DROP ... IF EXISTS`, guarded `UPDATE`s) so it's
safe to re-run.

When you make a schema change:
1. Put the idempotent SQL into `docs/database/apply_all.sql`.
2. Paste `apply_all.sql` into DataGrip against **dev** and **prod**.
3. Save a dated copy as a `.sql` file in **`_archived/`** for the record, and
   clear `apply_all.sql` for the next change.

## Folder layout

Loose, timestamped `.sql` files in this folder are **allowed** — they are the
outstanding (not-yet-applied-everywhere) migrations, written idempotently and
applied by hand, one file at a time, in DataGrip (▶ Lee, 2026-08-19: *"a
migration file is an SQL file… it's fine to put it in `supabase/migrations`";
*"even just directly executing the SQL is fine"* — apply-all and loose files
are both acceptable; neither is more disciplined in a way that matters).
Once a file is applied to **dev and prod**, move it to `_archived/` and, if it
was also mirrored into `docs/database/apply_all.sql`, replace that section with
an "✅ APPLIED" note.

| Path | Meaning |
|------|---------|
| `*.sql` (loose) | Outstanding migrations, idempotent, hand-applied. Today: `20260814120000_activities_two_time_and_tombstone.sql`, `20260814121000_plan_recalc_log.sql` (daily-macros-dashboard bundle). |
| `_archived/` | Every migration file we've ever written, in one place — applied migrations, data-seed migrations, the disabled pre-Oct-2025 base-schema attempts (`.sql.skip`), and a couple drafted-but-never-applied ones. We don't run these directly. |

## ⚠️ `supabase db push` will fail (issue #29)

The dev project's `supabase_migrations.schema_migrations` table contains ~49
timestamps from **before** the early migrations were moved into `_archived/` —
those timestamps have no matching file anymore. So `supabase db push` aborts
with *"Remote migration versions not found in local migrations directory."*

If you ever need `db push` to work again, pick one:
- `supabase migration repair --status applied <timestamp>` for each of the ~49
  phantom timestamps (marks them applied without running SQL), **or**
- backfill the missing `.sql` files from git history / `_archived/`, **or**
- keep using the DataGrip workflow and don't run `db push` at all (current
  approach).

This mismatch does **not** affect dev/prod data — both DBs are correct; only the
CLI's migration-history comparison is out of sync.
