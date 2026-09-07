# Landing notes — daily-macros-dashboard@v3 (for `land-bundle`)

Prepared 2026-08-19 by the app-side coding agent, at Xuan's direction, after the Phase-C dev
deploy. This file is the input the skill asks for: the target, the Step-2b attestation with its
evidence, and the landing parameters. Deploy playbook: `ops/docs/supabase-deploy-playbook.md` §7;
brief: app `docs/ssot/intake/2026-08-19-phase-c-deploy-brief.md`.

## Target
- **Bundle tag:** `daily-macros-dashboard@v3` (commit `180658d`). `@v2` must NOT land — RED by
  design (its `g1` / `two-time-mark-done` still say `= now`).
- **App implementation:** branch `feature/daily-macro-dashboard-redesign` @ `ca183ab1` (pushed).
- **App trunk:** `develop` (confirmed by Xuan; `main` is stale/CI-only).
- **Do NOT delete the app branch after landing** — the prod hand-off (playbook §7 steps 7–11)
  still references it; retire it after prod ships. QA's `qa/daily-macros` may be retired as usual.

## Step 2b — live-verified on dev: **YES** (2026-08-19, Xuan + app agent, together)
Dev project `vlmtsdzpnjnavdgytcmi`. Evidence:

1. **Schema live** (applied via `supabase db query --linked`, one file at a time):
   `activities.planned_time` / `actual_time` = `timestamp without time zone`;
   `activity_status_enum` contains `deleted`; `public.plan_recalc_log` exists, RLS on, 0 policies,
   pk + 2 indexes. REST probe for `planned_time` stopped returning 42703.
2. **Functions live:** `calculate-daily-macros-v6` v1 (deployed source downloaded and diffed
   byte-identical to the branch; emits `algorithm_version: v6.0.0`); `garmin-push` v57,
   `garmin-ping` v48, `sync-all-data` v54. The frozen legacy `calculate-daily-macros` (v5)
   untouched at v33, still serving pre-v6 installs; its folder carries a FROZEN marker and the
   deploy wrappers refuse it without `--force-legacy`.
3. **Integration:** 29/29 env-gated tests (`index.integration.test.ts`) against the deployed
   `-v6`; live v5-vs-v6 contrast confirmed (v5: carb 404 g, HARD_WARNING; v6: carb 587 g, 30 %E
   fat cap, `energy_basis` present).
4. **Patrol flow PASSED with the remote half EXECUTING** (first time; it self-skipped while dev
   was un-migrated): after a real on-sim skip, the Supabase row carries `status='skipped'`,
   `planned_time` round-tripped INTACT, `actual_time` null, and `needs_upload` cleared; the
   cleanup tombstone (`status='deleted'`) verified server-side.
5. **Defect found and fixed during verification** (the reason dev-before-landing exists): the
   migration's first cut used `timestamptz`, shifting naive-local uploads by the UTC offset
   (16:31 → 11:31, caught by the flow's planned_time-immutability assert). Fixed at all three
   layers — dev columns ALTERed (`USING … AT TIME ZONE 'UTC'` recovered the stored values), the
   migration file corrected in place BEFORE prod ever runs it, and
   `buildGarminCompletionUpdate` now writes `actual_time` naive-local (garmin functions
   redeployed). App commits `25a6a7e3`, `ca183ab1`.
6. dev `app_config`: `current_schema_version` / `latest_schema_version` → 18; `min_*` untouched
   (Lee's ruling).
7. Nothing prod was touched.

## Gate expectations (so a mismatch is investigated, not worked around)
- `./conformance/run_dart.sh <slice>` for all 13 manifest slices: **13/13 PASS** as of app
  `ca183ab1` / qa `6ab2205` (the engine arm points at `calculate-daily-macros-v6/`).
- Graph check `git diff daily-macros-dashboard@v3 HEAD -- spec/ vectors/` on qa: **empty** — the
  post-tag commits (`b5afbc4`…`6ab2205` + this file) touch handoff/runner/test-plan/skill docs
  only, never `spec/` or `vectors/`.
- App merge message must reference `daily-macros-dashboard@v3`.

## After landing
Prod (playbook §7 steps 7–11) is a separate, later hand-off run by Xuan: schema → functions
(`deploy_prod.sh`, incl. `calculate-daily-macros-v6`, never the frozen name) → store build →
`app_config` 18 + `min_supported_schema_version` 17 window → athlete comms. Do not prepare it as
part of the landing.
