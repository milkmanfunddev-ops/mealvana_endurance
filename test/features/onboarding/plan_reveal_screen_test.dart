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
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

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
      find.textContaining('${genericBundle.preview.longRun!.carbGph.round()}'),
      findsOneWidget,
    );
  });

  testWidgets('pencil opens the inline slider; dragging routes through '
      'applyPlanEdits (touched-only) on release', (tester) async {
    final container = await pumpScreen(tester);
    final controller = container.read(onboardingControllerProvider.notifier);
    await settleReveal(tester);

    // The generic run-only bundle's recommendation (70 g/hr) is untouched
    // — no reset link yet.
    expect(
      find.byKey(const ValueKey('plan_reveal.reset_long_run')),
      findsNothing,
    );

    await tester.tap(find.byKey(const ValueKey('plan_reveal.edit_long_run')));
    await tester.pumpAndSettle();

    final slider = find.byKey(const ValueKey('plan_reveal.slider_long_run'));
    expect(slider, findsOneWidget);

    // Drag far past the left edge — the Slider clamps to its min (the
    // run card's 30 g/hr floor), so this is a deterministic way to commit
    // a new value without needing exact per-pixel math.
    await tester.drag(slider, const Offset(-2000, 0));
    await tester.pumpAndSettle();

    final edits = controller.draft.planEdits;
    expect(edits.longRunCarbGph, 30);
    // Only the touched field is set — untouched targets stay null
    // (= algorithm default per the overrides contract).
    expect(edits.longRideCarbGph, isNull);
    expect(edits.fluidMlPerHr, isNull);
    expect(edits.sodiumMgPerHr, isNull);

    // The card now renders the committed value, and off-recommendation
    // surfaces the reset link.
    expect(find.text('30 g/hr'), findsOneWidget);
    final resetLink = find.byKey(const ValueKey('plan_reveal.reset_long_run'));
    expect(resetLink, findsOneWidget);

    await tester.ensureVisible(resetLink);
    await tester.pumpAndSettle();
    await tester.tap(resetLink);
    await tester.pumpAndSettle();

    expect(controller.draft.planEdits.longRunCarbGph, isNull);
    expect(find.text('70 g/hr'), findsOneWidget);
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

  /// A connected-provider bundle whose digest covers Jul 20–26 2026.
  OnboardingPreviewBundle connectedBundle() => OnboardingPreviewBundle(
    preview: genericBundle.preview,
    insights: TrainingInsights(
      isReliable: true,
      windowDays: 7,
      windowStart: DateTime(2026, 7, 20),
      windowEnd: DateTime(2026, 7, 26),
      sessionCount: 2,
      weeklyDurationHours: 6.4,
      heavyWeekdays: const [DateTime.wednesday, DateTime.sunday],
      lightWeekdays: const [DateTime.monday, DateTime.friday],
      sessions: [
        InsightSession(
          activityType: ActivityType.running,
          durationMinutes: 45,
          title: 'Easy shakeout',
          scheduledDateTime: DateTime(2026, 7, 20),
        ),
        InsightSession(
          activityType: ActivityType.running,
          durationMinutes: 150,
          distanceMiles: 15,
          title: 'Long run',
          scheduledDateTime: DateTime(2026, 7, 26),
        ),
      ],
    ),
  );

  testWidgets(
    'connected-plan card replaces the nudge and names the real date window',
    (tester) async {
      final container = await pumpScreen(
        tester,
        bundle: connectedBundle(),
        onConnectTap: () {},
      );
      final controller = container.read(onboardingControllerProvider.notifier);
      controller.recordConnectedProvider('final_surge');
      await settleReveal(tester);

      expect(
        find.byKey(const ValueKey('plan_reveal.connect_nudge')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('plan_reveal.connected_plan_card')),
        findsOneWidget,
      );
      // The window it claims is the window the digest actually covered —
      // never the prototype's unbacked "next four weeks".
      expect(
        find.text(
          'We read your Final Surge training plan from Jul 20 to Jul 26.',
        ),
        findsOneWidget,
      );
      expect(
        find.textContaining('Heavy days: Wednesday, Sunday'),
        findsOneWidget,
      );
      expect(find.textContaining('Light days: Monday, Friday'), findsOneWidget);
    },
  );

  testWidgets('connected card says so plainly when nothing was read', (
    tester,
  ) async {
    final container = await pumpScreen(
      tester,
      bundle: OnboardingPreviewBundle(
        preview: genericBundle.preview,
        insights: TrainingInsights.none,
      ),
      onConnectTap: () {},
    );
    container
        .read(onboardingControllerProvider.notifier)
        .recordConnectedProvider('runna');
    await settleReveal(tester);

    expect(
      find.text(
        'We connected your Runna account, but found no scheduled sessions '
        'to read yet.',
      ),
      findsOneWidget,
    );
    // No pattern to show, so the heavy/light line stays off entirely.
    expect(find.textContaining('Heavy days:'), findsNothing);
  });

  testWidgets('7 taps on the connected card open the imported-data sheet', (
    tester,
  ) async {
    final container = await pumpScreen(
      tester,
      bundle: connectedBundle(),
      onConnectTap: () {},
    );
    container
        .read(onboardingControllerProvider.notifier)
        .recordConnectedProvider('final_surge');
    await settleReveal(tester);

    final card = find.byKey(const ValueKey('plan_reveal.connected_plan_card'));
    final sheet = find.byKey(const ValueKey('plan_reveal.debug_sheet'));

    // Six taps must not open it — this is a deliberate gesture, not a
    // stray tap on a card that otherwise does nothing.
    for (var i = 0; i < 6; i++) {
      await tester.tap(card);
      await tester.pump();
    }
    expect(sheet, findsNothing);

    await tester.tap(card);
    await tester.pumpAndSettle();

    expect(sheet, findsOneWidget);
    expect(find.text('Imported from Final Surge'), findsOneWidget);
    // Summary block traces the card's claims back to their inputs, and
    // leads with the read path so an empty digest can be diagnosed.
    expect(find.text('Rows read'), findsOneWidget);
    expect(find.text('Jul 20 to Jul 26'), findsOneWidget);
    expect(find.text('Wednesday, Sunday'), findsOneWidget);
    expect(find.text('SESSIONS (2)'), findsOneWidget);

    // ...and every digested session is listed below it. Drive the sheet's
    // own scrollable — a plain drag would be swallowed by the draggable
    // sheet growing toward its max height instead of scrolling.
    await tester.scrollUntilVisible(
      find.text('Long run'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(DraggableScrollableSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();

    expect(find.text('Easy shakeout'), findsOneWidget);
    expect(find.text('Long run'), findsOneWidget);
    expect(find.text('150 min · 15.0 mi'), findsOneWidget);
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
