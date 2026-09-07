// Back-arrow wiring on the post-onboarding auth screen ("Your plan is ready").
//
// The contract: back from the auth screen returns the athlete to the LAST
// onboarding page (daily plan preview) — never to the first page, and never
// into the app. Two arrivals must both honor it:
//
//  1. push-arrival — the normal flow: the daily preview's "Save My Plan"
//     pushes the auth route, so back pops onto the still-alive PageView.
//  2. go-arrival — the stack was replaced (process restart, router redirect,
//     deep link), so there is nothing to pop and the screen's fallback has to
//     rebuild the onboarding route. A bare go('/onboarding') builds a fresh
//     PageView, and a fresh PageView starts at page 0 — the "back sent me to
//     the first question" bug this file exists for.
//
// These tests pump the REAL screens under a real GoRouter mirroring the app's
// route topology, so the navigation-stack facts (canPop, push vs go) are the
// production ones. Only external deps are mocked.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/auth/presentation/screens/post_onboarding_auth_screen.dart';
import 'package:mealvana_endurance/features/onboarding/application/plan_preview_service.dart';
import 'package:mealvana_endurance/features/onboarding/domain/onboarding_draft.dart';
import 'package:mealvana_endurance/features/onboarding/domain/training_insights.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/providers/onboarding_preview_providers.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/screens/daily_plan_preview_screen.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/screens/onboarding_pageview_screen.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/screens/sports_selection_screen.dart';

import '../../helpers/widget_test_harness.dart';

void main() {
  // A minimal preview bundle so the daily plan preview (the PageView's last
  // page) can build.
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

  /// The app's route topology for this flow, with real builders — mirrors
  /// app_router.dart. /welcome and /main are marker stubs: landing on either
  /// is itself a failure the assertions catch.
  GoRouter buildRouter(String initialLocation) => GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/welcome',
        builder: (context, state) =>
            const Scaffold(body: Text('WELCOME-MARKER')),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => OnboardingPageViewScreen(
          startAtLastPage: state.uri.queryParameters['page'] == 'last',
        ),
      ),
      GoRoute(
        path: '/auth/post-onboarding',
        builder: (context, state) {
          final mode = state.uri.queryParameters['mode'] ?? 'signup';
          return PostOnboardingAuthScreen(mode: mode);
        },
      ),
      GoRoute(
        path: '/main',
        builder: (context, state) => const Scaffold(body: Text('MAIN-MARKER')),
      ),
    ],
  );

  Future<void> pumpRouter(WidgetTester tester, GoRouter router) async {
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
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          minTextAdapt: true,
          splitScreenMode: true,
          builder: (_, __) => MaterialApp.router(routerConfig: router),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Taps the auth screen's back circle (the chevron inside the auth screen —
  /// scoped so an offstage onboarding page's chevron can't be hit instead).
  Future<void> tapAuthBack(WidgetTester tester) async {
    final back = find.descendant(
      of: find.byType(PostOnboardingAuthScreen),
      matching: find.byIcon(Icons.chevron_left),
    );
    expect(back, findsOneWidget, reason: 'auth screen must show a back arrow');
    await tester.tap(back);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'push-arrival: back from the auth screen returns to the daily preview',
    (tester) async {
      final router = buildRouter('/onboarding');
      await pumpRouter(tester, router);

      // Jump the PageView to the last page the way a completed flow would sit.
      final pageView = tester.widget<PageView>(find.byType(PageView));
      pageView.controller!.jumpToPage(8);
      await tester.pumpAndSettle();
      expect(find.byType(DailyPlanPreviewScreen), findsOneWidget);

      // "Save My Plan" — invoke the real onContinue wiring (_nextPage's
      // last-page branch, which must PUSH the auth route).
      tester
          .widget<DailyPlanPreviewScreen>(find.byType(DailyPlanPreviewScreen))
          .onContinue!();
      await tester.pumpAndSettle();
      expect(find.byType(PostOnboardingAuthScreen), findsOneWidget);

      await tapAuthBack(tester);

      expect(
        find.byType(DailyPlanPreviewScreen),
        findsOneWidget,
        reason:
            'back from "Your plan is ready" must land on the daily preview '
            '(the page the athlete came from)',
      );
      expect(
        find.byType(SportsSelectionScreen),
        findsNothing,
        reason: 'back must not rewind the flow to the first question',
      );
      expect(
        find.text('MAIN-MARKER'),
        findsNothing,
        reason: 'back must never enter the app',
      );
    },
  );

  testWidgets(
    'go-arrival (nothing to pop): back still returns to the daily preview, '
    'not the first onboarding page',
    (tester) async {
      // The stack-replaced arrival: restart / redirect lands directly on the
      // auth route, so canPop() is false and the screen's fallback runs.
      final router = buildRouter('/auth/post-onboarding');
      await pumpRouter(tester, router);
      expect(find.byType(PostOnboardingAuthScreen), findsOneWidget);

      await tapAuthBack(tester);

      expect(
        find.byType(SportsSelectionScreen),
        findsNothing,
        reason:
            'THE BUG: with nothing to pop, the fallback go(\'/onboarding\') '
            'builds a fresh PageView at page 0 — nine answered steps behind '
            'the athlete, who was one tap from saving',
      );
      expect(
        find.byType(DailyPlanPreviewScreen),
        findsOneWidget,
        reason:
            'the fallback must restore the flow at its last page, matching '
            'where back-from-auth always lands in the push case',
      );
    },
  );
}
