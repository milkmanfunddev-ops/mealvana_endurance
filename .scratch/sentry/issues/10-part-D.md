# Ticket 10, part D: meal planning cluster off the legacy aliases

Scope: `meal_planning`, `formula_kit`, `ai_coach`, `coach_mode`, `personal_templates`, `recipes`
(lib + tests). Verification: `dart analyze` on all 66 changed files. No errors; the only warnings
are five pre-existing ones in `test/features/recipes/recipe_repository_test.dart` (dead helpers,
unused `dart:convert`), identical at HEAD and left alone. No `flutter test`, per the brief.

## Files converted (66)
- lib: 46 (meal_planning 21, formula_kit 9, coach_mode 8, ai_coach 4, personal_templates 3,
  recipes 1). That is 32 files off `AppLogger` / `SentryReporter` (219 call sites), plus the
  domain decoders and their callers below.
- test: 20 (meal_planning 7, formula_kit 5, coach_mode 4, ai_coach 1, personal_templates 1,
  recipes 1, `test/new_sync/coach_repository_sync_test.dart` 1).

Areas are the feature names (`meal_planning`, `formula_kit`, `ai_coach`, `coach_mode`,
`personal_templates`, `recipes`); the legacy `context:` string survives only inside
`LoggedFault(m, context: c)`. `_sentry.reportNetworkError` (coach messaging, personal templates)
became `degraded(e, area: 'network', tags: {method}, extra: {url})`. Repositories that already
had wave 3's `Report? report` + `_r` getter dropped their logger param and route through `_r`.
Unused `_context` constants were deleted.

## Calls that departed from the mapping table
- `coach_activity_detail_controller.dart`: two `logger.warning` calls that record successful
  loads ("loaded remote activity", "parsed nutrition plan") became `_report.info`, not
  `degraded`; the table would have raised a Sentry warning on every coach activity view.
- `ai_coach_chat_controller.dart`: the offline and out-of-AI-credits `logger.error` calls became
  `degraded`, not `fault`; both are expected conditions shown to the user. The remaining
  `_logger.error` calls are `fault`, as the prompt asked; the repository Faults and rethrows the
  same object, and Report dedupes it.

## Identity calls deleted
None. No `setUserContext` / `clearUserContext` calls were in scope.

## Domain decoders moved to `DecodeIssue`
The eight named files no longer import `Report`: `vana_part.dart`, `vana_stream_event.dart`,
`wire_record.dart`, `day_plan.dart`, `personal_formula.dart`, `ai_coach_ui_part.dart`,
`ai_coach_message.dart`, `personal_template.dart`. Each former report site calls
`onIssue(message, error:, stackTrace:)` with the same fallback. The old `extra` fields (kind,
slot, key/type, message id, template id, the line head) are now in the message text, because
`DecodeIssue` carries no extras.

`readRecordList` and `DayPlan.fromJson` sit under many nested factories. To keep nested failures
reported, `onIssue` is threaded through every meal-planning factory on a path to a report site:
`MealPlan`, `PlanMeal`, `AthleteContext`, `AthleteWeekContext`, `AthleteBudgetContext`,
`HomePayload`, `HomeDays`, `MealDetail`, `VanaMessage`, the nine Vana part factories that nest
lists, `VanaPart.listFromJson` and `VanaStreamEvent.fromJson`. Every parameter is optional and
defaults to `ignoreDecodeIssue`, so the tests and other callers compile unchanged.

Data-layer callers pass `report.decodeIssue(area)`:
- `vana_chat_repository.dart`: stream events, history parts; `messageFromRow` (static) takes
  `onIssue`.
- `vana_action_client.dart`: `VanaActionResult` carries `onIssue` for its typed accessors.
- `meal_plan_repository.dart`: `_assemble`; `_planMealFromEntry` is now an instance method.
- `personal_formulas_repository.dart`, `ai_coach_chat_repository.dart`,
  `personal_templates_repository.dart` (new `_fromEntry` helper).

Behaviour change: `personal_template.dart` used `fault`. Through `decodeIssue` its decode
failures are now `degraded`.

## Left over
- `grep` still matches `AppExternalDeps(` in three tests (`meal_planning/helpers/container.dart`,
  `formula_kit/formula_editor_analytics_test.dart`, `formula_kit/fork_conflict_metadata_test.dart`).
  These construct the class without the `sentry:` / `logger:` args, which is allowed.
- 14 `SentryReport.global` uses remain in scope, all outside the domain layer. They are wave 3's
  `_r` fallbacks (`_report ?? SentryReport.global`) and static data-layer helpers
  (`meal_plan_repository._decodeList/_decodeMap`, `user_memory_repository`). The brief did not
  ask for them to move.
- `test/new_sync/coach_repository_sync_test.dart` is outside part D's test scope. It was edited
  only because `CoachRepository` lost its `logger:` param. If another part also converted it,
  expect a trivial conflict.
- The rest of the repo still has compile errors where `deps.logger` / `deps.sentry` are now
  nullable. Those are other parts' files.
