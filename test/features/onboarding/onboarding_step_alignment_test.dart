// Guards the 2026-08 redesign's funnel contract: the onboarding PageView's
// child order, the `stepIndex` each child is handed, and [kOnboardingStepNames]
// must all stay index-aligned.
//
// Why this exists: `onboarding_pageview_screen.dart` says that alignment "IS
// the Mixpanel funnel contract", but nothing enforced it. The existing analytics
// test pins the *names* (`onboardingStepName(3) == 'connect_training'`), which
// keeps passing if someone reorders the PageView children — every
// `onboarding_step_completed` / `screen_viewed` event then carries the wrong
// step_name and the drop-off funnel silently mislabels itself.
//
// It also catches the class of drift that broke
// `integration_test/flows/integrations_connect_flow_test.dart`, which hard-coded
// "Connect Training is the first step" and went stale when the redesign moved
// ConnectedAppsScreen from index 0 to index 3.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/onboarding/presentation/providers/onboarding_analytics.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/screens/body_composition_screen.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/screens/daily_plan_preview_screen.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/screens/goals_screen.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/screens/nutrition_settings_screen.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/screens/onboarding_pageview_screen.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/screens/personal_info_screen.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/screens/pitfalls_screen.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/screens/plan_reveal_screen.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/screens/sports_selection_screen.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/widgets/page_keep_alive_wrapper.dart';
import 'package:mealvana_endurance/features/settings/presentation/screens/connected_apps_screen.dart';

import '../../helpers/widget_test_harness.dart';

/// One expected page: the analytics step name, the widget that must sit at that
/// index, and how to read the `stepIndex` that widget was constructed with.
class _ExpectedStep {
  const _ExpectedStep(this.name, this.type, this.readStepIndex);

  final String name;
  final Type type;
  final int? Function(Widget) readStepIndex;
}

/// The funnel, in order. Changing this list without changing
/// `_buildPages()` + [kOnboardingStepNames] is exactly the mistake being caught.
final List<_ExpectedStep> _expectedSteps = <_ExpectedStep>[
  _ExpectedStep(
    'sports_selection',
    SportsSelectionScreen,
    (w) => (w as SportsSelectionScreen).stepIndex,
  ),
  _ExpectedStep('goals', GoalsScreen, (w) => (w as GoalsScreen).stepIndex),
  _ExpectedStep(
    'pitfalls',
    PitfallsScreen,
    (w) => (w as PitfallsScreen).stepIndex,
  ),
  _ExpectedStep(
    'connect_training',
    ConnectedAppsScreen,
    (w) => (w as ConnectedAppsScreen).stepIndex,
  ),
  _ExpectedStep(
    'personal_info',
    PersonalInfoScreen,
    (w) => (w as PersonalInfoScreen).stepIndex,
  ),
  _ExpectedStep(
    'body_composition',
    BodyCompositionScreen,
    (w) => (w as BodyCompositionScreen).stepIndex,
  ),
  _ExpectedStep(
    'nutrition_settings',
    NutritionSettingsScreen,
    (w) => (w as NutritionSettingsScreen).stepIndex,
  ),
  _ExpectedStep(
    'plan_reveal',
    PlanRevealScreen,
    (w) => (w as PlanRevealScreen).stepIndex,
  ),
  _ExpectedStep(
    'daily_plan_preview',
    DailyPlanPreviewScreen,
    (w) => (w as DailyPlanPreviewScreen).stepIndex,
  ),
];

void main() {
  /// Pumps the PageView shell and returns its children in declaration order,
  /// unwrapped from [PageKeepAliveWrapper].
  ///
  /// Only page 0 is ever built by the PageView, so the other screens'
  /// dependencies are never touched — the widget *descriptions* are read
  /// straight off the `children` list, which is what the funnel contract is
  /// about.
  Future<List<Widget>> pumpAndReadPages(WidgetTester tester) async {
    tester.view.physicalSize = standardPhoneSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [mockAppExternalDeps(), mockSharedPreferences()],
        child: wrapForTest(const OnboardingPageViewScreen()),
      ),
    );
    await tester.pumpAndSettle();

    final pageView = tester.widget<PageView>(find.byType(PageView));
    final delegate = pageView.childrenDelegate;
    expect(
      delegate,
      isA<SliverChildListDelegate>(),
      reason:
          'The funnel contract assumes a static child list. If the PageView '
          'moved to a builder delegate, this guard must be rewritten rather '
          'than deleted.',
    );

    return (delegate as SliverChildListDelegate).children
        .map((child) => child is PageKeepAliveWrapper ? child.child : child)
        .toList();
  }

  testWidgets('the PageView carries exactly the named funnel steps, in order', (
    tester,
  ) async {
    final pages = await pumpAndReadPages(tester);

    expect(
      pages,
      hasLength(kOnboardingStepNames.length),
      reason:
          'The PageView has ${pages.length} pages but kOnboardingStepNames has '
          '${kOnboardingStepNames.length} entries. Adding a step means adding '
          'its analytics name too, or every later step reports the wrong one.',
    );

    for (var i = 0; i < _expectedSteps.length; i++) {
      final expected = _expectedSteps[i];

      expect(
        pages[i].runtimeType,
        expected.type,
        reason:
            'Page $i should be ${expected.type} (the "${expected.name}" step). '
            'Reordering _buildPages() without reordering kOnboardingStepNames '
            'silently remaps the Mixpanel funnel.',
      );

      expect(
        kOnboardingStepNames[i],
        expected.name,
        reason:
            'kOnboardingStepNames[$i] should be "${expected.name}" to match '
            '${expected.type} at page $i.',
      );

      expect(
        onboardingStepName(i),
        expected.name,
        reason: 'onboardingStepName($i) must resolve to the page at index $i.',
      );
    }
  });

  testWidgets('each step is handed the stepIndex matching its position', (
    tester,
  ) async {
    final pages = await pumpAndReadPages(tester);

    for (var i = 0; i < _expectedSteps.length; i++) {
      final expected = _expectedSteps[i];

      expect(
        expected.readStepIndex(pages[i]),
        i,
        reason:
            '${expected.type} sits at page $i but was constructed with '
            'stepIndex ${expected.readStepIndex(pages[i])}. That literal is '
            'what stamps step_index onto screen_viewed — a mismatch reports '
            'the wrong step for this screen.',
      );
    }
  });

  testWidgets('the connect step is not first — Patrol flows must navigate to it', (
    tester,
  ) async {
    // Regression pin for integration_test/flows/integrations_connect_flow_test.dart,
    // which assumed "Get Started" landed straight on Connect Training. It did
    // pre-redesign (ConnectedAppsScreen was page 0) and no longer does.
    final pages = await pumpAndReadPages(tester);

    final connectIndex = pages.indexWhere((w) => w is ConnectedAppsScreen);
    expect(
      connectIndex,
      greaterThan(0),
      reason:
          'Connect Training is expected behind earlier steps. If it moves back '
          'to index 0, _reachConnectTrainingStep in the Patrol integrations '
          'flow becomes wrong in the other direction and must be updated.',
    );
    expect(kOnboardingStepNames[connectIndex], 'connect_training');
  });
}
