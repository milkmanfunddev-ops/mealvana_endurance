# Report source guard: allow-list

Read by `report_source_guard_test.dart` (rules in `source_guard.dart`). One
entry per line, counted: a file with three identical unreported catch lines
needs three entries. Line format:

    <kind> <path> :: <signature>              (baseline)
    <kind> <path> :: <signature> :: <reason>  (reasoned)

`<kind>` is `unreportedCatch`, `printInCatch` or `sentryImport`; `<signature>`
is the trimmed source line holding the `catch` / bare `on` keyword (or the
import). Lines starting with `>` are notes.

> `baseline` holds every violation on the branch the day the guard landed
> (2026-10-06). Entries are only ever deleted, by the migration ticket that
> fixes the site; the test fails on a stale entry, so this section can only
> shrink. Nothing is added here.
>
> `reasoned` holds sites that stay silent on purpose, each with a one-line
> reason. Adding one is a review decision, not a shortcut.

## reasoned

unreportedCatch lib/shared/services/sentry/sentry_provider_observer.dart :: } on ArgumentError {  :: Expando refuses primitive keys; the catch is the type test, the primitive goes to its own set
unreportedCatch lib/shared/services/sentry/sentry_provider_observer.dart :: } on ArgumentError {  :: same as above, the mark side of the pair
unreportedCatch lib/shared/controllers/food_search_controller.dart :: } catch (_) { :: the catch IS the mounted test: reading `state` after dispose throws; nothing failed, so there is nothing to report
unreportedCatch lib/shared/services/launch_trail.dart :: } catch (_) { :: LaunchTrail is the tape the D9 trail is written to; a recorder that reports into what it records recurses. Lee ruled it stays as is (ticket 05): begin() falls back to memory-only
unreportedCatch lib/shared/services/launch_trail.dart :: } catch (_) { :: same ruling, the native-key re-read: best effort, memory-only on failure
unreportedCatch lib/shared/services/launch_trail.dart :: } catch (_) { :: same ruling, the prefs persist step: the tape stays in memory for this launch
unreportedCatch lib/shared/services/report/report.dart :: } catch (_) { :: `_captureFailed`: the SDK failed twice (capture, then breadcrumb); the debug log already holds it and there is nothing left to write to
unreportedCatch lib/shared/services/report/report.dart :: } catch (_) { :: `_toSentryLog`: structured logs are narrative; a lost log line is not worth a Fault, and raising one from inside Report would recurse
unreportedCatch lib/shared/services/report/report.dart :: } catch (_) { :: `_mirror` debug-log sink: the dev debug screen's log is a convenience; Report must not call itself from its own sink
unreportedCatch lib/shared/services/report/report.dart :: } catch (_) { :: `_mirror` console sink: best effort; Report must not call itself from its own sink
unreportedCatch lib/shared/services/report/report.dart :: } catch (analyticsError) { :: Mixpanel fan-out failed after the Sentry event already left; mirrored to console and the debug log, and a Fault here would fan out again
unreportedCatch lib/shared/services/report/report.dart :: } catch (sdkError) { :: `fault`/`degraded`: Sentry capture threw; `_captureFailed` keeps it on the debug log and as a breadcrumb. The reporter must never take the app down
unreportedCatch lib/shared/services/report/report.dart :: } catch (sdkError) { :: `note` promotion: same as above, the captureMessage side

## baseline

printInCatch lib/features/ai_coach/data/ai_coach_chat_repository.dart :: } catch (e) {
printInCatch lib/features/carb_loading/presentation/screens/carb_loading_food_selection_screen.dart :: } catch (e, stackTrace) {
printInCatch lib/features/carb_loading/presentation/screens/carb_loading_food_selection_screen.dart :: } catch (e) {
printInCatch lib/features/carb_loading/presentation/screens/carb_loading_food_selection_screen.dart :: } catch (e) {
printInCatch lib/features/daily_macros/application/daily_macro_service.dart :: } catch (e) {
printInCatch lib/features/daily_macros/application/daily_macro_service.dart :: } catch (e) {
printInCatch lib/features/formula_kit/application/coach_insight_controller.dart :: } catch (e) {
printInCatch lib/features/formula_kit/application/coach_insight_controller.dart :: } catch (e) {
printInCatch lib/features/formula_kit/data/ai_coach_client.dart :: } catch (e) {
printInCatch lib/features/formula_kit/data/ai_coach_client.dart :: } on FunctionException catch (e) {
printInCatch lib/features/integrations/application/final_surge_sync_service.dart :: } catch (e) {
printInCatch lib/features/integrations/application/final_surge_sync_service.dart :: } catch (e) {
printInCatch lib/features/integrations/application/final_surge_sync_service.dart :: } catch (e) {
printInCatch lib/features/integrations/application/final_surge_sync_service.dart :: } on IntegrationApiException catch (e) {
printInCatch lib/features/integrations/application/final_surge_sync_service.dart :: } on NetworkException catch (e) {
printInCatch lib/features/integrations/application/final_surge_sync_service.dart :: } on TokenExpiredException {
printInCatch lib/features/integrations/application/final_surge_sync_service.dart :: } on TokenExpiredException {
printInCatch lib/features/integrations/application/final_surge_transformer.dart :: } catch (e) {
printInCatch lib/features/integrations/application/garmin_oauth_service.dart :: } catch (e) {
printInCatch lib/features/integrations/application/garmin_oauth_service.dart :: } catch (e) {
printInCatch lib/features/integrations/application/integration_sync_coordinator.dart :: } catch (e, stackTrace) {
printInCatch lib/features/integrations/application/integration_sync_coordinator.dart :: } catch (e, stackTrace) {
printInCatch lib/features/integrations/application/runna_sync_service.dart :: } catch (e) {
printInCatch lib/features/integrations/application/runna_sync_service.dart :: } on NetworkException catch (e) {
printInCatch lib/features/integrations/application/tp_writeback_service.dart :: } on TokenExpiredException {
printInCatch lib/features/integrations/application/training_peaks_oauth_service.dart :: } catch (e) {
printInCatch lib/features/integrations/application/training_peaks_oauth_service.dart :: } on TrainingPeaksApiException catch (e) {
printInCatch lib/features/integrations/application/training_peaks_oauth_service.dart :: } on TrainingPeaksApiException catch (e) {
printInCatch lib/features/integrations/application/training_peaks_sync_service.dart :: } catch (e) {
printInCatch lib/features/integrations/application/training_peaks_sync_service.dart :: } catch (e) {
printInCatch lib/features/integrations/application/training_peaks_sync_service.dart :: } catch (e) {
printInCatch lib/features/integrations/application/training_peaks_sync_service.dart :: } catch (e) {
printInCatch lib/features/integrations/application/training_peaks_sync_service.dart :: } catch (e) {
printInCatch lib/features/integrations/application/training_peaks_sync_service.dart :: } catch (e) {
printInCatch lib/features/integrations/application/training_peaks_sync_service.dart :: } catch (e) {
printInCatch lib/features/integrations/application/training_peaks_sync_service.dart :: } on TrainingPeaksApiException catch (e) {
printInCatch lib/features/integrations/application/training_peaks_transformer.dart :: } catch (e) {
printInCatch lib/features/integrations/application/vdot_sync_service.dart :: } catch (e) {
printInCatch lib/features/integrations/application/vdot_sync_service.dart :: } on TokenExpiredException {
printInCatch lib/features/integrations/data/training_peaks_api_client.dart :: } catch (e) {
printInCatch lib/features/integrations/domain/http_retry_client.dart :: } on RateLimitException catch (e) {
printInCatch lib/features/integrations/domain/http_retry_client.dart :: } on ServerException catch (e) {
printInCatch lib/features/integrations/domain/http_retry_client.dart :: } on SocketException catch (e) {
printInCatch lib/features/integrations/domain/http_retry_client.dart :: } on TimeoutException catch (_) {
printInCatch lib/features/integrations/presentation/providers/connect_training_controller.dart :: } catch (e, st) {
printInCatch lib/features/integrations/presentation/providers/connect_training_controller.dart :: } catch (e, stackTrace) {
printInCatch lib/features/integrations/presentation/providers/connect_training_controller.dart :: } catch (e, stackTrace) {
printInCatch lib/features/integrations/presentation/providers/connect_training_controller.dart :: } catch (e) {
printInCatch lib/features/integrations/presentation/providers/connect_training_controller.dart :: } catch (e) {
printInCatch lib/features/integrations/presentation/providers/connect_training_controller.dart :: } catch (e) {
printInCatch lib/features/integrations/presentation/providers/connect_training_controller.dart :: } catch (e) {
printInCatch lib/features/nutrition_plan/presentation/screens/swap_food_screen.dart :: } catch (e, stackTrace) {
printInCatch lib/features/nutrition_plan/presentation/screens/swap_food_screen.dart :: } catch (e) {
printInCatch lib/features/nutrition_plan/presentation/screens/swap_food_screen.dart :: } catch (e) {
printInCatch lib/features/settings/presentation/screens/debug_screen.dart :: } catch (e, stackTrace) {
sentryImport lib/features/daily_macros/data/daily_macro_targets_repository.dart :: import 'package:sentry_flutter/sentry_flutter.dart';
sentryImport lib/features/formula_kit/data/formula_pins_repository.dart :: import 'package:sentry_flutter/sentry_flutter.dart';
sentryImport lib/features/formula_kit/data/personal_formulas_repository.dart :: import 'package:sentry_flutter/sentry_flutter.dart';
sentryImport lib/features/integrations/application/raw_retention_dead_man_check.dart :: import 'package:sentry_flutter/sentry_flutter.dart' show SentryLevel;
sentryImport lib/features/integrations/application/tp_writeback_service.dart :: import 'package:sentry_flutter/sentry_flutter.dart';
sentryImport lib/features/macro_dashboard/application/dashboard_transient_telemetry.dart :: import 'package:sentry_flutter/sentry_flutter.dart';
sentryImport lib/features/nutrition_plan/presentation/providers/macro_targets_controller.dart :: import 'package:sentry_flutter/sentry_flutter.dart';
sentryImport lib/shared/services/performance_telemetry.dart :: import 'package:sentry_flutter/sentry_flutter.dart';
sentryImport lib/shared/services/sentry/sentry_reporter.dart :: import 'package:sentry_flutter/sentry_flutter.dart' show SentryLevel;
unreportedCatch lib/features/activities/data/activities_repository.dart :: } catch (_) {
unreportedCatch lib/features/activities/presentation/providers/activities_controller.dart :: } catch (_) {}
unreportedCatch lib/features/activities/presentation/providers/activities_controller.dart :: } catch (_) {}
unreportedCatch lib/features/activities/presentation/widgets/activity_card.dart :: } catch (_) {
unreportedCatch lib/features/activities/presentation/widgets/calendar_date_indicators.dart :: } catch (e) {
unreportedCatch lib/features/ai_coach/data/ai_coach_chat_repository.dart :: } catch (e) {
unreportedCatch lib/features/ai_coach/domain/ai_coach_message.dart :: } catch (_) {
unreportedCatch lib/features/ai_coach/domain/ai_coach_ui_part.dart :: } catch (_) {
unreportedCatch lib/features/ai_coach/presentation/providers/ai_coach_banner_providers.dart :: } catch (_) {
unreportedCatch lib/features/barcode_scanning/presentation/screens/add_food_screen.dart :: } catch (e) {
unreportedCatch lib/features/barcode_scanning/presentation/screens/add_food_screen.dart :: } catch (e) {
unreportedCatch lib/features/barcode_scanning/presentation/screens/add_food_screen.dart :: } on ProductDetailException catch (e) {
unreportedCatch lib/features/barcode_scanning/presentation/screens/add_food_screen.dart :: } on SearchException catch (e) {
unreportedCatch lib/features/barcode_scanning/presentation/screens/barcode_scanner_screen.dart :: } catch (e) {
unreportedCatch lib/features/barcode_scanning/presentation/screens/barcode_scanner_screen.dart :: } on MobileScannerException catch (_) {
unreportedCatch lib/features/barcode_scanning/presentation/screens/barcode_scanner_screen.dart :: } on MobileScannerException catch (_) {
unreportedCatch lib/features/calendar/domain/event_subtype.dart :: } catch (e) {
unreportedCatch lib/features/carb_loading/application/food_import_service.dart :: } catch (e) {
unreportedCatch lib/features/carb_loading/application/food_selection_service.dart :: } catch (_) {}
unreportedCatch lib/features/carb_loading/domain/carb_foods_list.dart :: } catch (e) {
unreportedCatch lib/features/carb_loading/domain/meal_type.dart :: } catch (_) {
unreportedCatch lib/features/carb_loading/presentation/providers/carb_loading_food_selection_controller.dart :: } catch (e) {
unreportedCatch lib/features/carb_loading/presentation/providers/carb_nudge_coordinator.dart :: } catch (e, stackTrace) {
unreportedCatch lib/features/carb_loading/presentation/screens/carb_loading_day_detail_page.dart :: } catch (_) {}
unreportedCatch lib/features/carb_loading/presentation/screens/carb_loading_food_selection_screen.dart :: } catch (e, stackTrace) {
unreportedCatch lib/features/carb_loading/presentation/screens/carb_loading_food_selection_screen.dart :: } catch (e) {
unreportedCatch lib/features/carb_loading/presentation/screens/carb_loading_food_selection_screen.dart :: } catch (e) {
unreportedCatch lib/features/carb_loading/presentation/screens/carb_loading_food_selection_screen.dart :: } catch (e) {
unreportedCatch lib/features/carb_loading/presentation/screens/carb_loading_food_selection_screen.dart :: } catch (e) {
unreportedCatch lib/features/carb_loading/presentation/screens/carb_loading_protocol_selection_screen.dart :: } catch (_) {}
unreportedCatch lib/features/carb_loading/presentation/screens/create_custom_carb_loading_food_screen.dart :: } catch (e) {
unreportedCatch lib/features/coach_mode/data/coach_repository.dart :: } catch (_) {
unreportedCatch lib/features/coach_mode/presentation/providers/athlete_detail_controller.dart :: } catch (e) {
unreportedCatch lib/features/coach_mode/presentation/providers/athlete_detail_controller.dart :: } catch (e) {
unreportedCatch lib/features/coach_mode/presentation/providers/athlete_detail_controller.dart :: } catch (e) {
unreportedCatch lib/features/coach_mode/presentation/providers/coach_activity_detail_controller.dart :: } catch (_) {
unreportedCatch lib/features/coach_mode/presentation/providers/coach_activity_detail_controller.dart :: } catch (_) {
unreportedCatch lib/features/coach_mode/presentation/providers/coach_activity_detail_controller.dart :: } catch (_) {
unreportedCatch lib/features/coach_mode/presentation/providers/coach_activity_detail_controller.dart :: } catch (error, stackTrace) {
unreportedCatch lib/features/coach_mode/presentation/providers/coach_chat_controller.dart :: } catch (e) {
unreportedCatch lib/features/coach_mode/presentation/providers/coach_chat_controller.dart :: } catch (e) {
unreportedCatch lib/features/coach_mode/presentation/providers/coach_dashboard_controller.dart :: } catch (e) {
unreportedCatch lib/features/coach_mode/presentation/providers/coach_dashboard_controller.dart :: } catch (e) {
unreportedCatch lib/features/coach_mode/presentation/providers/coach_dashboard_controller.dart :: } catch (e) {
unreportedCatch lib/features/coach_mode/presentation/providers/coach_dashboard_controller.dart :: } catch (e) {
unreportedCatch lib/features/coach_mode/presentation/providers/coach_directory_controller.dart :: } catch (e) {
unreportedCatch lib/features/coach_mode/presentation/providers/coach_directory_controller.dart :: } catch (e) {
unreportedCatch lib/features/coach_mode/presentation/providers/coach_reports_controller.dart :: } catch (_) {
unreportedCatch lib/features/coach_mode/presentation/providers/coach_reports_controller.dart :: } catch (_) {
unreportedCatch lib/features/coach_mode/presentation/providers/invite_athlete_controller.dart :: } catch (e, stack) {
unreportedCatch lib/features/coach_mode/presentation/providers/my_coaches_controller.dart :: } catch (e) {
unreportedCatch lib/features/coach_mode/presentation/providers/my_coaches_controller.dart :: } catch (e) {
unreportedCatch lib/features/coach_mode/presentation/providers/my_coaches_controller.dart :: } catch (e) {
unreportedCatch lib/features/coach_mode/presentation/widgets/activity_coach_feedback_widget.dart :: } catch (e) {
unreportedCatch lib/features/coach_mode/presentation/widgets/portal_athlete_detail_panel.dart :: } catch (e) {
unreportedCatch lib/features/coach_mode/presentation/widgets/portal_athlete_detail_panel.dart :: } catch (e) {
unreportedCatch lib/features/coach_mode/presentation/widgets/portal_athlete_detail_panel.dart :: } catch (e) {
unreportedCatch lib/features/coach_mode/presentation/widgets/portal_athlete_profile_form.dart :: } catch (e) {
unreportedCatch lib/features/coach_mode/presentation/widgets/portal_nutrition_targets_form.dart :: } catch (e) {
unreportedCatch lib/features/coach_mode/presentation/widgets/portal_nutrition_targets_form.dart :: } catch (e) {
unreportedCatch lib/features/coach_mode/presentation/widgets/portal_sidebar.dart :: } catch (_) {
unreportedCatch lib/features/coach_mode/presentation/widgets/portal_sidebar.dart :: } catch (_) {
unreportedCatch lib/features/content/application/content_service.dart :: } catch (_) {
unreportedCatch lib/features/content/application/content_service.dart :: } catch (_) {
unreportedCatch lib/features/content/application/content_service.dart :: } catch (e) {
unreportedCatch lib/features/daily_macros/application/daily_macro_service.dart :: } on FormatException {
unreportedCatch lib/features/daily_macros/data/daily_macro_targets_repository.dart :: } catch (_) {
unreportedCatch lib/features/daily_macros/presentation/providers/daily_macros_controller.dart :: } catch (e) {
unreportedCatch lib/features/daily_macros/presentation/providers/daily_macros_controller.dart :: } on DailyMacroCalculationException catch (e) {
unreportedCatch lib/features/education/presentation/screens/education_screen.dart :: } catch (_) {}
unreportedCatch lib/features/education/presentation/screens/video_player_screen.dart :: } catch (_) {}
unreportedCatch lib/features/education/presentation/screens/video_player_screen.dart :: } catch (_) {}
unreportedCatch lib/features/education/presentation/screens/video_player_screen.dart :: } catch (e) {
unreportedCatch lib/features/events/application/events_service.dart :: } catch (_) {
unreportedCatch lib/features/events/application/public_events_service.dart :: } catch (e) {
unreportedCatch lib/features/events/presentation/providers/events_controller.dart :: } catch (_) {
unreportedCatch lib/features/events/presentation/screens/event_detail_screen.dart :: } catch (e) {
unreportedCatch lib/features/events/presentation/screens/event_form_screen.dart :: } catch (e) {
unreportedCatch lib/features/events/presentation/screens/event_form_screen.dart :: } catch (e) {
unreportedCatch lib/features/events/presentation/screens/event_form_screen.dart :: } catch (e) {
unreportedCatch lib/features/events/presentation/screens/events_list_screen.dart :: } catch (e) {
unreportedCatch lib/features/events/presentation/widgets/event_action_buttons_card.dart :: } catch (e) {
unreportedCatch lib/features/formula_kit/application/coach_insight_controller.dart :: } catch (e) {
unreportedCatch lib/features/formula_kit/application/coach_insight_controller.dart :: } catch (e) {
unreportedCatch lib/features/formula_kit/application/formula_conflict_json.dart :: } catch (_) {
unreportedCatch lib/features/formula_kit/application/formula_library_controller.dart :: } catch (_) {
unreportedCatch lib/features/formula_kit/application/formula_library_controller.dart :: } catch (_) {}
unreportedCatch lib/features/formula_kit/application/formula_library_controller.dart :: } catch (_) {}
unreportedCatch lib/features/formula_kit/domain/personal_formula.dart :: } catch (_) {
unreportedCatch lib/features/formula_kit/domain/personal_formula.dart :: } catch (_) {
unreportedCatch lib/features/formula_kit/presentation/screens/formula_detail_screen.dart :: } catch (e) {
unreportedCatch lib/features/formula_kit/presentation/screens/formula_editor_screen.dart :: } catch (err) {
unreportedCatch lib/features/formula_kit/presentation/widgets/pin_conflict_card_state.dart :: } catch (e) {
unreportedCatch lib/features/formula_kit/presentation/widgets/pin_conflict_card_state.dart :: } catch (e) {
unreportedCatch lib/features/formula_kit/presentation/widgets/pin_toggle.dart :: } catch (e) {
unreportedCatch lib/features/fuel_timeline/presentation/widgets/energy_breakdown_sheet.dart :: } catch (_) {}
unreportedCatch lib/features/integrations/application/final_surge_sync_service.dart :: } catch (e) {
unreportedCatch lib/features/integrations/application/final_surge_sync_service.dart :: } catch (e) {
unreportedCatch lib/features/integrations/application/final_surge_sync_service.dart :: } catch (e) {
unreportedCatch lib/features/integrations/application/final_surge_sync_service.dart :: } catch (e) {
unreportedCatch lib/features/integrations/application/final_surge_sync_service.dart :: } on NetworkException catch (e) {
unreportedCatch lib/features/integrations/application/final_surge_sync_service.dart :: } on NetworkException catch (e) {
unreportedCatch lib/features/integrations/application/final_surge_sync_service.dart :: } on TokenExpiredException {
unreportedCatch lib/features/integrations/application/final_surge_sync_service.dart :: } on TokenExpiredException {
unreportedCatch lib/features/integrations/application/final_surge_sync_service.dart :: } on TokenExpiredException {
unreportedCatch lib/features/integrations/application/final_surge_sync_service.dart :: } on TokenRefreshException catch (e) {
unreportedCatch lib/features/integrations/application/final_surge_sync_service.dart :: } on TokenRefreshException catch (e) {
unreportedCatch lib/features/integrations/application/final_surge_transformer.dart :: } catch (e) {
unreportedCatch lib/features/integrations/application/garmin_oauth_service.dart :: } catch (e) {
unreportedCatch lib/features/integrations/application/garmin_oauth_service.dart :: } catch (e) {
unreportedCatch lib/features/integrations/application/integration_sync_coordinator.dart :: } catch (_) {
unreportedCatch lib/features/integrations/application/integration_sync_coordinator.dart :: } catch (_) {
unreportedCatch lib/features/integrations/application/raw_retention_dead_man_check.dart :: } catch (_) {
unreportedCatch lib/features/integrations/application/runna_sync_service.dart :: } catch (e) {
unreportedCatch lib/features/integrations/application/runna_sync_service.dart :: } on IntegrationApiException catch (e) {
unreportedCatch lib/features/integrations/application/runna_sync_service.dart :: } on NetworkException catch (e) {
unreportedCatch lib/features/integrations/application/synced_workout_analytics.dart :: } catch (_) {}
unreportedCatch lib/features/integrations/application/tp_writeback_service.dart :: } catch (_) {
unreportedCatch lib/features/integrations/application/tp_writeback_service.dart :: } catch (e, st) {
unreportedCatch lib/features/integrations/application/tp_writeback_service.dart :: } catch (e, st) {
unreportedCatch lib/features/integrations/application/tp_writeback_service.dart :: } catch (e, st) {
unreportedCatch lib/features/integrations/application/tp_writeback_service.dart :: } catch (e, st) {
unreportedCatch lib/features/integrations/application/tp_writeback_service.dart :: } catch (e, st) {
unreportedCatch lib/features/integrations/application/tp_writeback_service.dart :: } catch (e, st) {
unreportedCatch lib/features/integrations/application/tp_writeback_service.dart :: } catch (e, st) {
unreportedCatch lib/features/integrations/application/tp_writeback_service.dart :: } catch (e, st) {
unreportedCatch lib/features/integrations/application/tp_writeback_service.dart :: } on IntegrationApiException catch (e) {
unreportedCatch lib/features/integrations/application/tp_writeback_service.dart :: } on IntegrationApiException catch (e) {
unreportedCatch lib/features/integrations/application/tp_writeback_service.dart :: } on IntegrationApiException catch (e) {
unreportedCatch lib/features/integrations/application/tp_writeback_service.dart :: } on TokenExpiredException {
unreportedCatch lib/features/integrations/application/tp_writeback_service.dart :: } on TokenExpiredException {
unreportedCatch lib/features/integrations/application/tp_writeback_service.dart :: } on TokenExpiredException {
unreportedCatch lib/features/integrations/application/training_peaks_oauth_service.dart :: } catch (e) {
unreportedCatch lib/features/integrations/application/training_peaks_oauth_service.dart :: } on TrainingPeaksApiException catch (e) {
unreportedCatch lib/features/integrations/application/training_peaks_oauth_service.dart :: } on TrainingPeaksApiException catch (e) {
unreportedCatch lib/features/integrations/application/training_peaks_sync_service.dart :: } catch (_) {
unreportedCatch lib/features/integrations/application/training_peaks_sync_service.dart :: } catch (e) {
unreportedCatch lib/features/integrations/application/training_peaks_sync_service.dart :: } catch (e) {
unreportedCatch lib/features/integrations/application/training_peaks_sync_service.dart :: } catch (e) {
unreportedCatch lib/features/integrations/application/training_peaks_sync_service.dart :: } catch (e) {
unreportedCatch lib/features/integrations/application/training_peaks_sync_service.dart :: } catch (e) {
unreportedCatch lib/features/integrations/application/training_peaks_sync_service.dart :: } catch (e) {
unreportedCatch lib/features/integrations/application/training_peaks_sync_service.dart :: } catch (e) {
unreportedCatch lib/features/integrations/application/training_peaks_sync_service.dart :: } catch (e) {
unreportedCatch lib/features/integrations/application/training_peaks_sync_service.dart :: } on TrainingPeaksTokenExpiredException {
unreportedCatch lib/features/integrations/application/training_peaks_sync_service.dart :: } on TrainingPeaksTokenExpiredException {
unreportedCatch lib/features/integrations/application/training_peaks_sync_service.dart :: } on TrainingPeaksTokenExpiredException {
unreportedCatch lib/features/integrations/application/training_peaks_sync_service.dart :: } on TrainingPeaksTokenExpiredException {
unreportedCatch lib/features/integrations/application/training_peaks_sync_service.dart :: } on TrainingPeaksTokenExpiredException {
unreportedCatch lib/features/integrations/application/training_peaks_sync_service.dart :: } on TrainingPeaksTokenExpiredException {
unreportedCatch lib/features/integrations/application/training_peaks_sync_service.dart :: } on TrainingPeaksTokenExpiredException {
unreportedCatch lib/features/integrations/application/training_peaks_sync_service.dart :: } on TrainingPeaksTokenExpiredException {
unreportedCatch lib/features/integrations/application/training_peaks_transformer.dart :: } catch (e) {
unreportedCatch lib/features/integrations/application/vdot_oauth_service.dart :: } catch (_) {
unreportedCatch lib/features/integrations/application/vdot_sync_service.dart :: } catch (e) {
unreportedCatch lib/features/integrations/application/vdot_sync_service.dart :: } on NetworkException catch (e) {
unreportedCatch lib/features/integrations/application/vdot_sync_service.dart :: } on TokenExpiredException {
unreportedCatch lib/features/integrations/application/vdot_sync_service.dart :: } on TokenRefreshException catch (e) {
unreportedCatch lib/features/integrations/application/vdot_transformer.dart :: } catch (_) {
unreportedCatch lib/features/integrations/data/integrations_repository.dart :: } catch (_) {
unreportedCatch lib/features/integrations/data/integrations_repository.dart :: } catch (_) {
unreportedCatch lib/features/integrations/data/integrations_repository.dart :: } catch (e) {
unreportedCatch lib/features/integrations/data/training_peaks_api_client.dart :: } catch (e) {
unreportedCatch lib/features/integrations/data/vdot_api_client.dart :: } catch (_) {
unreportedCatch lib/features/integrations/domain/athlete_zones.dart :: } catch (_) {
unreportedCatch lib/features/integrations/domain/integration.dart :: } catch (_) {
unreportedCatch lib/features/integrations/presentation/providers/connect_training_controller.dart :: } catch (_) {
unreportedCatch lib/features/integrations/presentation/providers/connect_training_controller.dart :: } catch (_) {
unreportedCatch lib/features/integrations/presentation/providers/connect_training_controller.dart :: } catch (_) {
unreportedCatch lib/features/integrations/presentation/providers/connect_training_controller.dart :: } catch (_) {}
unreportedCatch lib/features/integrations/presentation/providers/connect_training_controller.dart :: } catch (_) {}
unreportedCatch lib/features/integrations/presentation/providers/connect_training_controller.dart :: } catch (_) {}
unreportedCatch lib/features/integrations/presentation/providers/connect_training_controller.dart :: } catch (_) {}
unreportedCatch lib/features/integrations/presentation/providers/connect_training_controller.dart :: } catch (_) {}
unreportedCatch lib/features/integrations/presentation/providers/connect_training_controller.dart :: } catch (_) {}
unreportedCatch lib/features/integrations/presentation/providers/connect_training_controller.dart :: } catch (_) {}
unreportedCatch lib/features/integrations/presentation/providers/connect_training_controller.dart :: } catch (_) {}
unreportedCatch lib/features/integrations/presentation/providers/connect_training_controller.dart :: } catch (e, st) {
unreportedCatch lib/features/integrations/presentation/providers/connect_training_controller.dart :: } catch (e, stackTrace) {
unreportedCatch lib/features/integrations/presentation/providers/connect_training_controller.dart :: } catch (e, stackTrace) {
unreportedCatch lib/features/integrations/presentation/providers/connect_training_controller.dart :: } catch (e, stackTrace) {
unreportedCatch lib/features/integrations/presentation/providers/connect_training_controller.dart :: } catch (e, stackTrace) {
unreportedCatch lib/features/integrations/presentation/providers/connect_training_controller.dart :: } catch (e, stackTrace) {
unreportedCatch lib/features/integrations/presentation/providers/connect_training_controller.dart :: } catch (e, stackTrace) {
unreportedCatch lib/features/integrations/presentation/providers/connect_training_controller.dart :: } catch (e, stackTrace) {
unreportedCatch lib/features/integrations/presentation/providers/connect_training_controller.dart :: } catch (e, stackTrace) {
unreportedCatch lib/features/integrations/presentation/providers/connect_training_controller.dart :: } catch (e, stackTrace) {
unreportedCatch lib/features/integrations/presentation/providers/connect_training_controller.dart :: } catch (e, stackTrace) {
unreportedCatch lib/features/integrations/presentation/providers/connect_training_controller.dart :: } catch (e, stackTrace) {
unreportedCatch lib/features/integrations/presentation/providers/connect_training_controller.dart :: } catch (e, stackTrace) {
unreportedCatch lib/features/integrations/presentation/providers/connect_training_controller.dart :: } catch (e, stackTrace) {
unreportedCatch lib/features/integrations/presentation/providers/connect_training_controller.dart :: } catch (e, stackTrace) {
unreportedCatch lib/features/integrations/presentation/providers/connect_training_controller.dart :: } catch (e) {
unreportedCatch lib/features/integrations/presentation/providers/connect_training_controller.dart :: } catch (e) {
unreportedCatch lib/features/integrations/presentation/providers/connect_training_controller.dart :: } catch (e) {
unreportedCatch lib/features/integrations/presentation/providers/connect_training_controller.dart :: } catch (e) {
unreportedCatch lib/features/integrations/presentation/providers/connect_training_controller.dart :: } on FormatException catch (e) {
unreportedCatch lib/features/integrations/presentation/providers/integrations_providers.dart :: } catch (_) {
unreportedCatch lib/features/macro_dashboard/presentation/providers/macro_dashboard_providers.dart :: } catch (_) {
unreportedCatch lib/features/macro_dashboard/presentation/providers/macro_dashboard_providers.dart :: } catch (_) {
unreportedCatch lib/features/macro_dashboard/presentation/screens/macro_dashboard_screen.dart :: } catch (_) {
unreportedCatch lib/features/macro_dashboard/presentation/screens/macro_dashboard_screen.dart :: } catch (_) {
unreportedCatch lib/features/macro_dashboard/presentation/screens/macro_dashboard_screen.dart :: } catch (_) {
unreportedCatch lib/features/macro_dashboard/presentation/screens/macro_dashboard_screen.dart :: } catch (_) {
unreportedCatch lib/features/macro_dashboard/presentation/screens/macro_dashboard_screen.dart :: } catch (e) {
unreportedCatch lib/features/macro_dashboard/presentation/screens/macro_dashboard_screen.dart :: } catch (e) {
unreportedCatch lib/features/macro_dashboard/presentation/screens/macro_dashboard_screen.dart :: } catch (e) {
unreportedCatch lib/features/macro_dashboard/presentation/screens/macro_dashboard_screen.dart :: } on BrickCreationException catch (e) {
unreportedCatch lib/features/macro_dashboard/presentation/screens/macro_dashboard_screen.dart :: } on BrickUngroupException catch (e) {
unreportedCatch lib/features/macro_dashboard/presentation/screens/macro_dashboard_screen.dart :: } on BrickValidationException catch (e) {
unreportedCatch lib/features/meal_planning/application/meal_plan_controller.dart :: } on VanaException catch (e) {
unreportedCatch lib/features/meal_planning/data/meal_plan_repository.dart :: } catch (_) {
unreportedCatch lib/features/meal_planning/data/meal_plan_repository.dart :: } catch (_) {
unreportedCatch lib/features/meal_planning/data/meal_plan_repository.dart :: } on FormatException {
unreportedCatch lib/features/meal_planning/data/user_memory_repository.dart :: } on FormatException {
unreportedCatch lib/features/meal_planning/data/vana_transport.dart :: } on FormatException {
unreportedCatch lib/features/meal_planning/domain/day_plan.dart :: } on FormatException {
unreportedCatch lib/features/meal_planning/domain/vana_part.dart :: } on FormatException {
unreportedCatch lib/features/meal_planning/domain/vana_part.dart :: } on TypeError {
unreportedCatch lib/features/meal_planning/domain/vana_stream_event.dart :: } on FormatException {
unreportedCatch lib/features/meal_planning/domain/wire_record.dart :: } on FormatException {
unreportedCatch lib/features/meal_planning/presentation/screens/cooking_mode_screen.dart :: } on Exception {
unreportedCatch lib/features/meal_planning/presentation/screens/cooking_mode_screen.dart :: } on Exception {
unreportedCatch lib/features/meal_planning/presentation/screens/meal_detail_screen.dart :: } on Exception {
unreportedCatch lib/features/meal_planning/presentation/screens/meal_detail_screen.dart :: } on Exception {
unreportedCatch lib/features/meal_planning/presentation/screens/meal_detail_screen.dart :: } on Exception {
unreportedCatch lib/features/meal_planning/presentation/screens/meal_detail_screen.dart :: } on NeedsConnectionException {
unreportedCatch lib/features/meal_planning/presentation/screens/meal_detail_screen.dart :: } on NeedsConnectionException {
unreportedCatch lib/features/meal_planning/presentation/screens/plan_tab.dart :: } on Exception {
unreportedCatch lib/features/meal_planning/presentation/screens/plan_tab.dart :: } on Exception {
unreportedCatch lib/features/meal_planning/presentation/screens/plan_tab.dart :: } on NeedsConnectionException {
unreportedCatch lib/features/meal_planning/presentation/screens/swap_meal_screen.dart :: } on Exception {
unreportedCatch lib/features/meal_planning/presentation/screens/swap_meal_screen.dart :: } on NeedsConnectionException {
unreportedCatch lib/features/meal_planning/presentation/screens/vana_browse_screen.dart :: } on Exception {
unreportedCatch lib/features/meal_planning/presentation/screens/vana_browse_screen.dart :: } on NeedsConnectionException {
unreportedCatch lib/features/meal_planning/presentation/screens/vana_chat_screen.dart :: } catch (e) {
unreportedCatch lib/features/meal_planning/presentation/screens/vana_chat_screen.dart :: } on Exception {
unreportedCatch lib/features/meal_planning/presentation/screens/vana_chat_screen.dart :: } on Exception {
unreportedCatch lib/features/meal_planning/presentation/screens/vana_chat_screen.dart :: } on Exception {
unreportedCatch lib/features/meal_planning/presentation/screens/vana_chat_screen.dart :: } on Exception {
unreportedCatch lib/features/meal_planning/presentation/screens/vana_chat_screen.dart :: } on NeedsConnectionException {
unreportedCatch lib/features/meal_planning/presentation/screens/vana_chat_screen.dart :: } on NeedsConnectionException {
unreportedCatch lib/features/meal_planning/presentation/screens/vana_chat_screen.dart :: } on VanaAttachPickFailed {
unreportedCatch lib/features/meal_planning/presentation/widgets/vana_mic_button.dart :: } catch (_) {
unreportedCatch lib/features/nutrition_plan/application/brick_macro_service.dart :: } catch (_) {
unreportedCatch lib/features/nutrition_plan/application/client_plan/client_food_pool_service.dart :: } catch (_) {}
unreportedCatch lib/features/nutrition_plan/application/client_plan/client_plan_service.dart :: } catch (_) {
unreportedCatch lib/features/nutrition_plan/application/client_plan/client_plan_service.dart :: } catch (_) {}
unreportedCatch lib/features/nutrition_plan/application/macro_generation_service.dart :: } catch (_) {
unreportedCatch lib/features/nutrition_plan/data/nutrition_plan_repository.dart :: } catch (_) {
unreportedCatch lib/features/nutrition_plan/data/template_foods_repository.dart :: } catch (_) {
unreportedCatch lib/features/nutrition_plan/data/template_foods_repository.dart :: } catch (_) {
unreportedCatch lib/features/nutrition_plan/data/transparency_feedback_store.dart :: } catch (_) {
unreportedCatch lib/features/nutrition_plan/domain/nutrition_target_overrides.dart :: } catch (_) {
unreportedCatch lib/features/nutrition_plan/domain/solver_food.dart :: } catch (_) {}
unreportedCatch lib/features/nutrition_plan/presentation/providers/activity_detail_controller.dart :: } catch (_) {
unreportedCatch lib/features/nutrition_plan/presentation/providers/activity_detail_controller.dart :: } catch (e) {
unreportedCatch lib/features/nutrition_plan/presentation/providers/activity_detail_controller.dart :: } catch (e) {
unreportedCatch lib/features/nutrition_plan/presentation/providers/activity_detail_controller.dart :: } catch (e) {
unreportedCatch lib/features/nutrition_plan/presentation/providers/cycling_input_controller.dart :: } catch (e) {
unreportedCatch lib/features/nutrition_plan/presentation/providers/cycling_input_controller.dart :: } catch (e) {
unreportedCatch lib/features/nutrition_plan/presentation/providers/macro_targets_controller.dart :: } catch (e) {
unreportedCatch lib/features/nutrition_plan/presentation/providers/night_before_nudge_coordinator.dart :: } catch (e, stackTrace) {
unreportedCatch lib/features/nutrition_plan/presentation/providers/running_input_controller.dart :: } catch (e) {
unreportedCatch lib/features/nutrition_plan/presentation/providers/running_input_controller.dart :: } catch (e) {
unreportedCatch lib/features/nutrition_plan/presentation/providers/swap_food_controller.dart :: } catch (_) {
unreportedCatch lib/features/nutrition_plan/presentation/providers/swap_food_controller.dart :: } catch (_) {}
unreportedCatch lib/features/nutrition_plan/presentation/providers/swimming_input_controller.dart :: } catch (e) {
unreportedCatch lib/features/nutrition_plan/presentation/providers/swimming_input_controller.dart :: } catch (e) {
unreportedCatch lib/features/nutrition_plan/presentation/screens/activity_detail_screen.dart :: } catch (e) {
unreportedCatch lib/features/nutrition_plan/presentation/screens/activity_detail_screen.dart :: } catch (e) {
unreportedCatch lib/features/nutrition_plan/presentation/screens/activity_detail_screen.dart :: } catch (e) {
unreportedCatch lib/features/nutrition_plan/presentation/screens/adjust_macros_screen.dart :: } catch (e) {
unreportedCatch lib/features/nutrition_plan/presentation/screens/fuel_log_screen.dart :: } catch (_) {
unreportedCatch lib/features/nutrition_plan/presentation/screens/swap_food_screen.dart :: } catch (e, stackTrace) {
unreportedCatch lib/features/nutrition_plan/presentation/screens/swap_food_screen.dart :: } catch (e) {
unreportedCatch lib/features/nutrition_plan/presentation/screens/swap_food_screen.dart :: } catch (e) {
unreportedCatch lib/features/nutrition_plan/presentation/screens/swap_food_screen.dart :: } catch (e) {
unreportedCatch lib/features/nutrition_plan/presentation/screens/swap_food_screen.dart :: } catch (e) {
unreportedCatch lib/features/nutrition_plan/presentation/screens/swap_food_screen.dart :: } catch (e) {
unreportedCatch lib/features/nutrition_plan/presentation/screens/swap_food_screen.dart :: } catch (e) {
unreportedCatch lib/features/nutrition_plan/presentation/widgets/activity_detail/nutrient_full_story_section.dart :: } catch (_) {}
unreportedCatch lib/features/nutrition_plan/presentation/widgets/adjust_macros/edit_macros_dialog_widget.dart :: } catch (e) {
unreportedCatch lib/features/onboarding/application/onboarding_snapshot_service.dart :: } catch (_) {
unreportedCatch lib/features/onboarding/application/onboarding_snapshot_service.dart :: } catch (e, stackTrace) {
unreportedCatch lib/features/onboarding/presentation/providers/onboarding_preview_providers.dart :: } catch (_) {
unreportedCatch lib/features/onboarding/presentation/providers/onboarding_preview_providers.dart :: } catch (_) {
unreportedCatch lib/features/onboarding/presentation/screens/allergies_screen.dart :: } catch (e) {
unreportedCatch lib/features/onboarding/presentation/screens/cycling_details_screen.dart :: } catch (e) {
unreportedCatch lib/features/onboarding/presentation/screens/daily_plan_preview_screen.dart :: } catch (_) {
unreportedCatch lib/features/onboarding/presentation/screens/dietary_preference_screen.dart :: } catch (e) {
unreportedCatch lib/features/onboarding/presentation/screens/goals_screen.dart :: } catch (_) {
unreportedCatch lib/features/onboarding/presentation/screens/onboarding_pageview_screen.dart :: } catch (_) {
unreportedCatch lib/features/onboarding/presentation/screens/onboarding_pageview_screen.dart :: } catch (_) {
unreportedCatch lib/features/onboarding/presentation/screens/pitfalls_screen.dart :: } catch (_) {
unreportedCatch lib/features/onboarding/presentation/screens/plan_reveal_screen.dart :: } catch (_) {
unreportedCatch lib/features/onboarding/presentation/screens/plan_reveal_screen.dart :: } catch (_) {
unreportedCatch lib/features/onboarding/presentation/screens/running_details_screen.dart :: } catch (e) {
unreportedCatch lib/features/onboarding/presentation/screens/sports_selection_screen.dart :: } catch (_) {
unreportedCatch lib/features/onboarding/presentation/screens/swimming_details_screen.dart :: } catch (e) {
unreportedCatch lib/features/personal_templates/domain/personal_template.dart :: } catch (_) {
unreportedCatch lib/features/personal_templates/domain/personal_template.dart :: } catch (_) {
unreportedCatch lib/features/race_checklist/presentation/screens/race_checklist_screen.dart :: } catch (e) {
unreportedCatch lib/features/recipes/data/repositories/recipe_repository.dart :: } catch (_) {
unreportedCatch lib/features/recipes/presentation/screens/recipes_screen.dart :: } catch (e) {
unreportedCatch lib/features/settings/presentation/providers/settings_controller.dart :: } catch (e) {
unreportedCatch lib/features/settings/presentation/screens/coach_connection_screen.dart :: } catch (_) {
unreportedCatch lib/features/settings/presentation/screens/coach_connection_screen.dart :: } catch (_) {
unreportedCatch lib/features/settings/presentation/screens/coach_connection_screen.dart :: } catch (_) {
unreportedCatch lib/features/settings/presentation/screens/connected_apps_screen.dart :: } catch (_) {
unreportedCatch lib/features/settings/presentation/screens/connected_apps_screen.dart :: } catch (_) {
unreportedCatch lib/features/settings/presentation/screens/connected_apps_screen.dart :: } catch (e) {
unreportedCatch lib/features/settings/presentation/screens/debug_screen.dart :: } catch (e, stackTrace) {
unreportedCatch lib/features/settings/presentation/screens/food_preferences_screen.dart :: } catch (e) {
unreportedCatch lib/features/settings/presentation/screens/food_settings_consolidated_screen.dart :: } catch (e) {
unreportedCatch lib/features/settings/presentation/screens/nutrition_profile_screen.dart :: } catch (_) {
unreportedCatch lib/features/settings/presentation/screens/nutrition_profile_screen.dart :: } catch (_) {
unreportedCatch lib/features/settings/presentation/screens/nutrition_profile_screen.dart :: } catch (_) {
unreportedCatch lib/features/settings/presentation/screens/nutrition_profile_screen.dart :: } catch (e) {
unreportedCatch lib/features/settings/presentation/screens/nutrition_targets_screen.dart :: } catch (_) {
unreportedCatch lib/features/settings/presentation/screens/nutrition_targets_screen.dart :: } catch (e) {
unreportedCatch lib/features/settings/presentation/screens/preferences_screen.dart :: } catch (e) {
unreportedCatch lib/features/sharing/application/email_service.dart :: } catch (e) {
unreportedCatch lib/features/sharing/presentation/providers/share_form_controller.dart :: } catch (e) {
unreportedCatch lib/features/user_foods/data/user_foods_repository.dart :: } catch (_) {
