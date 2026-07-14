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

      // identifyUser() sends Gender / Age / Weight (lbs) / Runs With Water
      // Bottle / Gut Training Level to Mixpanel People. The disclosure must say
      // so. An earlier draft claimed analytics "never includes your weights or
      // health data" — which was false. If health properties are ever stripped
      // from analytics_tracker.dart, update the copy and this test together.
      expect(find.textContaining('weight'), findsOneWidget);
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

      // The withdrawal toggle is above the fold — Apple requires it be easily
      // accessible, so it had better not need scrolling to find.
      expect(
        find.byKey(const ValueKey('privacy_settings.usage_toggle')),
        findsOneWidget,
      );
    });

    testWidgets('PrivacySettingsScreen exposes the policy + terms links',
        (tester) async {
      await smokeScreen(tester, const PrivacySettingsScreen());

      // These sit below the fold on a small phone, and the ListView builds
      // lazily — scroll to them rather than assuming they are already built.
      for (final key in const [
        'privacy_settings.policy_link',
        'privacy_settings.terms_link',
      ]) {
        await tester.scrollUntilVisible(
          find.byKey(ValueKey(key)),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.byKey(ValueKey(key)), findsOneWidget);
      }
    });
  });
}
