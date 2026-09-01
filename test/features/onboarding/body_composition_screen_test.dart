// Widget tests for the body composition step (onboarding step 5, 2026-08
// redesign).
//
// Pins the phase-5 contract: wheel defaults (5 ft 8 in / 150 lb) are pushed
// into the draft on entry so Continue is always enabled, the unit toggle
// converts the displayed wheels (canonical storage stays imperial), and the
// Garmin weight autofill lands when the draft has no weight yet.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/onboarding/presentation/providers/onboarding_controller.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/providers/onboarding_preview_providers.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/screens/body_composition_screen.dart';

import '../../helpers/widget_test_harness.dart';

void main() {
  Future<ProviderContainer> pumpScreen(
    WidgetTester tester, {
    VoidCallback? onContinue,
    double? integrationWeightLbs,
  }) async {
    tester.view.physicalSize = standardPhoneSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mockAppExternalDeps(),
          mockSharedPreferences(),
          // Screens must never hit the integrations repository in tests.
          onboardingIntegrationWeightLbsProvider.overrideWith(
            (ref) async => integrationWeightLbs,
          ),
        ],
        child: wrapForTest(
          BodyCompositionScreen(onContinue: onContinue, stepIndex: 5),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(BodyCompositionScreen)),
    );
  }

  testWidgets('defaults are pushed into the draft; Continue always enabled', (
    tester,
  ) async {
    var continued = 0;
    final container = await pumpScreen(tester, onContinue: () => continued++);
    final controller = container.read(onboardingControllerProvider.notifier);

    expect(controller.draft.heightFeet, 5);
    expect(controller.draft.heightInches, 8);
    expect(controller.draft.weightPounds, 150);
    expect(controller.draft.useMetricUnits, isFalse);

    await tester.tap(find.byKey(const ValueKey('body_comp.continue_button')));
    await tester.pumpAndSettle();
    expect(continued, 1);
    expectNoRenderOverflow(tester);
  });

  testWidgets('unit toggle converts the displayed wheels, keeps canon', (
    tester,
  ) async {
    final container = await pumpScreen(tester);
    final controller = container.read(onboardingControllerProvider.notifier);

    // Imperial wheels by default — the spec puts the unit inside the
    // selected row's label ('5 ft' / '8 in' / '150 lb').
    expect(find.textContaining(' ft'), findsOneWidget);
    expect(find.textContaining(' in'), findsOneWidget);
    expect(find.textContaining(' lb'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('body_comp.units_metric_button')),
    );
    await tester.pumpAndSettle();

    expect(controller.draft.useMetricUnits, isTrue);
    expect(find.textContaining(' cm'), findsOneWidget);
    expect(find.textContaining(' kg'), findsOneWidget);
    // 5 ft 8 in = 68 in → 173 cm; 150 lb → 68 kg. Both selected wheel items
    // are visible (they may collide on '68' — assert the cm value plus the
    // canonical draft staying imperial).
    expect(find.textContaining('173'), findsWidgets);
    expect(controller.draft.heightFeet, 5);
    expect(controller.draft.heightInches, 8);
    expect(controller.draft.weightPounds, 150);
  });

  testWidgets('Garmin weight autofill lands when draft has no weight', (
    tester,
  ) async {
    final container = await pumpScreen(tester, integrationWeightLbs: 161.0);
    final controller = container.read(onboardingControllerProvider.notifier);

    expect(controller.draft.weightPounds, 161.0);
    expect(
      find.byKey(const ValueKey('body_comp.garmin_badge')),
      findsOneWidget,
    );
  });

  testWidgets('no autofill without integration weight', (tester) async {
    final container = await pumpScreen(tester);
    final controller = container.read(onboardingControllerProvider.notifier);

    expect(controller.draft.weightPounds, 150);
    expect(find.byKey(const ValueKey('body_comp.garmin_badge')), findsNothing);
  });
}
