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
unreportedCatch lib/features/integrations/application/tp_writeback_service.dart :: } on IntegrationApiException catch (e) {  :: delegates to handleApiException, which classifies every status through Report (403 degraded, 404 note, else degraded); the guard only sees the block text
unreportedCatch lib/features/integrations/application/tp_writeback_service.dart :: } on IntegrationApiException catch (e) {  :: same as above (feedback push)
unreportedCatch lib/features/integrations/application/tp_writeback_service.dart :: } on IntegrationApiException catch (e) {  :: same as above (plan removal)

## baseline

printInCatch lib/features/ai_coach/data/ai_coach_chat_repository.dart :: } catch (e) {
printInCatch lib/features/ai_credits/application/credits_controller.dart :: } catch (e) {
printInCatch lib/features/ai_credits/application/purchase_controller.dart :: } catch (e) {
printInCatch lib/features/ai_credits/data/credits_repository.dart :: } catch (e) {
printInCatch lib/features/ai_credits/data/credits_repository.dart :: } catch (e) {
printInCatch lib/features/ai_credits/data/credits_repository.dart :: } catch (e) {
printInCatch lib/features/ai_credits/data/credits_repository.dart :: } catch (e) {
printInCatch lib/features/carb_loading/presentation/screens/carb_loading_food_selection_screen.dart :: } catch (e, stackTrace) {
printInCatch lib/features/carb_loading/presentation/screens/carb_loading_food_selection_screen.dart :: } catch (e) {
printInCatch lib/features/carb_loading/presentation/screens/carb_loading_food_selection_screen.dart :: } catch (e) {
printInCatch lib/features/daily_macros/application/daily_macro_service.dart :: } catch (e) {
printInCatch lib/features/daily_macros/application/daily_macro_service.dart :: } catch (e) {
printInCatch lib/features/formula_kit/application/coach_insight_controller.dart :: } catch (e) {
printInCatch lib/features/formula_kit/application/coach_insight_controller.dart :: } catch (e) {
printInCatch lib/features/formula_kit/data/ai_coach_client.dart :: } catch (e) {
printInCatch lib/features/formula_kit/data/ai_coach_client.dart :: } on FunctionException catch (e) {
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
printInCatch lib/features/meal_logging/application/meal_ai_service.dart :: } catch (e) {
printInCatch lib/features/meal_logging/application/meal_ai_service.dart :: } catch (e) {
printInCatch lib/features/meal_logging/application/meal_ai_service.dart :: } catch (e) {
printInCatch lib/features/meal_logging/application/meal_ai_service.dart :: } on StorageException catch (e) {
printInCatch lib/features/nutrition_plan/presentation/screens/swap_food_screen.dart :: } catch (e, stackTrace) {
printInCatch lib/features/nutrition_plan/presentation/screens/swap_food_screen.dart :: } catch (e) {
printInCatch lib/features/nutrition_plan/presentation/screens/swap_food_screen.dart :: } catch (e) {
printInCatch lib/features/settings/presentation/screens/debug_screen.dart :: } catch (e, stackTrace) {
printInCatch lib/features/subscription/application/subscription_status_provider.dart :: } catch (e) {
printInCatch lib/shared/database/app_database.dart :: } catch (closeError) {
printInCatch lib/shared/services/notification_service.dart :: } catch (e) {
printInCatch lib/shared/services/notification_service.dart :: } catch (e) {
printInCatch lib/shared/services/notification_service.dart :: } catch (e) {
printInCatch lib/shared/services/notification_service.dart :: } catch (e) {
sentryImport lib/features/daily_macros/data/daily_macro_targets_repository.dart :: import 'package:sentry_flutter/sentry_flutter.dart';
sentryImport lib/features/formula_kit/data/formula_pins_repository.dart :: import 'package:sentry_flutter/sentry_flutter.dart';
sentryImport lib/features/formula_kit/data/personal_formulas_repository.dart :: import 'package:sentry_flutter/sentry_flutter.dart';
sentryImport lib/features/macro_dashboard/application/dashboard_transient_telemetry.dart :: import 'package:sentry_flutter/sentry_flutter.dart';
sentryImport lib/features/nutrition_plan/presentation/providers/macro_targets_controller.dart :: import 'package:sentry_flutter/sentry_flutter.dart';
sentryImport lib/shared/core/app_router.dart :: import 'package:sentry_flutter/sentry_flutter.dart';
sentryImport lib/shared/database/connection_native.dart :: import 'package:sentry_drift/sentry_drift.dart';
sentryImport lib/shared/services/performance_telemetry.dart :: import 'package:sentry_flutter/sentry_flutter.dart';
sentryImport lib/shared/services/sentry/sentry_reporter.dart :: import 'package:sentry_flutter/sentry_flutter.dart' show SentryLevel;
sentryImport lib/shared/services/sync/data_sync_service.dart :: import 'package:sentry_flutter/sentry_flutter.dart';
sentryImport lib/shared/services/sync/sync_coordinator.dart :: import 'package:sentry_flutter/sentry_flutter.dart';
unreportedCatch lib/features/activities/data/activities_repository.dart :: } catch (_) {
unreportedCatch lib/features/activities/presentation/providers/activities_controller.dart :: } catch (_) {}
unreportedCatch lib/features/activities/presentation/providers/activities_controller.dart :: } catch (_) {}
unreportedCatch lib/features/activities/presentation/widgets/activity_card.dart :: } catch (_) {
unreportedCatch lib/features/activities/presentation/widgets/calendar_date_indicators.dart :: } catch (e) {
unreportedCatch lib/features/ai_coach/data/ai_coach_chat_repository.dart :: } catch (e) {
unreportedCatch lib/features/ai_coach/domain/ai_coach_message.dart :: } catch (_) {
unreportedCatch lib/features/ai_coach/domain/ai_coach_ui_part.dart :: } catch (_) {
unreportedCatch lib/features/ai_coach/presentation/providers/ai_coach_banner_providers.dart :: } catch (_) {
unreportedCatch lib/features/ai_credits/application/credits_controller.dart :: } catch (e) {
unreportedCatch lib/features/ai_credits/application/purchase_controller.dart :: } catch (_) {
unreportedCatch lib/features/ai_credits/application/purchase_controller.dart :: } catch (e) {
unreportedCatch lib/features/ai_credits/data/credits_repository.dart :: } catch (e) {
unreportedCatch lib/features/ai_credits/data/credits_repository.dart :: } catch (e) {
unreportedCatch lib/features/ai_credits/data/credits_repository.dart :: } catch (e) {
unreportedCatch lib/features/ai_credits/data/credits_repository.dart :: } catch (e) {
unreportedCatch lib/features/ai_credits/data/revenuecat_service.dart :: } catch (e, st) {
unreportedCatch lib/features/ai_credits/data/revenuecat_service.dart :: } catch (e, st) {
unreportedCatch lib/features/ai_credits/data/revenuecat_service.dart :: } catch (e, st) {
unreportedCatch lib/features/ai_credits/data/revenuecat_service.dart :: } catch (e, st) {
unreportedCatch lib/features/ai_credits/data/revenuecat_service.dart :: } catch (e, st) {
unreportedCatch lib/features/ai_credits/data/revenuecat_service.dart :: } on PurchasesError catch (e, st) {
unreportedCatch lib/features/app_startup/application/app_startup_service.dart :: } catch (_) {
unreportedCatch lib/features/app_startup/presentation/screens/force_upgrade_screen.dart :: } catch (_) {
unreportedCatch lib/features/auth/application/auth_service.dart :: } catch (e) {
unreportedCatch lib/features/auth/application/auth_service.dart :: } catch (e) {
unreportedCatch lib/features/auth/application/auth_service.dart :: } catch (e) {
unreportedCatch lib/features/auth/application/auth_service.dart :: } catch (e) {
unreportedCatch lib/features/auth/data/user_repository.dart :: } catch (_) {
unreportedCatch lib/features/auth/data/user_repository.dart :: } catch (e) {
unreportedCatch lib/features/auth/presentation/screens/email_login_screen.dart :: } catch (_) {
unreportedCatch lib/features/auth/presentation/screens/post_onboarding_auth_screen.dart :: } catch (_) {
unreportedCatch lib/features/auth/presentation/screens/verify_email_screen.dart :: } catch (_) {
unreportedCatch lib/features/auth/presentation/screens/verify_email_screen.dart :: } on InvalidVerificationCodeException catch (e) {
unreportedCatch lib/features/auth/presentation/screens/verify_email_screen.dart :: } on InvalidVerificationCodeException catch (e) {
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
unreportedCatch lib/features/meal_logging/domain/meal_log.dart :: } catch (_) {
unreportedCatch lib/features/meal_logging/domain/saved_meal.dart :: } catch (_) {
unreportedCatch lib/features/meal_logging/domain/saved_meal.dart :: } catch (_) {
unreportedCatch lib/features/meal_logging/presentation/providers/meal_log_providers.dart :: } catch (_) {
unreportedCatch lib/features/meal_logging/presentation/providers/meal_log_providers.dart :: } catch (_) {
unreportedCatch lib/features/meal_logging/presentation/screens/build_meal_screen.dart :: } catch (_) {
unreportedCatch lib/features/meal_logging/presentation/screens/build_meal_screen.dart :: } catch (_) {
unreportedCatch lib/features/meal_logging/presentation/screens/build_meal_screen.dart :: } catch (_) {
unreportedCatch lib/features/meal_logging/presentation/screens/build_meal_screen.dart :: } catch (_) {
unreportedCatch lib/features/meal_logging/presentation/screens/describe_meal_screen.dart :: } catch (_) {
unreportedCatch lib/features/meal_logging/presentation/screens/describe_meal_screen.dart :: } on InsufficientCreditsException catch (e) {
unreportedCatch lib/features/meal_logging/presentation/screens/describe_meal_screen.dart :: } on MealAiException catch (e) {
unreportedCatch lib/features/meal_logging/presentation/screens/edit_meal_log_screen.dart :: } catch (_) {
unreportedCatch lib/features/meal_logging/presentation/screens/edit_meal_log_screen.dart :: } catch (_) {
unreportedCatch lib/features/meal_logging/presentation/screens/edit_meal_log_screen.dart :: } on InsufficientCreditsException catch (e) {
unreportedCatch lib/features/meal_logging/presentation/screens/edit_meal_log_screen.dart :: } on MealAiException catch (e) {
unreportedCatch lib/features/meal_logging/presentation/screens/log_meal_screen.dart :: } catch (_) {
unreportedCatch lib/features/meal_logging/presentation/screens/log_meal_screen.dart :: } catch (_) {
unreportedCatch lib/features/meal_logging/presentation/screens/log_meal_screen.dart :: } catch (_) {
unreportedCatch lib/features/meal_logging/presentation/screens/log_meal_screen.dart :: } catch (_) {
unreportedCatch lib/features/meal_logging/presentation/screens/log_meal_screen.dart :: } catch (_) {
unreportedCatch lib/features/meal_logging/presentation/screens/log_meal_screen.dart :: } catch (_) {
unreportedCatch lib/features/meal_logging/presentation/screens/log_meal_screen.dart :: } catch (_) {
unreportedCatch lib/features/meal_logging/presentation/screens/log_meal_screen.dart :: } catch (_) {}
unreportedCatch lib/features/meal_logging/presentation/screens/log_meal_screen.dart :: } catch (e) {
unreportedCatch lib/features/meal_logging/presentation/screens/log_meal_screen.dart :: } on InsufficientCreditsException catch (e) {
unreportedCatch lib/features/meal_logging/presentation/screens/log_meal_screen.dart :: } on MealAiException catch (e) {
unreportedCatch lib/features/meal_logging/presentation/screens/photo_capture_screen.dart :: } catch (_) {
unreportedCatch lib/features/meal_logging/presentation/screens/photo_capture_screen.dart :: } catch (_) {
unreportedCatch lib/features/meal_logging/presentation/screens/photo_capture_screen.dart :: } on InsufficientCreditsException catch (e) {
unreportedCatch lib/features/meal_logging/presentation/screens/photo_capture_screen.dart :: } on MealAiException catch (e) {
unreportedCatch lib/features/meal_logging/presentation/screens/recipe_picker_screen.dart :: } catch (_) {
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
unreportedCatch lib/features/subscription/application/subscription_status_provider.dart :: } catch (e) {
unreportedCatch lib/features/subscription/data/subscription_service.dart :: } catch (e, st) {
unreportedCatch lib/features/subscription/data/subscription_service.dart :: } catch (e, st) {
unreportedCatch lib/features/user_foods/data/user_foods_repository.dart :: } catch (_) {
unreportedCatch lib/shared/controllers/food_search_controller.dart :: } catch (_) {
unreportedCatch lib/shared/data/syncable_repository.dart :: } catch (e) {
unreportedCatch lib/shared/database/app_database.dart :: } catch (closeError) {
unreportedCatch lib/shared/database/app_database.dart :: } catch (e) {
unreportedCatch lib/shared/database/app_database.dart :: } catch (e) {
unreportedCatch lib/shared/database/app_database.dart :: } catch (e) {
unreportedCatch lib/shared/database/daos/diagnostic_dao.dart :: } catch (e) {
unreportedCatch lib/shared/database/daos/diagnostic_dao.dart :: } catch (e) {
unreportedCatch lib/shared/database/daos/foods_dao.dart :: } catch (_) {
unreportedCatch lib/shared/database/daos/foods_dao.dart :: } catch (_) {
unreportedCatch lib/shared/database/daos/foods_dao.dart :: } catch (_) {
unreportedCatch lib/shared/database/daos/foods_dao.dart :: } on FormatException {
unreportedCatch lib/shared/database/schema_manager.dart :: } catch (e, stackTrace) {
unreportedCatch lib/shared/database/schema_manager.dart :: } catch (e) {
unreportedCatch lib/shared/database/schema_manager.dart :: } catch (e) {
unreportedCatch lib/shared/database/schema_manager.dart :: } catch (e) {
unreportedCatch lib/shared/database/tables/user_profiles.dart :: } catch (e) {
unreportedCatch lib/shared/services/analytics/analytics_tracker.dart :: } catch (_) {
unreportedCatch lib/shared/services/analytics/internal_user_service.dart :: } catch (_) {
unreportedCatch lib/shared/services/analytics/internal_user_service.dart :: } catch (_) {
unreportedCatch lib/shared/services/analytics/internal_user_service.dart :: } catch (_) {
unreportedCatch lib/shared/services/device_info_service.dart :: } catch (e) {
unreportedCatch lib/shared/services/launch_trail.dart :: } catch (_) {
unreportedCatch lib/shared/services/launch_trail.dart :: } catch (_) {
unreportedCatch lib/shared/services/launch_trail.dart :: } catch (_) {
unreportedCatch lib/shared/services/notification_service.dart :: } catch (e) {
unreportedCatch lib/shared/services/notification_service.dart :: } catch (e) {
unreportedCatch lib/shared/services/notification_service.dart :: } catch (e) {
unreportedCatch lib/shared/services/notification_service.dart :: } catch (e) {
unreportedCatch lib/shared/services/notification_service.dart :: } catch (e) {
unreportedCatch lib/shared/services/notification_service.dart :: } catch (e) {
unreportedCatch lib/shared/services/privacy/privacy_links.dart :: } catch (_) {
unreportedCatch lib/shared/services/privacy/privacy_region_service.dart :: } catch (_) {
unreportedCatch lib/shared/services/report/report.dart :: } catch (_) {
unreportedCatch lib/shared/services/report/report.dart :: } catch (_) {
unreportedCatch lib/shared/services/report/report.dart :: } catch (_) {
unreportedCatch lib/shared/services/report/report.dart :: } catch (_) {
unreportedCatch lib/shared/services/report/report.dart :: } catch (analyticsError) {
unreportedCatch lib/shared/services/report/report.dart :: } catch (sdkError) {
unreportedCatch lib/shared/services/report/report.dart :: } catch (sdkError) {
unreportedCatch lib/shared/services/schema_recovery_service.dart :: } on DatabaseSchemaException catch (e, stackTrace) {
unreportedCatch lib/shared/services/sync/data_sync_service.dart :: } catch (e) {
unreportedCatch lib/shared/services/sync/data_sync_service.dart :: } on TimeoutException {
unreportedCatch lib/shared/services/sync/entity_sync/activity_sync_handler.dart :: } catch (_) {
unreportedCatch lib/shared/services/sync/entity_sync/activity_sync_handler.dart :: } catch (_) {
unreportedCatch lib/shared/services/version_check_service.dart :: } catch (e) {
unreportedCatch lib/shared/services/version_check_service.dart :: } catch (e) {
unreportedCatch lib/shared/utils/celebration_haptics.dart :: } catch (_) {
unreportedCatch lib/shared/widgets/location_search_field.dart :: } catch (_) {
unreportedCatch lib/shared/widgets/root_app_widget.dart :: } catch (_) {
unreportedCatch lib/shared/widgets/tabs_screen.dart :: } catch (_) {
