// Screen smoke suite — onboarding / profile screens.
//
// Each test pumps a screen with mocked external deps and asserts it renders
// without layout overflow. These onboarding screens are pure-UI / selection /
// form screens (siblings of the ones already covered in
// test/features/responsive/responsive_smoke_test.dart), so the default
// AppExternalDeps override is sufficient.
//
// The 2026-08 redesign's step screens have dedicated widget tests in
// test/features/onboarding/ — this suite keeps only the PageView shell and
// the Settings-surviving sport-detail screens.

import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/onboarding/presentation/screens/cycling_details_screen.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/screens/swimming_details_screen.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/screens/onboarding_pageview_screen.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/screens/sports_selection_screen.dart';

import '../helpers/widget_test_harness.dart';

void main() {
  group('Onboarding screen smoke tests', () {
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
    // first page is mounted at render time — since the 2026-08 redesign that
    // is SportsSelectionScreen, which only reads the (synchronously-building)
    // onboardingControllerProvider, so no extra overrides are needed.
    testWidgets('OnboardingPageViewScreen renders first page', (tester) async {
      await smokeScreen(tester, const OnboardingPageViewScreen());
      expect(find.byType(SportsSelectionScreen), findsOneWidget);
    });
  });
}
