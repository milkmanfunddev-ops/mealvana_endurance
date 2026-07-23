// Accessibility regression coverage for the Garmin connect banner's dismiss ✕.
//
// Bug (2026-07-20 UX pass): the dismiss control was a bare GestureDetector +
// Icon with no Semantics — VoiceOver/TalkBack users could never dismiss the
// banner, and since dismissal persists until app data is cleared, they were
// stuck with it permanently. The fix wraps the control in
// Semantics(button: true, label: ...), matching PinToggle's pattern.
//
// Mutation check: removing the Semantics wrapper fails the first test (the
// node loses the button flag and label).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mealvana_endurance/features/auth/application/auth_service.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/integrations/presentation/providers/integrations_providers.dart';
import 'package:mealvana_endurance/features/integrations/presentation/widgets/garmin_connect_banner.dart';
import 'package:mealvana_endurance/shared/services/preferences_service.dart';

import '../../helpers/widget_test_harness.dart';

const _userId = 'garmin-banner-a11y-user-001';
const _dismissKey = ValueKey('garmin_banner.dismiss');

UserProfile _profileFixture() => UserProfile(
  id: _userId,
  deviceId: 'dev-001',
  authUserId: 'aa000000-0000-0000-0000-000000000002',
  authProvider: 'email',
  isAnonymous: false,
  gender: Gender.male,
  birthday: DateTime(1985, 3, 20),
  heightFeet: 6,
  heightInches: 0,
  weightPounds: 180.0,
  runsWithWaterBottle: false,
  createdAt: DateTime(2024),
  updatedAt: DateTime(2024),
  onboardingCompleted: true,
  appVersion: '1.0',
);

void main() {
  late PreferencesService prefs;

  setUp(() async {
    // Empty prefs => banner not yet dismissed, so it is eligible to show.
    SharedPreferences.setMockInitialValues({});
    prefs = PreferencesService(await SharedPreferences.getInstance());
  });

  List<Override> overrides() => [
    preferencesServiceProvider.overrideWithValue(prefs),
    currentUserProvider.overrideWith((ref) async => _profileFixture()),
    isGarminConnectedProvider(_userId).overrideWith((ref) async => false),
  ];

  testWidgets(
    'dismiss control is exposed to screen readers as a labeled button',
    (tester) async {
      final handle = tester.ensureSemantics();

      await smokeScreen(
        tester,
        const Scaffold(body: GarminConnectBanner()),
        overrides: overrides(),
      );

      // Guard: the assertion below is vacuous against a hidden banner.
      expect(find.text('Connect Garmin'), findsOneWidget);

      expect(
        tester.getSemantics(find.byKey(_dismissKey)),
        isSemantics(
          isButton: true,
          hasTapAction: true,
          label: 'Dismiss Garmin banner',
        ),
      );

      handle.dispose();
    },
  );

  testWidgets('tapping the dismiss control still dismisses the banner', (
    tester,
  ) async {
    await smokeScreen(
      tester,
      const Scaffold(body: GarminConnectBanner()),
      overrides: overrides(),
    );

    expect(find.text('Connect Garmin'), findsOneWidget);

    await tester.tap(find.byKey(_dismissKey));
    await tester.pumpAndSettle();

    expect(find.text('Connect Garmin'), findsNothing);
    expect(prefs.garminBannerDismissed, isTrue);
  });
}
