// Ticket 18 (Sentry MEALVANA-ENDURANCE-CM / CJ / C5 / DEV-8C): the personal
// info and body composition steps listen to the (keepAlive) integration
// profile with `fireImmediately: true`. When the profile has already resolved
// before the step mounts (the athlete connected a platform on an earlier
// step), the listener fires inside `initState` and the old code wrote the
// autofill straight into the onboarding draft. Writing a provider while the
// widget tree builds trips Riverpod's "Tried to modify a provider while the
// widget tree was building". The write now lands in the next frame.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/onboarding/domain/onboarding_integration_profile.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/providers/onboarding_controller.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/providers/onboarding_preview_providers.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/screens/body_composition_screen.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/screens/personal_info_screen.dart';

import '../../helpers/widget_test_harness.dart';

const _profile = OnboardingIntegrationProfile(
  firstName: 'Lee',
  lastName: 'Martin',
  email: 'lee@example.com',
  gender: Gender.male,
  birthYear: 1988,
  weightLbs: 161,
  detailsSource: 'TrainingPeaks',
  weightSource: 'TrainingPeaks',
);

/// A container whose integration profile has ALREADY resolved, so the
/// screen's `fireImmediately` listener fires during `initState`.
Future<ProviderContainer> _warmContainer() async {
  final container = ProviderContainer(
    overrides: [
      mockAppExternalDeps(),
      mockSharedPreferences(),
      onboardingIntegrationProfileProvider.overrideWith(
        (ref) async => _profile,
      ),
    ],
  );
  await container.read(onboardingIntegrationProfileProvider.future);
  return container;
}

Future<void> _pump(
  WidgetTester tester,
  ProviderContainer container,
  Widget screen,
) async {
  tester.view.physicalSize = standardPhoneSize;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: wrapForTest(screen)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('personal info: an already-resolved profile autofills without '
      'modifying a provider during build', (tester) async {
    final container = await tester.runAsync(_warmContainer);
    addTearDown(container!.dispose);

    await _pump(tester, container, const PersonalInfoScreen(stepIndex: 4));

    expect(tester.takeException(), isNull);
    final draft = container.read(onboardingControllerProvider.notifier).draft;
    expect(draft.firstName, 'Lee');
    expect(draft.gender, Gender.male);
    expect(draft.birthYear, 1988);
  });

  testWidgets('body composition: an already-resolved weight autofills '
      'without modifying a provider during build', (tester) async {
    final container = await tester.runAsync(_warmContainer);
    addTearDown(container!.dispose);

    await _pump(tester, container, const BodyCompositionScreen(stepIndex: 5));

    expect(tester.takeException(), isNull);
    final draft = container.read(onboardingControllerProvider.notifier).draft;
    expect(draft.weightPounds, 161);
  });
}
