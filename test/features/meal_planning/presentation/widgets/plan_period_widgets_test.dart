/// Ticket 29 (mp-269): the review sheet, the week card and the plan summary
/// read the athlete's period — its length and the day it starts — instead of
/// a fixed Sunday week.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_plan.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_part.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/plan_summary.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/review_sheet.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/week_card.dart';

import '../../domain/fixture_helpers.dart';
import '../helpers/test_content.dart';

/// The draft batch fixture with two batch meals, the first cooked on the
/// period's cook day and the second at its top-up.
MealPlan _plan({
  required String weekStart,
  required int periodDays,
  bool batchCooking = true,
  int covered = 8,
}) {
  final json = Map<String, dynamic>.from(
    (loadFixture('batch')['parts'] as List).first['plan'] as Map,
  );
  final meals = [
    for (final m in json['meals'] as List) Map<String, dynamic>.from(m as Map),
  ];
  meals[0]['session'] = 'cook-sun';
  meals[1]['session'] = 'topup-wed';
  for (final m in meals.skip(2)) {
    m['session'] = 'cook-sun';
  }
  return MealPlan.fromJson({
    ...json,
    'weekStart': weekStart,
    'status': 'draft',
    'batchCooking': batchCooking,
    'meals': meals,
    'coverage': {
      ...Map<String, dynamic>.from(json['coverage'] as Map),
      'periodDays': periodDays,
      'lunchDinnerSlots': periodDays * 2,
      'covered': covered,
    },
  });
}

void main() {
  Future<void> openReview(WidgetTester tester, MealPlan plan) async {
    await tester.binding.setSurfaceSize(const Size(430, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [contentServiceProvider.overrideWith(testContentService)],
        child: MaterialApp(
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: TextButton(
                onPressed: () => showReviewSheet(
                  context: context,
                  ref: ref,
                  plan: plan,
                  onTapMeal: (_) {},
                  onServings: (_, __) {},
                  onRemove: (_) {},
                  onConfirm: () async => true,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('review sheet', () {
    testWidgets('a Sunday week keeps "Your week", Sunday and Wednesday', (
      tester,
    ) async {
      await openReview(tester, _plan(weekStart: '2026-09-13', periodDays: 7));
      expect(find.text('Your week'), findsOneWidget);
      expect(find.text('Cook Sunday'), findsOneWidget);
      expect(find.text('Top-up Wednesday'), findsOneWidget);
    });

    testWidgets(
      'a ten-day period from Monday titles the days and moves the cook days',
      (tester) async {
        await openReview(
          tester,
          _plan(weekStart: '2026-09-14', periodDays: 10),
        );
        expect(find.text('Your 10 days'), findsOneWidget);
        // Cook on the Monday the period starts; top-up four days in.
        expect(find.text('Cook Monday'), findsOneWidget);
        expect(find.text('Top-up Friday'), findsOneWidget);
        expect(find.text('Cook Sunday'), findsNothing);
      },
    );
  });

  group('review sheet coverage (mp-231)', () {
    testWidgets('a batch counts servings against the period', (tester) async {
      await openReview(
        tester,
        _plan(weekStart: '2026-09-14', periodDays: 10, covered: 8),
      );
      expect(find.text('8 of 20 servings across 10 days'), findsOneWidget);
    });

    testWidgets('an athlete who cooks the night of counts nights', (
      tester,
    ) async {
      await openReview(
        tester,
        _plan(
          weekStart: '2026-09-13',
          periodDays: 7,
          batchCooking: false,
          covered: 5,
        ),
      );
      expect(find.text('5 of 14 nights planned'), findsOneWidget);
    });
  });

  group('week card', () {
    final week = VanaPart.fromJson(loadFixture('week')) as VanaWeekPart;

    Future<void> pump(WidgetTester tester, VanaWeekPart part) =>
        tester.pumpWidget(
          ProviderScope(
            overrides: [
              contentServiceProvider.overrideWith(testContentService),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(child: WeekCard(part: part)),
              ),
            ),
          ),
        );

    testWidgets('a part without a period reads as a week', (tester) async {
      await pump(tester, week);
      expect(find.text('Your week, laid out'), findsOneWidget);
    });

    testWidgets('a ten-day part is titled with its length', (tester) async {
      await pump(tester, week.copyWith(periodDays: 10));
      expect(find.text('Your 10 days, laid out'), findsOneWidget);
    });
  });

  group('plan summary', () {
    test('the label spans the period from its start day', () {
      expect(PlanSummary.weekLabel('2026-09-13'), 'Sep 13 – Sep 19');
      expect(PlanSummary.weekLabel('2026-09-14', 10), 'Sep 14 – Sep 23');
    });
  });
}
