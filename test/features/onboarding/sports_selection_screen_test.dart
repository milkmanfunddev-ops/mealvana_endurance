// Widget tests for the redesigned sports selection step (onboarding step 0).
//
// Pins the phase-4 contract: nothing pre-selected, toggles mirror into the
// controller draft (and the legacy sports cache) immediately, Continue is
// gated on >= 1 selection, and the screen lays out without overflow at a
// phone viewport.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/onboarding/domain/onboarding_draft.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/providers/onboarding_controller.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/screens/sports_selection_screen.dart';

import '../../helpers/widget_test_harness.dart';

void main() {
  Future<ProviderContainer> pumpScreen(
    WidgetTester tester, {
    VoidCallback? onContinue,
  }) async {
    tester.view.physicalSize = standardPhoneSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [mockAppExternalDeps(), mockSharedPreferences()],
        child: wrapForTest(
          SportsSelectionScreen(onContinue: onContinue, stepIndex: 0),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(SportsSelectionScreen)),
    );
  }

  OnboardingController controllerOf(ProviderContainer container) =>
      container.read(onboardingControllerProvider.notifier);

  testWidgets('renders all four sports, none pre-selected, without overflow', (
    tester,
  ) async {
    final container = await pumpScreen(tester);

    for (final sport in OnboardingSport.values) {
      expect(
        find.byKey(ValueKey('sport_selection.${sport.dbValue}_chip')),
        findsOneWidget,
      );
    }
    // The redesign removed the old default-running pre-selection.
    expect(controllerOf(container).draft.sports, isEmpty);
    expectNoRenderOverflow(tester);
  });

  testWidgets('toggling options updates the draft and the legacy cache', (
    tester,
  ) async {
    final container = await pumpScreen(tester);
    final controller = controllerOf(container);

    await tester.tap(
      find.byKey(const ValueKey('sport_selection.running_chip')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('sport_selection.triathlon_chip')),
    );
    await tester.pumpAndSettle();

    expect(controller.draft.sports, {
      OnboardingSport.running,
      OnboardingSport.triathlon,
    });
    // Deselecting works too — including down to the last selection (the old
    // "can't deselect the only sport" rule is gone; gating moved to Continue).
    await tester.tap(
      find.byKey(const ValueKey('sport_selection.running_chip')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('sport_selection.triathlon_chip')),
    );
    await tester.pumpAndSettle();
    expect(controller.draft.sports, isEmpty);
  });

  testWidgets('Continue is gated on at least one selection', (tester) async {
    var continued = 0;
    await pumpScreen(tester, onContinue: () => continued++);

    // Nothing selected: the Continue button is disabled.
    await tester.tap(
      find.byKey(const ValueKey('sport_selection.continue_button')),
    );
    await tester.pumpAndSettle();
    expect(continued, 0);

    // One selection: Continue advances.
    await tester.tap(
      find.byKey(const ValueKey('sport_selection.cycling_chip')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('sport_selection.continue_button')),
    );
    await tester.pumpAndSettle();
    expect(continued, 1);
  });
}
