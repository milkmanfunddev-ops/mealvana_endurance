# 09: Migrate: credits, subscription, notifications, the rest

**What to build:** Every catch block in AI credits, subscription and entitlements, the notification service (OneSignal init, permission, identity sync), and every remaining directory not covered by tickets 05 to 08 is classified and moved to `Report`: a swallowed failure becomes a Fault, an expected-but-bad condition a Degraded, a best-effort branch a Note with its area set, and a try/catch that hides a real bug is removed so the error propagates. Direct Sentry SDK calls in these directories route through `Report`. Every baseline entry for these directories is deleted from the guard's allow-list; any catch left deliberately silent gets a reasoned entry instead. The ticket's closing comment lists every site and its classification so review can overrule one.

**Blocked by:** 01 Report service exists; 04 Source guard with a baseline

**Status:** done (2026-10-06, wave 3; parts merged on `sentry`)

- [ ] No baseline entry remains for AI credits or the other directories in scope; the guard test is green
- [ ] No `print`, `debugPrint`, logger-only or empty catch remains in scope; each is a `Report` call, a rethrow, or a reasoned allow-list entry
- [ ] No direct Sentry SDK import remains in scope
- [ ] The ticket records each site's classification (Fault / Degraded / Note / removed / reasoned)
- [ ] Existing tests in scope still pass; where a catch becomes a Fault on a tested path, the test asserts the report through `NoopReport` or the transport, not console output


## Part A: ai_credits, subscription, push

## Sites

### lib/features/ai_credits/application/credits_controller.dart
- credits_controller.dart:72 — Fault (`credits`) — build fell through both repository guards; the zero shown is a stand-in. Asserted via RecordingReport in `credits_controller_test` ("a throwing repository degrades to zero").
- credits_controller.dart:108 — Legacy → `report.debug` — remote wallet update narrative, was a bare `debugPrint` outside any catch.

### lib/features/ai_credits/application/purchase_controller.dart
- purchase_controller.dart:144 — Legacy → Fault (`payments`) — purchase attempted with no signed-in user. Asserted via RecordingReport in `purchase_controller_test` ("no signed-in user → notSignedIn").
- purchase_controller.dart:157 — Legacy → breadcrumb (`payments`) — anonymous session blocked, an expected funnel step.
- purchase_controller.dart:195 — Legacy → Fault (`payments`) — store confirmed but the wallet never moved (highest-severity invisible failure).
- purchase_controller.dart:213 — Legacy → Fault (`payments`) — `AsyncValue.guard` caught a store/SDK error during buy. Note for review: the Riverpod observer (ticket 03) also sees this `AsyncError`; the explicit Fault keeps the sku tags, so left as is.
- purchase_controller.dart:246 — Note (`payments`, promoted) — pre-purchase balance unread, assuming 0; was an empty `catch (_)`. Can only over-report "credited", never hide a charge.
- purchase_controller.dart:286 — Note (`credits`, breadcrumb only) — one poll attempt failed; a later attempt may succeed and exhaustion is the caller's Fault. `debugPrint` removed.
- purchase_controller.dart:275, :303 — Legacy → breadcrumb (`credits`) — poll succeeded / poll exhausted, were `debugPrint`s outside any catch; the exhausted line now rides the caller's Fault.

### lib/features/ai_credits/data/credits_repository.dart
- credits_repository.dart:88 — Fault (`credits`) — `ensure-credits` edge call failed; a stale zero on screen, never a lost grant.
- credits_repository.dart:119 — Fault (`credits`) — `token_wallets` read failed; zero returned. Asserted via RecordingReport in `credits_repository_test` ("fetchWallet returns zero on exception").
- credits_repository.dart:162 — Fault (`credits`) — realtime payload did not parse; schema drift, not a network blip (keys attached).
- credits_repository.dart:198 — Fault (`credits`) — `token_ledger` read failed; empty ledger returned.

