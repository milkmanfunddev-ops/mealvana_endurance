/// Ticket 50 (testing-wave; Finding 24-002): a describe or photo log ends the
/// diary with the save counted.
///
/// Through the real Log a Meal and Review & Log screens under a real
/// GoRouter: Describe → Analyze pops Log a Meal and pushes Review & Log;
/// `diary_closed` must wait for Review & Log to close, and count the meal
/// logged there. Only the AI call, the meal write and the user lookup are
/// faked; analytics land in a recording sink.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/meal_logging/application/meal_ai_service.dart';
import 'package:mealvana_endurance/features/meal_logging/application/meal_logging_service.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_analysis_result.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log_source.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_slot.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/providers/meal_log_providers.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/screens/log_meal_screen.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/screens/meal_review_screen.dart';
import 'package:mealvana_endurance/features/subscription/application/pro_gate.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fakes/recording_analytics_tracker.dart';
import '../../helpers/widget_test_harness.dart';
import '../meal_planning/helpers/fakes.dart';
import '../meal_planning/presentation/helpers/test_content.dart';

const _logDate = '2026-09-24';

class _MockAi extends Mock implements MealAiService {}

class _MockService extends Mock implements MealLoggingService {}

class _MockUserRepo extends Mock implements UserRepository {}

class _MockUser extends Mock implements UserProfile {}

class _MockPrefs extends Mock implements SharedPreferences {}

class _FakeMealLog extends Fake implements MealLog {}

const _result = MealAnalysisResult(
  name: 'Chicken rice bowl',
  suggestedSlot: MealSlot.lunch,
  confidence: MealAnalysisConfidence.high,
  items: [
    MealAnalysisItem(
      name: 'Chicken',
      portion: '150 g',
      calories: 250,
      carbG: 0,
      proteinG: 45,
      fatG: 6,
      sodiumMg: 90,
    ),
  ],
  totals: MealAnalysisTotals(
    calories: 250,
    carbG: 0,
    proteinG: 45,
    fatG: 6,
    sodiumMg: 90,
  ),
);

void main() {
  setUpAll(() {
    registerFallbackValue(MealLogSource.manual);
  });

  testWidgets(
    'describe → Review & Log → Log this meal: diary_closed after the save, '
    'items_logged 1',
    (tester) async {
      tester.view.physicalSize = standardPhoneSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final analytics = RecordingAnalyticsTracker();
      final ai = _MockAi();
      when(() => ai.describeMeal(any())).thenAnswer((_) async => _result);
      final service = _MockService();
      when(
        () => service.logFromComponents(
          userId: any(named: 'userId'),
          name: any(named: 'name'),
          slot: any(named: 'slot'),
          logDate: any(named: 'logDate'),
          source: any(named: 'source'),
          components: any(named: 'components'),
          photoPath: any(named: 'photoPath'),
          notes: any(named: 'notes'),
          eatenAt: any(named: 'eatenAt'),
        ),
      ).thenAnswer((_) async => _FakeMealLog());
      final user = _MockUser();
      when(() => user.id).thenReturn('user-1');
      final userRepo = _MockUserRepo();
      when(() => userRepo.getCurrentUser()).thenAnswer((_) async => user);

      final router = GoRouter(
        initialLocation: '/main',
        routes: [
          GoRoute(
            path: '/main',
            builder: (context, _) => Scaffold(
              body: TextButton(
                onPressed: () => context.push('/log'),
                child: const Text('open diary'),
              ),
            ),
          ),
          GoRoute(
            path: '/log',
            builder: (_, _) =>
                const LogMealScreen(logDate: _logDate, source: 'test'),
          ),
          GoRoute(
            path: '/meal-log/review',
            builder: (_, _) => const MealReviewScreen(),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appExternalDepsProvider.overrideWithValue(
              AppExternalDeps(
                analytics: analytics,
                supabaseClient: supabaseWithSession(),
                sentry: const NoopSentryReporter(),
                logger: const NoopAppLogger(),
                sharedPreferences: _MockPrefs(),
              ),
            ),
            appConfigProvider.overrideWithValue(AppConfig.forTesting()),
            mockSharedPreferences(),
            writeAccessProvider.overrideWithValue(const AsyncData(true)),
            contentServiceProvider.overrideWith(testContentService),
            mealAiServiceProvider.overrideWithValue(ai),
            mealLoggingServiceProvider.overrideWithValue(service),
            userRepositoryProvider.overrideWith((ref) async => userRepo),
          ],
          child: ScreenUtilInit(
            designSize: const Size(393, 852),
            builder: (_, _) => MaterialApp.router(routerConfig: router),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('open diary'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.text('Describe'));
      await tester.pump();
      await tester.enterText(find.byType(TextFormField), 'chicken and rice');
      await tester.pump();
      await tester.tap(find.text('Analyze'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      // Log a Meal has closed under Review & Log; the diary is still open.
      expect(find.byType(LogMealScreen), findsNothing);
      expect(find.byType(MealReviewScreen), findsOneWidget);
      expect(analytics.hasEvent('diary_closed'), isFalse);

      await tester.tap(find.text('Log this meal'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }

      expect(find.byType(MealReviewScreen), findsNothing);
      final names = analytics.events.map((e) => e.name).toList();
      expect(names, containsAllInOrder(['meal_logged', 'diary_closed']));
      final closed = analytics.findEvents('diary_closed');
      expect(closed, hasLength(1));
      expect(closed.single.properties, {
        'duration_sec': isA<int>(),
        'items_logged': 1,
        'log_date': _logDate,
      });
    },
  );
}
