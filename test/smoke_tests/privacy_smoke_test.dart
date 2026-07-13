// Screen smoke suite — the privacy consent disclosure and the Settings →
// Privacy screen (the consent-withdrawal surface Apple 5.1.1(ii) requires).

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/privacy/presentation/screens/privacy_consent_screen.dart';
import 'package:mealvana_endurance/features/settings/presentation/screens/privacy_settings_screen.dart';

import '../helpers/widget_test_harness.dart';

void main() {
  group('Privacy screen smoke tests', () {
    testWidgets('PrivacyConsentScreen renders without overflow',
        (tester) async {
      await smokeScreen(tester, const PrivacyConsentScreen());

      // The disclosure has to actually disclose: name the processor and offer
      // the choice, or it isn't informed consent.
      expect(find.textContaining('Mixpanel'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('privacy_consent.usage_toggle')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('privacy_consent.continue_button')),
        findsOneWidget,
      );
    });

    testWidgets('PrivacySettingsScreen renders without overflow',
        (tester) async {
      await smokeScreen(tester, const PrivacySettingsScreen());

      // Withdrawal must be reachable here, alongside the policy links.
      expect(
        find.byKey(const ValueKey('privacy_settings.usage_toggle')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('privacy_settings.policy_link')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('privacy_settings.terms_link')),
        findsOneWidget,
      );
    });
  });
}
