# Edge Functions Technical Guide (Repo Truth)

## Current State (Repo Truth)
- Edge functions are stored under `supabase/functions/`.
- App code invokes a subset of available functions; the canonical list is maintained in `/docs/deployment/README.md`.
- Shared edge-function modules live in `supabase/functions/_shared/`.

## Source of Truth
- Edge function folders: `supabase/functions/`
- App invocation points: `lib/**` (`functions.invoke(...)`)
- Deployment: manual only — `scripts/deploy_dev.sh` / `scripts/deploy_prod.sh` (or the
  `/deploy-edge` Claude skill). The CI deploy workflows were deleted in `b2f86b4f` (2026-05-22);
  no workflow runs `supabase functions deploy`.
- Deployment hub: `/docs/deployment/README.md`

## Runbook / Commands
- List function folders:
```bash
ls -1 supabase/functions
```
- Extract app-invoked function names:
```bash
rg -n "functions\.invoke\(" lib -S
```
- Deploy one or more functions (the process of record — nothing deploys automatically):
```bash
./scripts/deploy_dev.sh <function-name> [<function-name> ...]
./scripts/deploy_prod.sh <function-name> [<function-name> ...]
```
- Raw CLI equivalent:
```bash
supabase functions deploy <function-name> --project-ref <project-ref> --no-verify-jwt
```
- Avoid bare `supabase functions deploy` (no `--project-ref`): it trusts
  `supabase/.temp/project-ref`, which can silently point at prod after any `supabase link`.

## Verification Checklist
- Every function documented as active exists as a folder under `supabase/functions/`.
- App-invoked list matches current `lib/** functions.invoke(...)` usage.
- `_shared` changes trigger redeploy of importing functions.

## Related Docs
- `/docs/deployment/README.md`
- `/docs/business_logic/README.md`
- `/docs/test/README.md`

## Deprecated/Legacy Notes
- Legacy references to `run-plan`, `generate-ai-nutrition-plan`, and `save-food-preferences` should be treated as historical unless reintroduced in current app code.
