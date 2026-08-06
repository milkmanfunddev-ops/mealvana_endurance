// Widget tests for the daily plan preview step (onboarding step 8 — final,
// 2026-08 redesign).
//
// Pins the phase-5 contract: the three day tabs switch the rendered macro
// numbers (all from the same shared preview bundle the plan reveal used),
// the footer reads "Save My Plan", and the connect nudge shows iff no
// provider was connected.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/onboarding/application/plan_preview_service.dart';
import 'package:mealvana_endurance/features/onboarding/domain/onboarding_draft.dart';
import 'package:mealvana_endurance/features/onboarding/domain/training_insights.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/providers/onboarding_controller.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/providers/onboarding_preview_providers.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/screens/daily_plan_preview_screen.dart';

import '../../helpers/widget_test_harness.dart';

void main() {
  // Full-biometrics draft (≈70 kg runner) so the day tabs produce distinct,
  // stable numbers via the real (pure) preview service.
  final bundle = OnboardingPreviewBundle(
    preview: PlanPreviewService.buildPreview(
      const OnboardingDraft(
        sports: {OnboardingSport.running},
        gender: Gender.male,
        birthYear: 1991,
        heightFeet: 5,
        heightInches: 8,
        weightPounds: 154.32,
      ),
      now: DateTime(2026, 8, 6),
    ),
    insights: TrainingInsights.none,
  );

  Future<ProviderContainer> pumpScreen(
    WidgetTester tester, {
    VoidCallback? onContinue,
    VoidCallback? onConnectTap,
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
          onboardingPlanPreviewProvider.overrideWith((ref) async => bundle),
        ],
        child: wrapForTest(
          DailyPlanPreviewScreen(
            onContinue: onContinue,
            stepIndex: 8,
            onConnectTap: onConnectTap ?? () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(DailyPlanPreviewScreen)),
    );
  }

  testWidgets('tab switch changes the rendered macro numbers', (tester) async {
    await pumpScreen(tester);

    final workoutCarbs = bundle.preview.workoutDay.carbsG;
    final restCarbs = bundle.preview.restDay.carbsG;
    final carbLoadCarbs = bundle.preview.carbLoadDay.carbsG;
    // Sanity: the fixture actually distinguishes the tabs.
    expect(workoutCarbs, isNot(restCarbs));

    // Workout tab is active by default.
    expect(find.text('$workoutCarbs g'), findsOneWidget);
    expect(find.text('Built around a long training session.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('daily_preview.tab_rest')));
    await tester.pumpAndSettle();
    expect(find.text('$restCarbs g'), findsOneWidget);
    expect(
      find.text('Minimal movement — the day after a long session.'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const ValueKey('daily_preview.tab_carb_load')));
    await tester.pumpAndSettle();
    expect(find.text('$carbLoadCarbs g'), findsOneWidget);
    expect(
      find.text('The day before your race — topping up glycogen.'),
      findsOneWidget,
    );

    // Calories row always renders in kcal.
    expect(
      find.text('${bundle.preview.carbLoadDay.calories} kcal'),
      findsOneWidget,
    );
    expectNoRenderOverflow(tester);
  });

  testWidgets('final step footer reads Save My Plan and advances', (
    tester,
  ) async {
    var continued = 0;
    await pumpScreen(tester, onContinue: () => continued++);

    expect(find.text('Save My Plan'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('daily_preview.save_button')));
    await tester.pumpAndSettle();
    expect(continued, 1);
  });

  testWidgets('connect nudge shows iff no provider connected', (tester) async {
    var connectTaps = 0;
    final container = await pumpScreen(
      tester,
      onConnectTap: () => connectTaps++,
    );
    final controller = container.read(onboardingControllerProvider.notifier);

    expect(
      find.byKey(const ValueKey('daily_preview.connect_nudge')),
      findsOneWidget,
    );
    await tester.ensureVisible(
      find.byKey(const ValueKey('daily_preview.connect_now')),
    );
    await tester.tap(find.byKey(const ValueKey('daily_preview.connect_now')));
    await tester.pumpAndSettle();
    expect(connectTaps, 1);

    controller.recordConnectedProvider('final_surge');
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('daily_preview.connect_nudge')),
      findsNothing,
    );
  });
}
