# Business Logic Guide (Repo Truth)

## Current State (Repo Truth)
- Nutrition planning logic is split between Flutter services and Supabase edge functions.
- Main app flow invokes:
  - `generate-nutrition-plan` for plan generation
  - `generate-macros-v4` for macro target generation
- App code currently invokes 11 edge functions total (see deployment doc for full list).
- Legacy function names (`run-plan`, `generate-ai-nutrition-plan`, `save-food-preferences`) are not part of the current app-invoked set.

## Source of Truth
- Plan generation service: `lib/features/nutrition_plan/application/llm_nutrition_plan_service.dart`
- Macro generation service: `lib/features/nutrition_plan/application/macro_generation_service.dart`
- Brick macro generation service: `lib/features/nutrition_plan/application/brick_macro_service.dart`
- Edge function directories: `supabase/functions/`
- Deployment truth model: `/docs/deployment/README.md`

## Runbook / Commands
- Inspect app-invoked function usage:
```bash
rg -n "functions\.invoke\(" lib -S
```
- List available edge-function folders:
```bash
ls -1 supabase/functions
```
- Run algorithm unit tests:
```bash
./supabase/functions/run-algorithm-tests.sh
```
- Run macros v4 integration test directly:
```bash
deno test --allow-net --allow-env supabase/functions/generate-macros-v4/index.test.ts
```

## Verification Checklist
- `llm_nutrition_plan_service.dart` still invokes `generate-nutrition-plan`.
- Macro services still invoke `generate-macros-v4`.
- Any documented active function exists as a folder under `supabase/functions/`.
- App-invoked set in docs matches extracted usage from `lib/** functions.invoke(...)`.

## Related Docs
- `/docs/deployment/README.md`
- `/docs/test/README.md`
- `/docs/technical/edge-functions/README.md`
- `/docs/database/README.md`

## Deprecated/Legacy Notes
- Archived architecture docs contain earlier AI/fallback narrative and function names that no longer represent current app wiring.
- Keep historical references in `/docs/_archived/` only; use this file + deployment hub for current behavior.
