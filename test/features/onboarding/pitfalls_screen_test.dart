// Widget tests for the pitfalls step (onboarding step 2, 2026-08 redesign).
//
// Pins the phase-4 contract: toggles mirror into the controller draft
// immediately, zero selections is valid (Continue always enabled), all eight
// rows are reachable (the options area scrolls), and the screen lays out
// without overflow at a phone viewport.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/onboarding/domain/onboarding_draft.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/providers/onboarding_controller.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/screens/pitfalls_screen.dart';

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
          PitfallsScreen(onContinue: onContinue, stepIndex: 2),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(PitfallsScreen)),
    );
  }

  testWidgets('renders all eight pitfalls, none pre-selected, no overflow', (
    tester,
  ) async {
    final container = await pumpScreen(tester);

    expect(OnboardingPitfall.values, hasLength(8));
    for (final pitfall in OnboardingPitfall.values) {
      expect(
        find.byKey(ValueKey('pitfalls.${pitfall.dbValue}_chip')),
        findsOneWidget,
      );
    }
    expect(
      container.read(onboardingControllerProvider.notifier).draft.pitfalls,
      isEmpty,
    );
    expectNoRenderOverflow(tester);
  });

  testWidgets('toggling options (incl. a scrolled-to row) updates the draft', (
    tester,
  ) async {
    final container = await pumpScreen(tester);
    final controller = container.read(onboardingControllerProvider.notifier);

    await tester.tap(find.byKey(const ValueKey('pitfalls.energy_crash_chip')));
    await tester.pumpAndSettle();

    // The last row may sit below the fold on a phone — the options area must
    // scroll it into reach.
    final lastChip = find.byKey(const ValueKey('pitfalls.fueling_cost_chip'));
    await tester.ensureVisible(lastChip);
    await tester.pumpAndSettle();
    await tester.tap(lastChip);
    await tester.pumpAndSettle();

    expect(controller.draft.pitfalls, {
      OnboardingPitfall.energyCrash,
      OnboardingPitfall.fuelingCost,
    });

    // Scroll back up before deselecting — the first row scrolled off-screen
    // while the last row was brought into view.
    final firstChip = find.byKey(const ValueKey('pitfalls.energy_crash_chip'));
    await tester.ensureVisible(firstChip);
    await tester.pumpAndSettle();
    await tester.tap(firstChip);
    await tester.pumpAndSettle();
    expect(controller.draft.pitfalls, {OnboardingPitfall.fuelingCost});
  });

  testWidgets('Continue is enabled with zero selections (non-blocking)', (
    tester,
  ) async {
    var continued = 0;
    await pumpScreen(tester, onContinue: () => continued++);

    await tester.tap(find.byKey(const ValueKey('pitfalls.continue_button')));
    await tester.pumpAndSettle();
    expect(continued, 1);
  });
}
