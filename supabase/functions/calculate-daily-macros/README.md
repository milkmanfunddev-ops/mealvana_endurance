# calculate-daily-macros — LEGACY v5 (FROZEN)

**Do not edit. Do not deploy except to roll back.**

This folder is a frozen snapshot of the daily-macro engine as it is **deployed under this name**
(algorithm_version `v5.0.0`, restored from `origin/develop` on 2026-08-19). It stays deployed for
installs whose client pins `_expectedAlgorithmVersion = 'v5.0.0'` and discards cached days on a
mismatch — overwriting it with a newer engine would send every one of those installs into a
discard → recalc → discard loop.

- The live engine is **`../calculate-daily-macros-v6/`** (ratified `daily-macros-dashboard@v3`,
  emits `v6.0.0`); the schema-18 app build calls `calculate-daily-macros-v6`.
- The empty `FROZEN` marker makes `scripts/deploy_dev.sh` / `deploy_prod.sh` refuse this folder
  unless `--force-legacy` is passed (rollback only).
- Its tests were moved to `_archived/supabase/functions/calculate-daily-macros/` so the Deno runner
  does not keep re-testing the superseded engine.
- **Delete this folder and the deployed function together** once `min_supported_schema_version ≥ 18`
  (old clients forced off) — same cleanup as `generate-macros` v1–v3.

Ruling: Lee, 2026-08-19 ("new edge function, version in the name; old installs are fine in
perpetuity"); shape: Xuan, 2026-08-19 (`ops/docs/supabase-deploy-playbook.md` §6 A, §7 row 4).
