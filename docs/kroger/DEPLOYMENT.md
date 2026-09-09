# Kroger — dev deployment record

Date: 2026-09-08. User explicitly authorized dev deployment after local verification.

## Current state

| Component | Dev | Production |
|---|---|---|
| Database | Kroger-only migration applied and inspected | Not applied |
| Edge function | `kroger`, ACTIVE, internal JWT validation; configuration updated without source redeploy | Not deployed |
| Credentials | Kroger Production credentials stored as server secrets | Not uploaded |
| Server flag | `KROGER_ENABLED=true` after disabled-state smoke check | Not enabled |
| Flutter source | Implemented; entry visible in dev configuration | Release flag defaults off |
| Mobile build | No build cut/push performed | No build cut/push performed |
| Customer OAuth | Completed on iOS dev against Kroger Production (2026-09-09): a device session showed a connected account and a resolved Location, both of which need a customer token. Android needs its dev redirect URI registered with Kroger first. | Done on iOS |
| Cart write | Never exercised. No item has reached a real Kroger cart from this app. | Not tested |

Dev project: `vlmtsdzpnjnavdgytcmi`. No production database, function, secret,
`app_config` or release branch was modified by this task.

## What was executed

### Production API configuration switch — 2026-09-08

After Lee explicitly approved switching Mealvana DEV to Kroger Production:

1. Verified the saved Production client credentials against Kroger's Production
   token endpoint with `client_credentials` and `product.compact`. Passed; no
   token or secret was logged, and no customer/cart request was made.
2. Ran `node scripts/kroger-dev-admin.mjs secrets-production`: uploaded only
   client ID, client secret, `KROGER_USE_CERTIFICATION=false`, the native redirect
   `com.milkman.mealvanaendurance://callback`, and `KROGER_ENABLED=false` to dev.
3. Ran `verify`: confirmed ACTIVE function, intact private-table grants/RLS,
   unauthenticated 401 and authenticated `available:false` while disabled.
4. Ran `enable`, then `verify-production`: unauthenticated 401 and authenticated
   `available:true, environment:production`. No source redeploy was required.
5. Aligned public Kroger settings in `.env` and `.env.dev.local` with the live
   dev configuration; secrets remain blank in all bundled env assets.

The script remains pinned to Mealvana DEV. `secrets` / `verify-enabled` explicitly
target Kroger Certification; use `secrets-production` / `verify-production` for
the new registration. The local Production server env stays fail-closed; `enable`
is an explicit remote action. Certification credentials remain preserved.

No mobile build, production Supabase change, customer consent or cart write was
performed. Close any old Certification login page and start a new connection
from the app to test customer OAuth against the new environment.

### Initial Certification deployment (historical)

1. Inspected the dev `meal_plans` schema and confirmed the Kroger tables/function
   did not already exist.
2. Applied `supabase/migrations/20260907120000_kroger_shopping.sql` only, through
   the Supabase Management API in one transaction. No `supabase db push` and no
   unrelated pending migrations were executed. The migration is re-runnable.
3. Uploaded five Kroger-only secrets: client ID, client secret, certification
   selection, registered redirect, and an initially false enable flag.
4. Deployed `kroger` with the existing `scripts/deploy_dev.sh` wrapper. Its bundle
   includes the new Kroger modules and existing auth/entitlement/CORS helpers;
   no other edge functions required deployment for the new modules.
5. Inspected ACTIVE/version 1 and `verify_jwt=false`; the function independently
   validates bearer tokens through Supabase Auth.
6. Verified all five Kroger tables have RLS. Authenticated users cannot read
   OAuth tokens/state or directly insert into any of these tables. Draft and
   receipt SELECTs are owner scoped; draft writes use the CAS RPC.
7. Verified unauthenticated status → 401 and authenticated dev status →
   `available:false`. Authentication used the existing dedicated dev login in
   Keychain; no password/session token was logged or written to disk.
8. Enabled the dev certification pilot, then rechecked unauthenticated → 401 and
   authenticated → `available:true`, environment `certification`.

`scripts/kroger-dev-admin.mjs` is dev-target-only tooling for these actions. It
prefers the standard PAT file and falls back to the known ignored management
credential file. No credentials are embedded in command arguments or committed.
The local server template and `secrets` mode intentionally start disabled;
`enable` is the separate, explicit activation step.

## Verification

- 42 Flutter tests passed: 41 Kroger tests plus the shopping-header regression.
- 12 Deno backend tests passed; function and probe type checks passed.
- Actual PostgreSQL migration/grants/RLS/CAS/rate-limit assertions passed in an
  isolated disposable database; its local server was stopped afterward.
- Targeted Flutter analysis passed with no issues. Whole-repo analysis had zero
  errors and existing unrelated warnings/infos; design-library check reported
  existing repo violations, none in the new Kroger feature.
- Live Kroger certification read-only probe passed token, location, search and
  UPC detail/normalization checks. The sampled product was not pickup-eligible;
  the live cart test needs an eligible test fixture.

Task-checker result: targeted analysis **0 errors / 0 warnings / 0 infos**;
whole-repo analysis **0 errors / 109 warnings / 891 infos**. Riverpod generated
files were regenerated successfully. Tests: **42/42 Flutter, 12/12 Deno**, plus
PostgreSQL assertions including migration reapplication. Verdict: ready for
hands-on dev acceptance; production rollout remains gated on the checks below.

No customer Kroger account was authorized and no cart was modified. This record
is a backend deployment, not a mobile release cut: no Codemagic/Shorebird build
was started and no Notion release card was marked Ready to Test.

## Next acceptance gate

Run the code in the appropriate dev mobile app, connect a Kroger customer
account through Kroger Production, and complete [TESTING.md](TESTING.md).
Kroger does not offer Certification customer accounts. Android dev first
needs its `.dev` redirect registered with Kroger and matched in server config.
The sole currently confirmed URI remains the base native scheme. Production
device OAuth, refresh, eligible product/cart modalities,
and an explicitly approved test-cart addition are still open.

Follow the normal production release sequence only after those gates pass.
