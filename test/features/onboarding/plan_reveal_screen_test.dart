// Widget tests for the plan reveal step (onboarding step 7, 2026-08
// redesign).
//
// Pins the phase-5 contract: loader-then-reveal, the generic caption when
// biometrics were defaulted, edits routing through applyPlanEdits (only the
// touched field non-null), the connect nudge iff no provider connected, and
// the sweat-test tile's flag + snackbar. The shared preview provider is
// overridden with a bundle computed by the real (pure) PlanPreviewService.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/onboarding/application/plan_preview_service.dart';
import 'package:mealvana_endurance/features/onboarding/domain/onboarding_draft.dart';
import 'package:mealvana_endurance/features/onboarding/domain/training_insights.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/providers/onboarding_controller.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/providers/onboarding_preview_providers.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/screens/plan_reveal_screen.dart';

import '../../helpers/widget_test_harness.dart';

void main() {
  // Generic run-only bundle: no biometrics → isGeneric, 150-min run at
  // moderate gut → 70 g/hr (run ceiling), fluid/sodium from medium sweat.
  final genericBundle = OnboardingPreviewBundle(
    preview: PlanPreviewService.buildPreview(
      const OnboardingDraft(sports: {OnboardingSport.running}),
    ),
    insights: TrainingInsights.none,
  );

  Future<ProviderContainer> pumpScreen(
    WidgetTester tester, {
    OnboardingPreviewBundle? bundle,
    VoidCallback? onConnectTap,
    VoidCallback? onContinue,
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
          onboardingPlanPreviewProvider.overrideWith(
            (ref) async => bundle ?? genericBundle,
          ),
        ],
        child: wrapForTest(
          PlanRevealScreen(
            onContinue: onContinue,
            stepIndex: 7,
            onConnectTap: onConnectTap ?? () {},
          ),
        ),
      ),
    );
    await tester.pump();
    return ProviderScope.containerOf(
      tester.element(find.byType(PlanRevealScreen)),
    );
  }

  /// Advance past the ≥1.5 s loader into the reveal.
  Future<void> settleReveal(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the loader first, then the reveal', (tester) async {
    await pumpScreen(tester);

    expect(find.byKey(const ValueKey('plan_reveal.loader')), findsOneWidget);
    expect(find.byKey(const ValueKey('plan_reveal.title')), findsNothing);

    await settleReveal(tester);

    expect(find.byKey(const ValueKey('plan_reveal.loader')), findsNothing);
    expect(find.byKey(const ValueKey('plan_reveal.title')), findsOneWidget);
    expect(find.text('We built your plan.'), findsOneWidget);
    expectNoRenderOverflow(tester);
  });

  testWidgets('generic preview shows the estimates caption + run card', (
    tester,
  ) async {
    await pumpScreen(tester);
    await settleReveal(tester);

    expect(
      find.byKey(const ValueKey('plan_reveal.generic_caption')),
      findsOneWidget,
    );
    // Run-only selection → run card, no ride card.
    expect(find.text('LONG-RUN CARB TARGET'), findsOneWidget);
    expect(find.text('LONG-RIDE CARB TARGET'), findsNothing);
    expect(
      find.text('${genericBundle.preview.longRun!.carbGph.round()}'),
      findsOneWidget,
    );
  });

  testWidgets('edit dialog routes through applyPlanEdits (touched-only)', (
    tester,
  ) async {
    final container = await pumpScreen(tester);
    final controller = container.read(onboardingControllerProvider.notifier);
    await settleReveal(tester);

    await tester.tap(find.byKey(const ValueKey('plan_reveal.edit_long_run')));
    await tester.pumpAndSettle();

    // 70 → 65 (one -5 step).
    await tester.tap(find.byKey(const ValueKey('plan_reveal.edit_minus')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('plan_reveal.edit_value')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('plan_reveal.edit_save')));
    await tester.pumpAndSettle();

    final edits = controller.draft.planEdits;
    expect(edits.longRunCarbGph, 65);
    // Only the touched field is set — untouched targets stay null
    // (= algorithm default per the overrides contract).
    expect(edits.longRideCarbGph, isNull);
    expect(edits.fluidMlPerHr, isNull);
    expect(edits.sodiumMgPerHr, isNull);

    // The card now renders the edited value.
    expect(find.text('65'), findsOneWidget);
  });

  testWidgets('connect nudge shows iff no provider connected', (tester) async {
    var connectTaps = 0;
    final container = await pumpScreen(
      tester,
      onConnectTap: () => connectTaps++,
    );
    final controller = container.read(onboardingControllerProvider.notifier);
    await settleReveal(tester);

    expect(
      find.byKey(const ValueKey('plan_reveal.connect_nudge')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('plan_reveal.connect_now')));
    await tester.pumpAndSettle();
    expect(connectTaps, 1);

    // Once a provider is recorded, the nudge disappears.
    controller.recordConnectedProvider('garmin');
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('plan_reveal.connect_nudge')),
      findsNothing,
    );
  });

  testWidgets('sweat test tile records interest and shows the info snack', (
    tester,
  ) async {
    final container = await pumpScreen(tester);
    final controller = container.read(onboardingControllerProvider.notifier);
    await settleReveal(tester);

    await tester.ensureVisible(
      find.byKey(const ValueKey('plan_reveal.sweat_test_tile')),
    );
    await tester.tap(find.byKey(const ValueKey('plan_reveal.sweat_test_tile')));
    await tester.pump();

    expect(controller.draft.sweatTestInterest, isTrue);
    expect(
      find.text('You can run a sweat test anytime in Settings → Sweat Profile'),
      findsOneWidget,
    );
    // Let the snackbar timer run out so no timers leak past the test.
    await tester.pumpAndSettle(const Duration(seconds: 1));
  });
}
