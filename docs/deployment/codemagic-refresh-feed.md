# Codemagic scheduled feed refresh — ready-to-activate setup

Schedules the **deterministic feed routine** (B0 non-destructive import + B1
removed-deactivation + B2 classify-new) to run weekly on Codemagic, dev then prod.
Codemagic is the right scheduler here: it runs off **`develop`** (no merge to `main`
needed, unlike GitHub Actions) and is your CI SSOT.

> ⚠️ **Activation requires a push.** Codemagic runs whatever `codemagic.yaml` is in
> the pushed branch. Nothing runs until the feed-routine code (currently on local
> `develop`, unpushed) + this workflow are pushed. Everything below is prepared so
> push is the only remaining step.

## Step 1 — Add Supabase data-ops secrets to a Codemagic group
The existing `mealvana_dev` / `mealvana_prod` groups carry the `.env` contents
(so `SUPABASE_URL`, `USDA_API_KEY` are already there) but NOT the service-role keys
or access token. Create a group **`mealvana_data_ops`** (Codemagic → App settings →
Environment variables) with these secure vars:
- `SUPABASE_ACCESS_TOKEN` — for `supabase db query --linked` (Management API). (Same
  value already in the GitHub secret of that name.)
- `DEV_SUPABASE_SERVICE_ROLE_KEY` — from `secrets/supabase_service_role_keys.md` (Dev).
- `PROD_SUPABASE_SERVICE_ROLE_KEY` — from `secrets/supabase_service_role_keys.md` (Prod).
- `USDA_API_KEY` — from `.env` (optional; enables nutrition enrichment).

## Step 2 — Add this workflow to `codemagic.yaml`
Append under `workflows:` (do NOT rewrite the file — append only):

```yaml
  refresh-feed:
    name: Scheduled - Refresh TheFeed catalog (dev + prod)
    instance_type: linux_x2
    max_build_duration: 30
    environment:
      groups:
        - mealvana_data_ops
      vars:
        DEV_SUPABASE_URL: https://vlmtsdzpnjnavdgytcmi.supabase.co
        PROD_SUPABASE_URL: https://wvmvsodrvbkxfydabqed.supabase.co
        DEV_REF: vlmtsdzpnjnavdgytcmi
        PROD_REF: wvmvsodrvbkxfydabqed
    scripts:
      - name: Install Supabase CLI
        script: npm i -g supabase
      - name: Refresh DEV (import + deactivate-removed + classify-new)
        script: |
          set -euo pipefail
          export SUPABASE_URL="$DEV_SUPABASE_URL"
          export SUPABASE_SERVICE_ROLE_KEY="$DEV_SUPABASE_SERVICE_ROLE_KEY"
          export FDA_API_KEY="${USDA_API_KEY:-}"
          node scripts/update_catalog.js
          supabase link --project-ref "$DEV_REF"
          supabase db query --linked -f scripts/classify_unclassified_by_type.sql
      - name: Refresh PROD
        script: |
          set -euo pipefail
          export SUPABASE_URL="$PROD_SUPABASE_URL"
          export SUPABASE_SERVICE_ROLE_KEY="$PROD_SUPABASE_SERVICE_ROLE_KEY"
          export FDA_API_KEY="${USDA_API_KEY:-}"
          node scripts/update_catalog.js
          supabase link --project-ref "$PROD_REF"
          supabase db query --linked -f scripts/classify_unclassified_by_type.sql
```

The importer's built-in 10% anti-wipeout guard protects against a bad Shopify
fetch. `update_catalog.js` is non-destructive (B0), so a re-run is always safe.

## Step 3 — Push, then set the schedule
1. Push `develop` (with the feed-routine commits + this workflow).
2. In Codemagic → App → the `refresh-feed` workflow → **Schedule a build**: weekly,
   branch `develop`, e.g. Mondays ~09:23 (off the :00 mark). Or via the Codemagic
   REST API (`POST /builds` on a cron is configured in the UI; programmatic schedule
   creation is limited — the UI toggle is the reliable path).

## Notes
- Skill / manual run: `/refresh-feed` or `.claude/commands/refresh-feed.md`.
- The **events** routine can't run here — it needs Claude (web research). Schedule
  that as a cloud Claude routine / headless-Claude job, not plain Codemagic.
- Full design: `docs/technical/data-refresh-routines.md`.
