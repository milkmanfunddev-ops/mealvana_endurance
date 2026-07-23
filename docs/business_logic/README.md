# Business Logic Guide (Repo Truth)

## Current State (Repo Truth)
- Nutrition planning logic is split between Flutter services and Supabase edge functions.
- Main app flow invokes:
  - `generate-nutrition-plan-v3` for plan generation (main production flow, via `nutrition_plan_service.dart`)
  - `generate-nutrition-plan` for plan generation (V1 — legacy LLM pathway only, via `llm_nutrition_plan_service.dart`)
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
- `nutrition_plan_service.dart` still invokes `generate-nutrition-plan-v3` (main production flow).
- `llm_nutrition_plan_service.dart` still invokes `generate-nutrition-plan` (V1, legacy LLM pathway).
- Macro services still invoke `generate-macros-v4`.
- Any documented active function exists as a folder under `supabase/functions/`.
- App-invoked set in docs matches extracted usage from `lib/** functions.invoke(...)`.

## Related Docs
- [`Generate Nutrition Plan V3: Algorithm Flow`](./nutrition-plan-v3-algorithm.md)
- `/docs/deployment/README.md`
- `/docs/test/README.md`
- `/docs/technical/edge-functions/README.md`
- `/docs/database/README.md`

## Deprecated/Legacy Notes
- Archived architecture docs contain earlier AI/fallback narrative and function names that no longer represent current app wiring.
- Keep historical references in `/docs/_archived/` only; use this file + deployment hub for current behavior.
