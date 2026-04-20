# Edge Functions Technical Guide (Repo Truth)

## Current State (Repo Truth)
- Edge functions are stored under `supabase/functions/`.
- App code invokes a subset of available functions; the canonical list is maintained in `/docs/deployment/README.md`.
- Shared edge-function modules live in `supabase/functions/_shared/`.

## Source of Truth
- Edge function folders: `supabase/functions/`
- App invocation points: `lib/**` (`functions.invoke(...)`)
- Deployment workflows: `.github/workflows/deploy-dev.yml`, `.github/workflows/deploy-prod.yml`
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
- Deploy one function manually:
```bash
supabase functions deploy <function-name> --project-ref <project-ref> --no-verify-jwt
```
- Deploy all functions in linked project context:
```bash
supabase functions deploy
```

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
