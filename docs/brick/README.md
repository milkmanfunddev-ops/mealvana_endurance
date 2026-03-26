# Brick Workouts Guide (Repo Truth)

## Current State (Repo Truth)
- Brick workouts are represented as combined multi-segment activities.
- Nutrition and macro generation for brick sessions uses brick-aware services in nutrition plan feature code.
- Brick metadata is modeled in the activities domain and used across activity and nutrition flows.

## Source of Truth
- Brick metadata model: `lib/features/activities/domain/brick_metadata.dart`
- Brick exceptions/domain rules: `lib/features/activities/domain/brick_exceptions.dart`
- Brick macro service: `lib/features/nutrition_plan/application/brick_macro_service.dart`
- Activity/nutrition helpers and presentation behavior: `lib/features/activities/` and `lib/features/nutrition_plan/`

## Runbook / Commands
- Find brick-related code:
```bash
rg -n "brick|Brick" lib/features/activities lib/features/nutrition_plan -S
```
- Run brick-related tests:
```bash
flutter test test/features/activities/domain/brick_metadata_test.dart
```
- Run nutrition presentation tests touching brick detail behavior:
```bash
flutter test test/features/nutrition_plan/presentation
```

## Verification Checklist
- Brick metadata structure remains compatible with current services/controllers.
- Brick macro generation still calls `generate-macros-v4` via brick service.
- Brick UI behavior remains in presentation layer while business logic remains in services/controllers.

## Related Docs
- `/docs/business_logic/README.md`
- `/docs/deployment/README.md`
- `/docs/technical/foa-architecture.md`

## Deprecated/Legacy Notes
- Older planning/roadmap docs may describe designs that were not finalized.
- Use code references above as canonical behavior for current brick support.
