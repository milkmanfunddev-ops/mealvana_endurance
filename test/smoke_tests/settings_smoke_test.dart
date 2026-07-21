// Settings screen smoke suite.
//
// Covers 14 screens under lib/features/settings/presentation/screens/.
// (WeatherDetailScreen deleted — was unrouted dead code with hardcoded data.)
// Each test pumps the screen with mocked external deps (via smokeScreen) and
// asserts it builds without throwing and has no layout overflow at 390 px.
//
// Per-screen notes document why settle:false is needed and any code-quality
// findings. The harness (widget_test_harness.dart) wraps all pumps in
// ScreenUtilInit via wrapForTest() so .sp/.h/.w extensions always resolve.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

// Screens under test
import 'package:mealvana_endurance/features/settings/presentation/screens/settings_screen.dart';
import 'package:mealvana_endurance/features/settings/presentation/screens/preferences_screen.dart';
import 'package:mealvana_endurance/features/settings/presentation/screens/sweat_profile_screen.dart';
import 'package:mealvana_endurance/features/settings/presentation/screens/sport_settings_screen.dart';
import 'package:mealvana_endurance/features/settings/presentation/screens/nutrition_profile_screen.dart';
import 'package:mealvana_endurance/features/settings/presentation/screens/nutrition_targets_screen.dart';
import 'package:mealvana_endurance/features/settings/presentation/screens/food_preferences_hub_screen.dart';
import 'package:mealvana_endurance/features/settings/presentation/screens/food_preferences_screen.dart';
import 'package:mealvana_endurance/features/settings/presentation/screens/food_settings_consolidated_screen.dart';
import 'package:mealvana_endurance/features/settings/presentation/screens/sport_preferences_hub_screen.dart';
import 'package:mealvana_endurance/features/settings/presentation/screens/coach_connection_screen.dart';
import 'package:mealvana_endurance/features/settings/presentation/screens/connected_apps_screen.dart';
import 'package:mealvana_endurance/features/settings/presentation/screens/help_feedback_screen.dart';
import 'package:mealvana_endurance/features/settings/presentation/screens/debug_screen.dart';

// Providers / domain objects needed for seeded overrides
import 'package:mealvana_endurance/features/settings/domain/settings_state.dart';
import 'package:mealvana_endurance/features/settings/presentation/providers/settings_controller.dart';
import 'package:mealvana_endurance/features/settings/presentation/providers/sweat_profile_controller.dart';
import 'package:mealvana_endurance/features/integrations/presentation/providers/connect_training_controller.dart';

import '../helpers/widget_test_harness.dart';

// ─── Local mock ───────────────────────────────────────────────────────────────
//
// (No local SharedPreferences mock needed — smokeScreen now provides a default
// sharedPreferencesProvider override via mockSharedPreferences().)

// ─── Seeded controller implementations ───────────────────────────────────────
//
// Each extends the concrete controller class (NOT the private generated
// `_$XyzController` base — that is library-private to the controller file and
// inaccessible from a test file). Extending the concrete class overrides
// `build()` to return a fixed state synchronously, so tests never touch real
// Drift / Supabase. Other action methods (save, connect, etc.) are inherited
// from the concrete class but are never invoked during a smoke test (they live
// in button handlers, not in build()).

// ignore_for_file: must_be_immutable

class _SeededSettingsController extends SettingsController {
  @override
  FutureOr<SettingsState> build() => const SettingsState(
    title: 'Settings',
    profileSectionTitle: 'Profile',
    preferenceSectionTitle: 'Preferences',
    genderLabel: 'Gender',
    birthdayLabel: 'Birthday',
    heightLabel: 'Height',
    weightLabel: 'Weight',
    waterBottleLabel: 'Water Bottle',
    distanceUnitLabel: 'Distance',
    paceUnitLabel: 'Pace',
    gutTrainingLabel: 'Gut Training',
    saveButtonText: 'Save',
  );
}

class _SeededSweatProfileController extends SweatProfileController {
  @override
  FutureOr<SweatProfileState> build() => const SweatProfileState();
}

class _SeededConnectTrainingController extends ConnectTrainingController {
  @override
  FutureOr<ConnectTrainingState> build() => const ConnectTrainingState();
}

// ─────────────────────────────────────────────────────────────────────────────

