// Screen smoke suite — assorted standalone screens that render from the default
// mocked external deps (no per-screen AsyncNotifier seeding required).

import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/ai_credits/presentation/screens/buy_credits_screen.dart';
import 'package:mealvana_endurance/features/pro_version/presentation/screens/pro_version_screen.dart';
import 'package:mealvana_endurance/features/auth/presentation/screens/post_onboarding_auth_screen.dart';
import 'package:mealvana_endurance/features/education/presentation/screens/education_screen.dart';

import '../helpers/widget_test_harness.dart';

void main() {
  group('Assorted screen smoke tests', () {
    testWidgets('ProVersionScreen renders without overflow', (tester) async {
      await smokeScreen(tester, const ProVersionScreen());
    });

    testWidgets('PostOnboardingAuthScreen builds without overflow', (
      tester,
    ) async {
      await smokeScreen(tester, const PostOnboardingAuthScreen());
    });

    testWidgets('EducationScreen renders without overflow', (tester) async {
      await smokeScreen(tester, const EducationScreen());
    });

    // BuyCreditsScreen in the disabled state (aiCreditsEnabled = false, the
    // default). No async providers are exercised — only the static
    // "Coming Soon" body is rendered.
    testWidgets('BuyCreditsScreen (disabled) renders without overflow', (
      tester,
    ) async {
      // smokeScreen already overrides appConfigProvider with
      // AppConfig.forTesting() (aiCreditsEnabled = false by default), so no
      // extra override is needed — passing one here double-overrides and throws.
      await smokeScreen(tester, const BuyCreditsScreen());
    });
  });
}
