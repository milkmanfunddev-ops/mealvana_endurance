# 09 part B: meal_planning, formula_kit, ai_coach, daily_macros

Companion to `09-migrate-credits-subscription-notifications-the-rest.md` (parts A and C
are other agents'). Scope: every catch block, print-in-catch and Sentry import under
`lib/features/{meal_planning,formula_kit,ai_coach,daily_macros}/`. 65 baseline lines
deleted from `test/shared/source_guard/allow_list.md`; one `reasoned` entry added.

**Status:** done

Conventions used (brief § The ladder):
- Malformed JSON that a tolerant decoder turns into a fallback (wire records, Drift
  JSON columns, metadata) is **Degraded**: the app lives with it, the server or a
  past write broke a contract. Static decoders with no instance in reach report via
  `SentryReport.global`; the comment at each site says so.
- Vana remote-ack screens report through the new
  `lib/features/meal_planning/application/vana_failure_report.dart` extension:
  `report.vanaFailure(e, st, operation:)` is **Degraded** for
  `VanaUnauthenticatedException`, `ProRequiredException` (spec ruling, Testing
  Decisions 10), `VanaRateLimitedException`, `VanaOfflineException`,
  `NeedsConnectionException`, and **Fault** otherwise; `report.vanaNeedsConnection(op)`
  is a **Note** (the athlete was told). Screens stay UI-only: two lines per catch.
- Sync pipeline catches (`syncFromRemote`, `uploadDirtyRecords`, `ensureSynced`) use
  `area: 'sync'` with a `repository` tag, per the brief.
- `_logger.error` / `_logger.warning` inside catches of files touched here were
  converted to `Report` in the same pass (brief § Getting a Report). `_logger.info`
  narrative stays.

## Sites

### ai_coach (area `ai_coach`)
- lib/features/ai_coach/data/ai_coach_chat_repository.dart:162 — Fault — fetchConversations failed; was `_logger.error` + rethrow, now `_r.fault` + rethrow
- lib/features/ai_coach/data/ai_coach_chat_repository.dart:190 — Fault — fetchMessages failed; same conversion
- lib/features/ai_coach/data/ai_coach_chat_repository.dart:352 — Fault — jade-chat NDJSON line did not parse, line dropped; `debugPrint` removed (printInCatch + unreportedCatch)
- lib/features/ai_coach/domain/ai_coach_message.dart:71 — Degraded — `metadata.ui_parts` malformed, parts dropped, message still renders (global; domain `fromJson`)
- lib/features/ai_coach/domain/ai_coach_ui_part.dart:87 — Degraded — a part of a known kind did not parse, part dropped (unknown kinds return null without an exception, unchanged)
- lib/features/ai_coach/presentation/providers/ai_coach_banner_providers.dart:32 — Fault — baseline check threw, banner hidden; `fault` downgrades network itself

### daily_macros (area `daily_macros`)
- lib/features/daily_macros/application/daily_macro_service.dart:249 — Fault — calculate-daily-macros (day) threw outside the typed path; `print` removed, still rethrown as `DailyMacroCalculationException`
- lib/features/daily_macros/application/daily_macro_service.dart:498 — Fault — same for the week call; `print` removed
- lib/features/daily_macros/application/daily_macro_service.dart:838 — Degraded — `brick_metadata` JSON malformed, single-session pricing used (top-level function, global)
- lib/features/daily_macros/data/daily_macro_targets_repository.dart:240 — Degraded — cached `calculation_input` JSON malformed, read as absent (was static, now instance so it reports through `_r`)
- lib/features/daily_macros/data/daily_macro_targets_repository.dart:257 — Fault, then Note — remote cache save failed; first failure per session is a Fault with `operation: remote_cache_save`, repeats are Notes (kept the per-session dedup; a week overview saves seven days). `SentryReporter` + `sentry_flutter` import gone (sentryImport)
- lib/features/daily_macros/presentation/providers/daily_macros_controller.dart:251 — Degraded — typed `DailyMacroCalculationException`, reason shown to the athlete
- lib/features/daily_macros/presentation/providers/daily_macros_controller.dart:271 — Fault — week calculation threw outside the typed path, generic error shown
- lib/features/daily_macros/presentation/providers/daily_macros_controller.dart:~243 — Note — not a catch: the "week calc made no progress; not re-invalidating" `kDebugMode print` branch is now a Note (rule D9)

### formula_kit (area `formula_kit`)
- lib/features/formula_kit/application/coach_insight_controller.dart:104 — Fault — coach insight auto-persist failed, insight still shown; `debugPrint` removed (printInCatch + unreportedCatch)
- lib/features/formula_kit/application/coach_insight_controller.dart:150 — Fault — analytics event failed; `debugPrint` removed. `Report` fan-out is zone-guarded so a throwing tracker cannot loop
- lib/features/formula_kit/application/formula_conflict_json.dart:13 — Degraded — db string-array JSON malformed, decoded as empty (top-level function, global)
- lib/features/formula_kit/application/formula_library_controller.dart:823 — Degraded — template quantity-map JSON malformed, field read as empty
- lib/features/formula_kit/application/formula_library_controller.dart:847 — Degraded — `component_carb_ratios` JSON malformed, ratios dropped
- lib/features/formula_kit/application/formula_library_controller.dart:950 — Degraded — template string-array JSON malformed, field read as empty
- lib/features/formula_kit/data/ai_coach_client.dart:148 — Fault (non-402) / silent (402) — `on FunctionException`: a 402 is the credits paywall and is rethrown typed with no report; any other status is a Fault with `status` before the typed throw. `debugPrint` removed (printInCatch)
- lib/features/formula_kit/data/ai_coach_client.dart:184 — Fault — insight call threw outside the typed paths, then typed throw; `debugPrint` removed (printInCatch)
- lib/features/formula_kit/data/formula_pins_repository.dart:179 — Fault (area `sync`) — syncFromRemote failed; was `_logger.error`
- lib/features/formula_kit/data/formula_pins_repository.dart:333 — Fault (area `sync`) — uploadDirtyRecords failed; was `_logger.error`
- lib/features/formula_kit/data/formula_pins_repository.dart:527 — Fault — immediate pin upload failed, pin stays dirty; was `_logger.warning` + `_sentry.reportNetworkError`. `SentryReporter` + `sentry_flutter` import gone (sentryImport)
- lib/features/formula_kit/data/formula_pins_repository.dart:~583 `_logUnknownTemplateKind` — Degraded — not a catch: `_sentry.captureMessage` (warning) is now `_r.degraded(LoggedFault(...))` with the pin id and kind
- lib/features/formula_kit/data/personal_formulas_repository.dart:162 — Fault (area `sync`) — syncFromRemote failed; was `_logger.error`
- lib/features/formula_kit/data/personal_formulas_repository.dart:314 — Fault (area `sync`) — uploadDirtyRecords failed; was `_logger.error`
- lib/features/formula_kit/data/personal_formulas_repository.dart:494 — Fault — immediate formula upload failed, formula stays dirty; was `_logger.warning` + `_sentry.reportNetworkError`. Sentry import gone (sentryImport)
- lib/features/formula_kit/data/personal_formulas_repository.dart:~531 `_logUnknownFormula` — Degraded — not a catch: `_sentry.captureMessage` is now `_r.degraded(LoggedFault(...))`
- lib/features/formula_kit/domain/personal_formula.dart:356 — Degraded — stored string-list JSON malformed, read as empty (static, global)
- lib/features/formula_kit/domain/personal_formula.dart:381 — Degraded — stored components JSON malformed, read as empty (static, global)
- lib/features/formula_kit/presentation/screens/formula_detail_screen.dart:126 — Fault — pin toggle from the detail screen failed; snackbar kept
- lib/features/formula_kit/presentation/screens/formula_editor_screen.dart:107 — Fault — conflicted pin completion failed; snackbar kept
- lib/features/formula_kit/presentation/widgets/pin_conflict_card_state.dart:78 — Fault — "pin anyway" failed; snackbar kept
- lib/features/formula_kit/presentation/widgets/pin_conflict_card_state.dart:96 — Fault — unpin from the conflict card failed; snackbar kept
- lib/features/formula_kit/presentation/widgets/pin_toggle.dart:216 — Fault — pin toggle failed, with `template_id` and `pinning`; snackbar kept

### meal_planning (area `meal_planning` unless noted)
- lib/features/meal_planning/application/meal_plan_controller.dart:100 — Fault (area `sync`) — `ensureSynced('meal_plans')` failed, non-fatal; was `_logger.warning`
- lib/features/meal_planning/application/meal_plan_controller.dart:~190 — Note — not a catch: deferred upload failed, rows stay dirty (the repository already raised the Fault); was `_logger.warning`
- lib/features/meal_planning/application/meal_plan_controller.dart:211 — Note — plan re-read after upload skipped on `VanaException`; was `_logger.debug`
- lib/features/meal_planning/application/meal_plan_controller.dart:280 — Fault (area `push`) — plan reminders not scheduled, confirm still succeeds; was `_logger.warning`. Reporting only; what gets scheduled is unchanged
- lib/features/meal_planning/application/meal_plan_controller.dart:~355 — Note — not a catch: could not flush local edits before a remote-ack action, proceeding; was `_logger.warning`
- lib/features/meal_planning/data/meal_plan_repository.dart:183 — Fault (area `sync`) — syncFromRemote failed; was `_logger.error`
- lib/features/meal_planning/data/meal_plan_repository.dart:254 — Fault (area `sync`) — uploadDirtyRecords failed; was `_logger.error`
- lib/features/meal_planning/data/meal_plan_repository.dart:373 — Note — coverage scope stored as a bare string, read as-is (the code documents tolerating that encoding)
- lib/features/meal_planning/data/meal_plan_repository.dart:936 — Degraded — local JSON list column malformed, read as empty (static, global)
- lib/features/meal_planning/data/meal_plan_repository.dart:954 — Degraded — local JSON map column malformed, read as empty (static, global)
- lib/features/meal_planning/data/user_memory_repository.dart:188 — Fault (area `sync`) — syncFromRemote failed; was `_logger.error`
- lib/features/meal_planning/data/user_memory_repository.dart:262 — Fault (area `sync`) — uploadDirtyRecords failed; was `_logger.error`
- lib/features/meal_planning/data/user_memory_repository.dart:525 — Note — memory value stored as a bare string, read as-is (static, global)
- lib/features/meal_planning/data/vana_transport.dart:96 — Fault — network error streaming an edge function, then `VanaOfflineException`; `fault` downgrades the socket/DNS cases itself. Was `_logger.error`
- lib/features/meal_planning/data/vana_transport.dart:133 — Fault — same for the unary call
- lib/features/meal_planning/data/vana_transport.dart:202 — Reasoned — `_tryDecode` returns null and each caller owns it: `postJson` throws `invalid_response`, `mapErrorResponse` reports and tolerates text bodies, `_decodeLine` reports the skipped line
- lib/features/meal_planning/data/vana_transport.dart:~165 `mapErrorResponse` — Degraded (401/403/429) / Fault (other non-2xx) — not a catch: was `_logger.error('Vana HTTP ...')`; carries status and the first 500 bytes of the body
- lib/features/meal_planning/data/vana_transport.dart:~230 `_decodeLine` — Degraded — not a catch: non-object NDJSON line skipped; was `_logger.warning`
- lib/features/meal_planning/domain/day_plan.dart:87 — Degraded — day slot ref malformed, slot read as empty (global)
- lib/features/meal_planning/domain/vana_part.dart:59 — Degraded — part of a known kind did not parse (`FormatException`), part dropped (global)
- lib/features/meal_planning/domain/vana_part.dart:71 — Degraded — part of a known kind had wrong types (`TypeError`), part dropped (global)
- lib/features/meal_planning/domain/vana_stream_event.dart:30 — Degraded — NDJSON line is not JSON, line dropped (global)
- lib/features/meal_planning/domain/wire_record.dart:148 — Degraded — one wire record in a list did not parse, entry dropped (global)
- lib/features/meal_planning/presentation/screens/cooking_mode_screen.dart:66 — Note — vibration unavailable, ringing chip is the fallback
- lib/features/meal_planning/presentation/screens/cooking_mode_screen.dart:91 — Note (area `push`, so promoted to a warning) — cooking-timer local notification not shown, chip is the fallback. Reporting only; the `show()` call is unchanged
- lib/features/meal_planning/presentation/screens/meal_detail_screen.dart:466 — Note — `pick_meals (detail)` needs a connection
- lib/features/meal_planning/presentation/screens/meal_detail_screen.dart:475 — Fault / Degraded by exception type — `pick_meals (detail)` failed (`vanaFailure`)
- lib/features/meal_planning/presentation/screens/meal_detail_screen.dart:513 — Note — `swap_meal (detail)` needs a connection
- lib/features/meal_planning/presentation/screens/meal_detail_screen.dart:522 — Fault / Degraded — `swap_meal (detail)` failed
- lib/features/meal_planning/presentation/screens/meal_detail_screen.dart:632 — Fault / Degraded — `save_to_mine` failed
- lib/features/meal_planning/presentation/screens/plan_tab.dart:153 — Fault / Degraded — `pick_meals (undo remove)` failed
- lib/features/meal_planning/presentation/screens/plan_tab.dart:314 — Note — `confirm_plan` needs a connection
- lib/features/meal_planning/presentation/screens/plan_tab.dart:323 — Fault / Degraded — `confirm_plan` failed
- lib/features/meal_planning/presentation/screens/swap_meal_screen.dart:258 — Note — `swap_meal` needs a connection
- lib/features/meal_planning/presentation/screens/swap_meal_screen.dart:267 — Fault / Degraded — `swap_meal` failed
- lib/features/meal_planning/presentation/screens/vana_browse_screen.dart:132 — Note — `pick_meals (browse)` needs a connection
- lib/features/meal_planning/presentation/screens/vana_browse_screen.dart:141 — Fault / Degraded — `pick_meals (browse)` failed
- lib/features/meal_planning/presentation/screens/vana_chat_screen.dart:722 — Fault — attach-sheet photo pick failed (`VanaAttachPickFailed`); snackbar kept
- lib/features/meal_planning/presentation/screens/vana_chat_screen.dart:792 — Fault — photo-capture image pick threw; snackbar kept. Photo-capture stays on
- lib/features/meal_planning/presentation/screens/vana_chat_screen.dart:892 — Note — `pick_meals (chat sheet)` needs a connection
- lib/features/meal_planning/presentation/screens/vana_chat_screen.dart:901 — Fault / Degraded — `pick_meals (chat sheet)` failed
- lib/features/meal_planning/presentation/screens/vana_chat_screen.dart:922 — Note — `accept_rule` needs a connection
- lib/features/meal_planning/presentation/screens/vana_chat_screen.dart:931 — Fault / Degraded — `accept_rule` failed
- lib/features/meal_planning/presentation/screens/vana_chat_screen.dart:949 — Fault / Degraded — `swap_meal (chat sheet)` failed
- lib/features/meal_planning/presentation/screens/vana_chat_screen.dart:987 — Fault / Degraded — `confirm_plan (review sheet)` failed, sheet told `false`
- lib/features/meal_planning/presentation/widgets/vana_mic_button.dart:64 — Note — speech recognition unavailable, mic button hidden (plain `StatefulWidget`, global)

## Tests
- `test/features/formula_kit/data/{formula_pins_repository,personal_formulas_repository,coach_insight_persist_roundtrip}_test.dart`: `MockSentryReporter` and the `SentryLevel` fallback are gone; the repositories take `report: RecordingReport()`. The pins unpin test now asserts the failed immediate uploads land as `formula_kit` Faults through `RecordingReport`.
- Constructors gained an optional `Report? report` (falls back to `SentryReport.global`), so the daily_macros and meal_planning tests that build repositories directly did not need to change.
- Run: guard test green; `test/features/{formula_kit,daily_macros,meal_planning,ai_coach}` 712 passed, 2 skipped (pre-existing skips).

## Left for ticket 10 (legacy aliases, not catches or not in this scope's baseline)
- `_logger.error` inside catches of files this ticket did not otherwise touch:
  `lib/features/meal_planning/data/vana_chat_repository.dart` (172, 220),
  `lib/features/meal_planning/application/vana_chat_controller.dart`,
  `lib/features/ai_coach/presentation/providers/ai_coach_chat_controller.dart`,
  `lib/features/formula_kit/application/formula_pin_controller.dart:140`,
  `lib/features/formula_kit/data/{pre,during,post}_workout_templates_repository.dart`.
- `_logger.warning` outside catches in `vana_settings_controller`, `meal_detail_controller`,
  `meal_catalog_controller`, `home_service`, `formula_pin_controller`, `personal_formulas_controller`,
  and the dirty-preserve / unknown-provenance warnings in the two formula_kit repositories.
- `AppExternalDeps.sentry` is still constructed by two formula_kit widget tests
  (`formula_editor_analytics_test`, `fork_conflict_metadata_test`); it is ticket 10's field.
