// Screen smoke suite — onboarding / profile screens.
//
// Each test pumps a screen with mocked external deps and asserts it renders
// without layout overflow. These onboarding screens are pure-UI / selection /
// form screens (siblings of the ones already covered in
// test/features/responsive/responsive_smoke_test.dart), so the default
// AppExternalDeps override is sufficient.

import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/onboarding/presentation/screens/user_profile_screen.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/screens/cycling_details_screen.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/screens/swimming_details_screen.dart';

import '../helpers/widget_test_harness.dart';

// NOTE: SportPreferencesScreen is intentionally NOT smoke-tested — it has zero
// references in lib/ (dead code; it still pushes to the removed
// '/onboarding/food-preferences' route) and overflows by 104px. Flagged for
// removal rather than tested.

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
  });
}