### lib/features/ai_credits/data/revenuecat_service.dart
Constructor now takes `Report? report` (was `SentryReporter sentry`); the `_report`/`_crumb` helpers' `debugPrint`s are gone, every catch calls `_r.fault` inline with `rc_operation` / `rc_store` tags. `revenueCatServiceProvider` lifecycle unchanged (keepAlive).
- revenuecat_service.dart:150 — Legacy → Fault (`payments`) — wrong-platform API key, RevenueCat disabled for the session.
- revenuecat_service.dart:186 — Fault (`payments`) — `Purchases.configure` threw.
- revenuecat_service.dart:212 — Fault (`payments`) — `Purchases.logIn` threw (a missed login credits nobody's wallet).
- revenuecat_service.dart:245 — Fault (`payments`) — `getOfferings` threw; null returned.
- revenuecat_service.dart:268 — Legacy → Fault (`payments`) — purchase attempted before configure.
- revenuecat_service.dart:282 — Fault (`payments`) — `PurchasesError` other than user-cancel; cancel stays a breadcrumb, and `fault` downgrades `purchaseCancelledError` / `networkError` itself if one ever reaches it.
- revenuecat_service.dart:298 — Fault (`payments`) — unexpected purchase error; the raw `PlatformException` cancel shape is still a breadcrumb first.
- revenuecat_service.dart:356 — Fault (`payments`) — `restorePurchases` threw.

### lib/features/subscription/application/subscription_status_provider.dart
- subscription_status_provider.dart:79 — Fault (`subscription`) — resolve failed, degrading to none / tester grant. Asserted via RecordingReport in `subscription_status_provider_test` ("build never throws").

### lib/features/subscription/application/pro_paywall_controller.dart
No catch blocks; converted off `sentryReporterProvider` so ticket 10 can delete it.
- pro_paywall_controller.dart:82 — Legacy → breadcrumb (`subscription`) — PRO_PURCHASE_ENABLED off.
- pro_paywall_controller.dart:92 — Legacy → Fault (`payments`) — pro purchase with no signed-in user.
- pro_paywall_controller.dart:100 — Legacy → breadcrumb (`subscription`) — anonymous session blocked.
- pro_paywall_controller.dart:129 — Legacy breadcrumb → Note (`payments`, promoted) — purchase completed but Pro not yet active: money moved, status did not; the one upgrade in this file.
- pro_paywall_controller.dart:140 — Legacy → Fault (`payments`) — guard caught a store/SDK error during buy.

### lib/features/subscription/data/subscription_service.dart
Constructor now takes `Report? report`; `_report` helper and both `debugPrint`s gone.
- subscription_service.dart:78 — Fault (`payments`) — `getCustomerInfo` threw; null returned.
- subscription_service.dart:148 — Fault (`payments`) — `restorePurchases` threw; null returned.

### lib/features/subscription/data/user_entitlements_repository.dart
Was not in the baseline (its catches used the `AppLogger` alias); converted per the brief's "while you are there" rule. Constructor now takes `Report? report` instead of `AppLogger logger`; provider no longer reads `deps.logger`.
- user_entitlements_repository.dart:87 — Degraded (`subscription`) — `users.is_internal` mirror failed; expected offline, retried on next resolve. Asserted via RecordingReport in `user_entitlements_repository_test` ("mirrorInternalFlag returns false on failure").
- user_entitlements_repository.dart:119 — Fault (`subscription`) — `user_entitlements` remote read failed (offline downgrades itself; RLS/shape is real).
- user_entitlements_repository.dart:148 — Fault (`subscription`) — Drift cache write failed after a good remote read.
- user_entitlements_repository.dart:191 — Fault (`subscription`) — Drift cache read failed.
- user_entitlements_repository.dart:207 — Fault (`subscription`) — Drift cache clear failed on sign-out.

### lib/shared/services/notification_service.dart
Static class: `static Report? _report` with `_r => _report ?? SentryReport.global` and `debugSetReport` as the test seam. Every LaunchTrail line is kept; Report is the PROD-readable half. No ordering or behaviour change.
- notification_service.dart:185 — Fault (`push`) — legacy iOS launch payload could not be read from prefs (tape line kept).
- notification_service.dart:223 — Note (`push`, promoted) — OneSignal init skipped, no app id yet: D9's founding case, now a warning event as well as a tape line. Asserted via RecordingReport in `push_arming_order_test`.
- notification_service.dart:315 — Fault (`push`) — `requestPermission` / opt-out heal threw; a valid-token device may stay unreachable. `debugPrint` removed.
- notification_service.dart:328 — Fault (`push`) — OneSignal init threw. `debugPrint` removed.
- notification_service.dart:445 — Fault (`push`) — login/logout alias sync threw (the `invalid_aliases` mechanism); `detach` flag attached. `debugPrint` removed.
- notification_service.dart:681 — Fault (`push`) — legacy iOS resume payload could not be read (tape line kept).
- notification_service.dart:717 — Fault (`push`) — explicit `requestPermission(true)` threw. `debugPrint` removed.

### Counts
- Catch blocks migrated: 33 (27 Fault, 1 Degraded, 2 Note, 0 Removed, 0 Reasoned) plus 3 catches in `user_entitlements_repository.dart` already counted above (they were alias-reported, not baseline).
  - By baseline: 22 unreportedCatch + 11 printInCatch lines deleted = 33.
- Non-catch legacy calls moved to Report: 15 (purchase_controller 6, revenuecat_service 2 + helpers, pro_paywall_controller 5, credits_controller 1, notification_service 1 new Note).
- Direct `package:sentry*` imports in scope: none before, none after.

### Tests touched
`credits_controller_test`, `purchase_controller_test`, `credits_repository_test`,
`revenuecat_service_test`, `subscription_status_provider_test`,
`subscription_service_test`, `user_entitlements_repository_test`,
`push_arming_order_test`. All green with the guard test (239 tests in the run).

### Left for others
- `test/shared/services/notification_push_identity_test.dart` runs against
  `SentryReport.global` with no injected fake; it passes, no assertion added
  (the sync step bails before any catch in a test binding).
- Duplicate-report question on `purchase_controller.dart:213` and
  `pro_paywall_controller.dart:140` (observer + explicit Fault) is a review call,
  not changed here.


## Part B: meal_planning, formula_kit, ai_coach, daily_macros

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

### Tests
- `test/features/formula_kit/data/{formula_pins_repository,personal_formulas_repository,coach_insight_persist_roundtrip}_test.dart`: `MockSentryReporter` and the `SentryLevel` fallback are gone; the repositories take `report: RecordingReport()`. The pins unpin test now asserts the failed immediate uploads land as `formula_kit` Faults through `RecordingReport`.
- Constructors gained an optional `Report? report` (falls back to `SentryReport.global`), so the daily_macros and meal_planning tests that build repositories directly did not need to change.
- Run: guard test green; `test/features/{formula_kit,daily_macros,meal_planning,ai_coach}` 712 passed, 2 skipped (pre-existing skips).

### Left for ticket 10 (legacy aliases, not catches or not in this scope's baseline)
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


## Part C: remaining features

## Sites

### activities
- lib/features/activities/data/activities_repository.dart:1517 — Degraded — inner provider-key lookup failed during the insert fallback; the original insert error is reported and rethrown right after, this was the second failure hiding behind it
- lib/features/activities/presentation/providers/activities_controller.dart:225 — Fault — analytics swallow (`workout_planned`)
- lib/features/activities/presentation/providers/activities_controller.dart:239 — Fault — analytics swallow (`first_activity_added`)
- lib/features/activities/presentation/widgets/activity_card.dart:276 — Note — undo-delete `restoreActivity` failed; the controller reported before rethrowing, UI shows "Could not restore activity"
- lib/features/activities/presentation/widgets/calendar_date_indicators.dart:53 — Removed — hand-rolled `tryParse`; replaced with `DateTime.tryParse`, same fallback, no catch

### barcode_scanning
- lib/features/barcode_scanning/presentation/screens/add_food_screen.dart:65 — Degraded — `SearchException` is the service's own typed, expected failure; its message is shown to the athlete
- lib/features/barcode_scanning/presentation/screens/add_food_screen.dart:70 — Fault — untyped search failure
- lib/features/barcode_scanning/presentation/screens/add_food_screen.dart:155 — Degraded — `ProductDetailException`, typed and expected, message shown
- lib/features/barcode_scanning/presentation/screens/add_food_screen.dart:164 — Fault — untyped product-detail failure
- lib/features/barcode_scanning/presentation/screens/barcode_scanner_screen.dart:129 — Note — `MobileScannerException` on start is the documented benign init race (MEALVANA-ENDURANCE-79); start skipped, controller will be running once init completes
- lib/features/barcode_scanning/presentation/screens/barcode_scanner_screen.dart:139 — Note — same race on stop; nothing to stop yet
- lib/features/barcode_scanning/presentation/screens/barcode_scanner_screen.dart:231 — Fault — barcode lookup failed; error copy shown

### calendar
- lib/features/calendar/domain/event_subtype.dart:269 — Removed — `firstWhere` + catch-everything as a find-or-null; replaced with a loop returning null

### carb_loading
- lib/features/carb_loading/application/food_import_service.dart:323 — Fault — categories column matched neither the Postgres-array nor the JSON shape; row still imports without categories
- lib/features/carb_loading/application/food_selection_service.dart:54 — Fault — analytics swallow (`carb_loading_food_added`)
- lib/features/carb_loading/domain/carb_foods_list.dart:140 — Removed — `firstWhere` + catch as find-or-null; loop returning null
- lib/features/carb_loading/domain/meal_type.dart:89 — Fault — `meal_types` column unparseable; `parseMealTypeIds` gained an optional `report` parameter (global Report by default) so the test can assert it
- lib/features/carb_loading/presentation/providers/carb_loading_food_selection_controller.dart:319 — Fault — Open Food Facts search failed, results cleared (offline auto-downgrades)
- lib/features/carb_loading/presentation/providers/carb_nudge_coordinator.dart:55 — Fault — was `appLoggerProvider.warning`; the nudge sweep failing is not expected
- lib/features/carb_loading/presentation/screens/carb_loading_day_detail_page.dart:48 — Fault — analytics swallow (`carb_loading_day_viewed`)
- lib/features/carb_loading/presentation/screens/carb_loading_food_selection_screen.dart:832 — Fault — Open Food Facts import failed; error copy shown
- lib/features/carb_loading/presentation/screens/carb_loading_food_selection_screen.dart:890 — Fault — catalog import failed; error copy shown
- lib/features/carb_loading/presentation/screens/carb_loading_food_selection_screen.dart:1074 — Fault — duplicate-to-custom-food failed; `debugPrint` removed
- lib/features/carb_loading/presentation/screens/carb_loading_food_selection_screen.dart:1205 — Fault — user food delete failed; `debugPrint` removed
- lib/features/carb_loading/presentation/screens/carb_loading_food_selection_screen.dart:1262 — Fault — user food update failed; two `debugPrint`s removed
- lib/features/carb_loading/presentation/screens/carb_loading_protocol_selection_screen.dart:246 — Fault — analytics swallow (`carb_loading_protocol_selected`)
- lib/features/carb_loading/presentation/screens/create_custom_carb_loading_food_screen.dart:97 — Fault — custom food create failed; error copy shown

### content
- lib/features/content/application/content_service.dart:49 (`.catchError`) — Fault — not a catch block by the guard's rules, but the same swallow one line up from site 53; background content refresh failed, app continues on cached/default content
- lib/features/content/application/content_service.dart:53 — Fault — synchronous throw from `refreshContent()` before a Future existed
- lib/features/content/application/content_service.dart:75 — Fault — manual refresh failed, returns false (offline auto-downgrades)
- lib/features/content/application/content_service.dart:135 — Fault — bundled content defaults failed to load; a build problem that must be seen. Static class, so this one uses `SentryReport.global`

### education
- lib/features/education/presentation/screens/education_screen.dart:250 — Fault — analytics swallow (`education_video_opened`)
- lib/features/education/presentation/screens/video_player_screen.dart:49 — Fault — analytics tracker unavailable at initState; the screen caches a `Report` in initState for the same reason it caches the tracker (dispose cannot touch `ref`)
- lib/features/education/presentation/screens/video_player_screen.dart:94 — Fault — analytics swallow (`education_video_completed`, fires from dispose)
- lib/features/education/presentation/screens/video_player_screen.dart:136 — Fault — video player failed to initialise; error state shown

### events
- lib/features/events/application/events_service.dart:54 — Removed — `DateTime.parse` + catch as tryParse; `DateTime.tryParse`
- lib/features/events/application/public_events_service.dart:60 — Fault — public events search failed, returns none (the TODO in that catch asked for exactly this)
- lib/features/events/presentation/providers/events_controller.dart:370 — Removed — `DateTime.parse` + catch as tryParse; `DateTime.tryParse`
- lib/features/events/presentation/screens/event_detail_screen.dart:316 — Fault — event delete failed; error copy shown
- lib/features/events/presentation/screens/event_form_screen.dart:246 — Fault — public event search failed, suggestions cleared
- lib/features/events/presentation/screens/event_form_screen.dart:401 — Fault — location search failed, suggestions cleared
- lib/features/events/presentation/screens/event_form_screen.dart:615 — Fault — event create/update failed; error copy shown
- lib/features/events/presentation/screens/events_list_screen.dart:121 — Removed — `DateTime.parse` + catch as tryParse-and-skip; `DateTime.tryParse` with the same `continue`
- lib/features/events/presentation/widgets/event_action_buttons_card.dart:246 — Fault — carb-loading plan creation from the event failed; error copy shown

### fuel_timeline
- lib/features/fuel_timeline/presentation/widgets/energy_breakdown_sheet.dart:210 — Fault — analytics swallow (`weekly_overview_viewed`)

### macro_dashboard
- lib/features/macro_dashboard/presentation/providers/macro_dashboard_providers.dart:82 — Fault — profile weight read failed; dashboard prices with the engine weight instead (fail-soft kept)
- lib/features/macro_dashboard/presentation/providers/macro_dashboard_providers.dart:122 — Fault — carb-plan lookup failed; ordinary day rendered (fail-soft kept)
- lib/features/macro_dashboard/presentation/screens/macro_dashboard_screen.dart:535 — Note — `_guardWrite`: controller reported, rolled back and rethrew; UI owns the failure copy. `_guardWrite` gained a `WidgetRef` parameter
- lib/features/macro_dashboard/presentation/screens/macro_dashboard_screen.dart:574 — Note — skip/unskip failed; controller reported and rolled back
- lib/features/macro_dashboard/presentation/screens/macro_dashboard_screen.dart:596 — Note — undo-skip `restoreActivity` failed; controller reported
- lib/features/macro_dashboard/presentation/screens/macro_dashboard_screen.dart:1006 — Note — undo brick creation (`ungroupBrick`) failed; controller reported
- lib/features/macro_dashboard/presentation/screens/macro_dashboard_screen.dart:1013 — Note — `BrickValidationException`: user input the controller rejected; dialog explains it
- lib/features/macro_dashboard/presentation/screens/macro_dashboard_screen.dart:1021 — Note — `BrickCreationException`: controller `logger.error`s the underlying error before wrapping it; UI shows the dialog and offers retry
- lib/features/macro_dashboard/presentation/screens/macro_dashboard_screen.dart:1031 — Fault — untyped error creating a brick (nothing upstream caught it)
- lib/features/macro_dashboard/presentation/screens/macro_dashboard_screen.dart:1077 — Note — `BrickUngroupException`: controller reported before wrapping
- lib/features/macro_dashboard/presentation/screens/macro_dashboard_screen.dart:1087 — Fault — untyped error ungrouping a brick
- lib/features/macro_dashboard/presentation/screens/macro_dashboard_screen.dart:1168 — Note / Fault — delete brick: Note when the error is a `BrickUngroupException` (controller reported), Fault otherwise

### onboarding
- lib/features/onboarding/application/onboarding_snapshot_service.dart:60 — Fault — was `logger?.warning`; snapshot write to SharedPreferences failing should never happen. Service gained a `Report? report` constructor parameter; `writeSnapshot` lost its unused `logger` parameter (no caller passed one)
- lib/features/onboarding/application/onboarding_snapshot_service.dart:92 — Fault — corrupt snapshot dropped; test asserts the Fault
- lib/features/onboarding/presentation/providers/onboarding_preview_providers.dart:69 — Note — no local profile yet on first run is the expected branch; the auth and temp ids still apply
- lib/features/onboarding/presentation/providers/onboarding_preview_providers.dart:273 — Fault — integration autofill failed; forms keep defaults (offline auto-downgrades)
- lib/features/onboarding/presentation/screens/allergies_screen.dart:103 — Fault — loading current allergies failed; defaults shown
- lib/features/onboarding/presentation/screens/cycling_details_screen.dart:122 — Fault — loading cycling details failed; defaults shown
- lib/features/onboarding/presentation/screens/daily_plan_preview_screen.dart:104 — Fault — analytics swallow (`daily_preview_tab_viewed`)
- lib/features/onboarding/presentation/screens/dietary_preference_screen.dart:98 — Fault — loading dietary preference failed; defaults shown
- lib/features/onboarding/presentation/screens/goals_screen.dart:73 — Fault — analytics swallow (`goals_selected`)
- lib/features/onboarding/presentation/screens/onboarding_pageview_screen.dart:243 — Fault — analytics swallow (`onboarding_step_completed`)
- lib/features/onboarding/presentation/screens/onboarding_pageview_screen.dart:263 — Fault — analytics swallow (`onboarding_completed`)
- lib/features/onboarding/presentation/screens/pitfalls_screen.dart:80 — Fault — analytics swallow (`pitfalls_selected`)
- lib/features/onboarding/presentation/screens/plan_reveal_screen.dart:437 — Fault — analytics swallow (`sweat_test_link_tapped`)
- lib/features/onboarding/presentation/screens/plan_reveal_screen.dart:474 — Fault — analytics swallow (`plan_target_edited`)
- lib/features/onboarding/presentation/screens/running_details_screen.dart:90 — Fault — loading running details failed; defaults shown
- lib/features/onboarding/presentation/screens/sports_selection_screen.dart:97 — Fault — analytics swallow (`sports_selected`)
- lib/features/onboarding/presentation/screens/swimming_details_screen.dart:128 — Fault — loading swimming details failed; defaults shown

No onboarding body copy was touched.

### personal_templates
- lib/features/personal_templates/domain/personal_template.dart:56 — Fault — `planData` column not valid JSON; template loads empty. Domain factory with no injection point, uses `SentryReport.global`
- lib/features/personal_templates/domain/personal_template.dart:65 — Fault — `brickSegmentOrder` not valid JSON; dropped. Same handle

### race_checklist
- lib/features/race_checklist/presentation/screens/race_checklist_screen.dart:638 — Fault — loading event details for the nutrition plan failed; error copy shown

### recipes
- lib/features/recipes/data/repositories/recipe_repository.dart:251 — Fault — cached list column not valid JSON (we wrote it); test asserts the Fault. Repository gained `Report? report`
- lib/features/recipes/presentation/screens/recipes_screen.dart:76 — Fault — loading recipes failed; error state shown

### sharing
- lib/features/sharing/application/email_service.dart:55 — Fault — email send failed; `ShareResult.failure` returned. Service gained `Report? report`
- lib/features/sharing/presentation/providers/share_form_controller.dart:198 — Fault — share failed before the email went out; the existing `plan_share_failed` analytics event stays

### user_foods
- lib/features/user_foods/data/user_foods_repository.dart:363 — Fault — array column not valid JSON; row uploads without it. `_decodeJsonArray` became an instance method so it can reach `_report`; repository gained `Report? report`

### Legacy alias conversions in the same files (brief: "while you are there")

`_logger.error` → `_report.fault`, `_logger.warning` → `_report.degraded`,
one for one (same message, same extra data, `LoggedFault(message)` where no
error object was passed), via a scripted rewrite reviewed in the diff:

- activities_repository.dart: 40 (class gained `Report? report`, provider passes it; `_logger.info/debug` and `_sentry.*` untouched — ticket 10)
- activities_controller.dart: 12 (`_logger` getter replaced by `_report`; `_backgroundSync` caches the Report before its awaits, as it did the logger, because that catch can run on a disposed ref)
- events_service.dart: 11 (class gained `Report? report`, provider passes it)
- events_controller.dart: 9 (the per-method `final logger = ref.read(appLoggerProvider)` cache became `final report = ref.read(reportProvider)` for the same disposed-ref reason)
- recipe_repository.dart: 1
- add_food_screen.dart: 2 `DebugLogger.error` lines in one catch → one Fault; 3 `DebugLogger.warning` branch lines (duplicate food, widget unmounted) → Notes. `DebugLogger.info/debug` untouched

### Tests

- `onboarding_snapshot_service_test`: corrupt-snapshot test asserts one Fault, area `onboarding`.
- `content_service_test`: refresh-throws test asserts the manual-refresh Fault by message (the background refresh kicked by `initialize()` may report the same stub); `_container()` overrides `reportProvider` with a `RecordingReport`.
- `meal_type_parsing_test`: malformed-JSON test asserts one Fault, area `carb_loading`.
- `recipe_repository_test`: malformed-ingredients test asserts one Fault, area `recipes`.