void main() {
  group('Settings screen smoke tests', () {
    // ── 1. SettingsScreen ──────────────────────────────────────────────────
    //
    // Watches settingsControllerProvider. Uses go_router navigation (context.pop
    // / context.push) which works inside MaterialApp's built-in Navigator.
    // kyleThemeModeProvider reads sharedPreferencesProvider only on tap events,
    // not during build — no extra override needed.
    testWidgets('SettingsScreen builds without overflow', (tester) async {
      await smokeScreen(
        tester,
        const SettingsScreen(),
        overrides: [
          settingsControllerProvider.overrideWith(
            _SeededSettingsController.new,
          ),
        ],
      );
    });

    // ── 2. PreferencesScreen ───────────────────────────────────────────────
    //
    // Watches settingsControllerProvider. Uses addPostFrameCallback to
    // initialize local form state from the seeded provider value. Renders the
    // full form immediately — no perpetual spinner.
    testWidgets('PreferencesScreen builds without overflow', (tester) async {
      await smokeScreen(
        tester,
        const PreferencesScreen(),
        overrides: [
          settingsControllerProvider.overrideWith(
            _SeededSettingsController.new,
          ),
        ],
      );
    });

    // ── 3. SweatProfileScreen ──────────────────────────────────────────────
    //
    // Watches sweatProfileControllerProvider. Form renders from default
    // SweatProfileState (medium sweat rate, average sodium) immediately.
    //
    // Bug #14 FIXED: 35-pixel horizontal overflow caused by DropdownButtonFormField
    // lacking isExpanded:true when combined with prefixIcon + contentPadding.
    // Bug #17 FIXED: unit-label ternary was 'mL/hr'/'mL/hr' — now 'oz/hr'/'mL/hr'.
    testWidgets('SweatProfileScreen builds without overflow', (tester) async {
      await smokeScreen(
        tester,
        const SweatProfileScreen(),
        overrides: [
          sweatProfileControllerProvider.overrideWith(
            _SeededSweatProfileController.new,
          ),
        ],
      );
    });

    // ── 4. SportSettingsScreen ─────────────────────────────────────────────
    //
    // FINDING: SportSettingsScreen has a broken relative import at line 8:
    //   `../../../../../../../../../shared/widgets/kyle_design/kyle_design.dart`
    // Nine `../` levels from a file 4 levels deep — resolves above the package
    // root. Dart currently resolves this gracefully (same as package import),
    // but it is a latent maintenance bug. Correct form:
    //   `package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart`
    // Severity: other (import path bug, no runtime failure today).
    //
    // Bug #16: _withScreenUtil() workaround removed — harness now wraps all
    // pumps in ScreenUtilInit via wrapForTest(), so .sp/.h/.w resolve correctly.
    testWidgets('SportSettingsScreen builds without crash', (tester) async {
      await smokeScreen(
        tester,
        const SportSettingsScreen(),
        overrides: [
          settingsControllerProvider.overrideWith(
            _SeededSettingsController.new,
          ),
        ],
      );
    });

    // ── 5. NutritionProfileScreen ──────────────────────────────────────────
    //
    // Heavy initState: _loadCurrentValues() awaits userRepositoryProvider.future
    // + garminLastBodyCompProvider — both require real Drift/Supabase and never
    // complete in-test. Screen stays in loading state indefinitely. settle:false.
    testWidgets('NutritionProfileScreen builds (loading state)', (
      tester,
    ) async {
      await smokeScreen(tester, const NutritionProfileScreen(), settle: false);
    });

    // ── 6. NutritionTargetsScreen ──────────────────────────────────────────
    //
    // Reads settingsControllerProvider synchronously via addPostFrameCallback.
    // The form renders immediately; the seeded state supplies default values
    // for all fields. Settles cleanly.
    testWidgets('NutritionTargetsScreen builds without overflow', (
      tester,
    ) async {
      await smokeScreen(
        tester,
        const NutritionTargetsScreen(),
        overrides: [
          settingsControllerProvider.overrideWith(
            _SeededSettingsController.new,
          ),
        ],
      );
    });

    // ── 7. FoodPreferencesHubScreen ───────────────────────────────────────
    //
    // ConsumerWidget. Watches settingsControllerProvider. Hub with dietary /
    // allergy / formula-library tiles. Renders data state immediately.
    testWidgets('FoodPreferencesHubScreen builds without overflow', (
      tester,
    ) async {
      await smokeScreen(
        tester,
        const FoodPreferencesHubScreen(),
        overrides: [
          settingsControllerProvider.overrideWith(
            _SeededSettingsController.new,
          ),
        ],
      );
    });

    // ── 8. FoodPreferencesScreen ───────────────────────────────────────────
    //
    // FINDING (FOA violation): business logic is embedded in UI initState.
    // _loadFoods() calls foodRepositoryProvider, authServiceProvider,
    // appDatabaseProvider, syncCoordinatorProvider, and userFoodsRepositoryProvider
    // — all async — wrapped in Future.wait([…]).timeout(15s). None resolve
    // in-test. Screen shows CircularProgressIndicator indefinitely. settle:false.
    // This logic belongs in a controller, not in UI initState.
    // Severity: FOA violation (business logic in presentation layer).
    testWidgets('FoodPreferencesScreen builds (loading state)', (tester) async {
      await smokeScreen(tester, const FoodPreferencesScreen(), settle: false);
    });

    // ── 9. FoodSettingsConsolidatedScreen ─────────────────────────────────
    //
    // initState calls authService.getCurrentUser() which awaits
    // userRepositoryProvider.future (Drift). Never resolves in-test.
    // Shows CircularProgressIndicator. settle:false.
    testWidgets('FoodSettingsConsolidatedScreen builds (loading state)', (
      tester,
    ) async {
      await smokeScreen(
        tester,
        const FoodSettingsConsolidatedScreen(),
        settle: false,
      );
    });

    // ── 10. SportPreferencesHubScreen ─────────────────────────────────────
    //
    // ConsumerWidget. Watches settingsControllerProvider. Sport hub tiles
    // (running / cycling / swimming / triathlon). Renders data state
    // immediately when seeded.
    testWidgets('SportPreferencesHubScreen builds without overflow', (
      tester,
    ) async {
      await smokeScreen(
        tester,
        const SportPreferencesHubScreen(),
        overrides: [
          settingsControllerProvider.overrideWith(
            _SeededSettingsController.new,
          ),
        ],
      );
    });

    // ── 11. CoachConnectionScreen ──────────────────────────────────────────
    //
    // initState calls userIdProvider.future + coachRepositoryProvider.getMyCoach().
    // Both require real infrastructure and won't resolve in-test. Screen stays
    // in loading state (_isLoading = true renders a CircularProgressIndicator).
    // settle:false.
    testWidgets('CoachConnectionScreen builds (loading state)', (tester) async {
      await smokeScreen(tester, const CoachConnectionScreen(), settle: false);
    });

    // ── 12. ConnectedAppsScreen ────────────────────────────────────────────
    //
    // Watches connectTrainingControllerProvider (async). Also accesses
    // preferencesServiceProvider (via tp_writeback_providers.dart) which reads
    // sharedPreferencesProvider directly — not covered by the harness's
    // appExternalDepsProvider override. We add a mock sharedPreferencesProvider
    // override so PreferencesService initialises without throwing.
    //
    // In settings mode (no onContinue), initState calls
    // ref.invalidate(connectTrainingControllerProvider) in a postFrameCallback,
    // which re-triggers the seeded provider. settle:false to avoid waiting on
    // the re-triggered build path.
    testWidgets('ConnectedAppsScreen (settings mode) builds without crash', (
      tester,
    ) async {
      // sharedPreferencesProvider is now provided by smokeScreen defaults
      // (mockSharedPreferences()), so no explicit override needed here.
      await smokeScreen(
        tester,
        const ConnectedAppsScreen(),
        overrides: [
          connectTrainingControllerProvider.overrideWith(
            _SeededConnectTrainingController.new,
          ),
        ],
        settle: false,
      );
    });

    // ── 13. HelpFeedbackScreen ────────────────────────────────────────────
    //
    // Pure-UI ConsumerWidget. Reads appExternalDepsProvider only in tap event
    // handlers (already mocked by harness). Wiredash.of(context) references
    // are tap-only. Settles cleanly.
    testWidgets('HelpFeedbackScreen builds without overflow', (tester) async {
      await smokeScreen(tester, const HelpFeedbackScreen());
    });

    // ── 14. DebugScreen ───────────────────────────────────────────────────
    //
    // ConsumerStatefulWidget. initState has no async work. build() reads
    // DebugLogStorage() (a singleton — empty in test) and renders a log list.
    // Heavy providers (appDatabaseProvider, etc.) are accessed only in the
    // manual "_performSync" button handler.
    //
    // Bug #16: _withScreenUtil() workaround removed — harness now wraps all
    // pumps in ScreenUtilInit via wrapForTest(), so .sp/.h/.w resolve correctly.
    testWidgets('DebugScreen builds without crash', (tester) async {
      await smokeScreen(tester, const DebugScreen());
    });

    // NOTE: WeatherDetailScreen (settings/presentation/screens/) was deleted —
    // it was unrouted dead code with hardcoded mock data, a dead animation, and
    // a 185-pixel bottom overflow. The live WeatherDetailScreen lives at
    // lib/features/weather/presentation/screens/weather_detail_screen.dart and
    // is tested via its own feature smoke suite.
  });
}
