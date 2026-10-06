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
unreportedCatch lib/features/meal_planning/data/vana_transport.dart :: } on FormatException { :: _tryDecode's null is a value each caller owns: postJson throws invalid_response, mapErrorResponse reports and tolerates text bodies, _decodeLine reports the skipped line
unreportedCatch lib/features/integrations/application/tp_writeback_service.dart :: } on IntegrationApiException catch (e) {  :: delegates to handleApiException, which classifies every status through Report (403 degraded, 404 note, else degraded); the guard only sees the block text
unreportedCatch lib/features/integrations/application/tp_writeback_service.dart :: } on IntegrationApiException catch (e) {  :: same as above (feedback push)
unreportedCatch lib/features/integrations/application/tp_writeback_service.dart :: } on IntegrationApiException catch (e) {  :: same as above (plan removal)
unreportedCatch lib/features/nutrition_plan/presentation/providers/swap_food_controller.dart :: } catch (_) {  :: the catch is the mounted test: reading `state` on a disposed notifier throws and Riverpod exposes no mounted flag here
unreportedCatch lib/features/integrations/data/vdot_api_client.dart :: } catch (_) {  :: the body is read as JSON only to pick out an error message; a non-JSON body (HTML error page) is an expected input and the raw text is the fallback output

## baseline

printInCatch lib/features/carb_loading/presentation/screens/carb_loading_food_selection_screen.dart :: } catch (e, stackTrace) {
printInCatch lib/features/carb_loading/presentation/screens/carb_loading_food_selection_screen.dart :: } catch (e) {
printInCatch lib/features/carb_loading/presentation/screens/carb_loading_food_selection_screen.dart :: } catch (e) {
sentryImport lib/features/macro_dashboard/application/dashboard_transient_telemetry.dart :: import 'package:sentry_flutter/sentry_flutter.dart';
sentryImport lib/shared/services/performance_telemetry.dart :: import 'package:sentry_flutter/sentry_flutter.dart';
sentryImport lib/shared/services/sentry/sentry_reporter.dart :: import 'package:sentry_flutter/sentry_flutter.dart' show SentryLevel;
unreportedCatch lib/features/activities/data/activities_repository.dart :: } catch (_) {
unreportedCatch lib/features/activities/presentation/providers/activities_controller.dart :: } catch (_) {}
unreportedCatch lib/features/activities/presentation/providers/activities_controller.dart :: } catch (_) {}
unreportedCatch lib/features/activities/presentation/widgets/activity_card.dart :: } catch (_) {
unreportedCatch lib/features/activities/presentation/widgets/calendar_date_indicators.dart :: } catch (e) {
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
unreportedCatch lib/features/content/application/content_service.dart :: } catch (_) {
unreportedCatch lib/features/content/application/content_service.dart :: } catch (_) {
unreportedCatch lib/features/content/application/content_service.dart :: } catch (e) {
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
unreportedCatch lib/features/fuel_timeline/presentation/widgets/energy_breakdown_sheet.dart :: } catch (_) {}
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
unreportedCatch lib/features/sharing/application/email_service.dart :: } catch (e) {
unreportedCatch lib/features/sharing/presentation/providers/share_form_controller.dart :: } catch (e) {
unreportedCatch lib/features/user_foods/data/user_foods_repository.dart :: } catch (_) {
