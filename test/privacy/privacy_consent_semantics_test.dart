// Ticket 43 (Finding 30-010): on "Your privacy", VoiceOver read the usage
// switch as an unnamed checkbox ("CheckBox '' '0'") beside the static text
// "Share usage data". Merged at the call site, the switch's toggled node
// carries the title as its name. KyleSwitch itself is untouched (library
// component; a change there would owe /design-sync).
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/privacy/presentation/screens/privacy_consent_screen.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';

import '../helpers/widget_test_harness.dart';

void main() {
  testWidgets('the usage switch is one toggle named Share usage data', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    tester.view.physicalSize = standardPhoneSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mockAppExternalDeps(),
          appConfigProvider.overrideWithValue(AppConfig.forTesting()),
          mockSharedPreferences(),
        ],
        child: wrapForTest(const PrivacyConsentScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final toggle = find.byKey(const ValueKey('privacy_consent.usage_toggle'));
    expect(
      tester.getSemantics(toggle),
      matchesSemantics(
        label: 'Share usage data',
        hasToggledState: true,
        isToggled: false,
        hasTapAction: true,
        hasEnabledState: true,
        isEnabled: true,
        isFocusable: true,
        hasFocusAction: true,
      ),
    );

    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(toggle),
      isSemantics(
        label: 'Share usage data',
        hasToggledState: true,
        isToggled: true,
      ),
    );

    // The disclosure line stays its own node, read next — not folded into
    // the switch's name.
    expect(tester.getSemantics(toggle).label, isNot(contains('Mixpanel')));
    handle.dispose();
  });
}
