// Screen smoke suite — onboarding / profile screens.
//
// Each test pumps a screen with mocked external deps and asserts it renders
// without layout overflow. These onboarding screens are pure-UI / selection /
// form screens (siblings of the ones already covered in
// test/features/responsive/responsive_smoke_test.dart), so the default
// AppExternalDeps override is sufficient.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/onboarding/presentation/screens/user_profile_screen.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/screens/cycling_details_screen.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/screens/swimming_details_screen.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/screens/onboarding_pageview_screen.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/screens/food_preferences_v2_screen.dart';
import 'package:mealvana_endurance/features/integrations/presentation/providers/connect_training_controller.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';

import '../helpers/widget_test_harness.dart';

// NOTE: SportPreferencesScreen is intentionally NOT smoke-tested — it has zero
// references in lib/ (dead code; it still pushes to the removed
// '/onboarding/food-preferences' route) and overflows by 104px. Flagged for
// removal rather than tested.

// Seeded controller for the first onboarding page (ConnectedAppsScreen), which
// watches connectTrainingControllerProvider. Same pattern as the settings
// bundle: extend the concrete controller and return a fixed state so the test
// never touches real Drift/Supabase.
class _SeededConnectTrainingController extends ConnectTrainingController {
  @override
  FutureOr<ConnectTrainingState> build() => const ConnectTrainingState();
}

void main() {
  group('Onboarding screen smoke tests', () {
    testWidgets('UserProfileScreen renders without overflow', (tester) async {
      await smokeScreen(tester, const UserProfileScreen());
    });

    testWidgets('CyclingDetailsScreen renders without overflow', (
      tester,
    ) async {
      await smokeScreen(tester, const CyclingDetailsScreen());
    });

    testWidgets('SwimmingDetailsScreen renders without overflow', (
      tester,
    ) async {
      await smokeScreen(tester, const SwimmingDetailsScreen());
    });

    // OnboardingPageViewScreen hosts the whole onboarding PageView. Only the
    // first page (ConnectedAppsScreen) is mounted at render time, so seeding
    // connectTrainingControllerProvider is sufficient. The real
    // onboardingControllerProvider builds synchronously (returns null +
    // keepAlive) and is safe to leave un-overridden. settle:false because
    // ConnectedAppsScreen re-invalidates its controller in a post-frame
    // callback and never fully settles in-test.
    testWidgets('OnboardingPageViewScreen renders first page', (tester) async {
      await smokeScreen(
        tester,
        const OnboardingPageViewScreen(),
        overrides: [
          connectTrainingControllerProvider.overrideWith(
            _SeededConnectTrainingController.new,
          ),
        ],
        settle: false,
      );
    });

    // FoodPreferencesV2Screen loads foods in initState via
    // foodRepositoryProvider (business logic in UI initState — same FOA
    // violation already noted for FoodPreferencesScreen in the settings
    // bundle). With an empty in-memory Drift DB and the harness's fake
    // Supabase client the load either stays pending or fails fast into the
    // caught-error branch ("No foods available") — both are defined safe
    // states. settle:false keeps the test deterministic either way.
    testWidgets('FoodPreferencesV2Screen builds', (tester) async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      await smokeScreen(
        tester,
        const FoodPreferencesV2Screen(),
        overrides: [inMemoryDatabaseOverride(db)],
        settle: false,
      );
    });
  });
}
