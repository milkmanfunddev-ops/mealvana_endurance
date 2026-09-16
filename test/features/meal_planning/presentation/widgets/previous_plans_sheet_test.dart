import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/meal_planning/application/meal_plan_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/application/previous_plans.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_plan_summary.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/week_start.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/previous_plans_sheet.dart';

import '../helpers/test_content.dart';

/// The earlier-plans sheet: rows newest first with week and meal count, a
/// tap closes the sheet and hands over the id, and the empty and failed
/// states each say so.
void main() {
  final rows = [
    MealPlanSummary.fromJson({
      'id': 'plan-a',
      'weekStart': '2026-09-06',
      'status': 'archived',
      'batchCooking': true,
      'mealCount': 4,
    }),
    MealPlanSummary.fromJson({
      'id': 'plan-b',
      'weekStart': '2026-08-30',
      'status': 'confirmed',
      'batchCooking': false,
      'mealCount': 1,
    }),
  ];

  Future<void> pumpSheet(
    WidgetTester tester, {
    required Future<List<MealPlanSummary>> Function() plans,
    required ValueChanged<String> onOpen,
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentServiceProvider.overrideWith(testContentService),
          previousPlansProvider.overrideWith((ref) => plans()),
          planPeriodProvider.overrideWith(
            (ref) => Stream.value(const PlanPeriod()),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                key: const ValueKey('open'),
                onPressed: () =>
                    showPreviousPlansSheet(context: context, onOpen: onOpen),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('open')));
    await tester.pumpAndSettle();
  }

  testWidgets('lists each plan with its week and meal count', (tester) async {
    await pumpSheet(tester, plans: () async => rows, onOpen: (_) {});

    expect(
      find.byKey(const ValueKey('meal_planning.previous_plans_sheet')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('meal_planning.previous_plan_plan-a')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('meal_planning.previous_plan_plan-b')),
      findsOneWidget,
    );
    expect(find.text('Sep 6 – Sep 12'), findsOneWidget);
    expect(find.text('Aug 30 – Sep 5'), findsOneWidget);
    final content = loadDefaultContent();
    expect(find.text('4 meals'), findsOneWidget);
    expect(
      find.text(content['meal_planning.plan_week_meal_one']!),
      findsOneWidget,
    );
  });

  testWidgets('tapping a plan closes the sheet and hands over its id', (
    tester,
  ) async {
    final opened = <String>[];
    await pumpSheet(tester, plans: () async => rows, onOpen: opened.add);

    await tester.tap(
      find.byKey(const ValueKey('meal_planning.previous_plan_plan-b')),
    );
    await tester.pumpAndSettle();

    expect(opened, ['plan-b']);
    expect(
      find.byKey(const ValueKey('meal_planning.previous_plans_sheet')),
      findsNothing,
    );
  });

  testWidgets('no earlier plans says so', (tester) async {
    await pumpSheet(tester, plans: () async => const [], onOpen: (_) {});

    expect(
      find.byKey(const ValueKey('meal_planning.previous_plans_empty')),
      findsOneWidget,
    );
  });

  testWidgets('a failed read says so rather than spinning', (tester) async {
    await pumpSheet(
      tester,
      plans: () async => throw StateError('offline'),
      onOpen: (_) {},
    );

    expect(
      find.byKey(const ValueKey('meal_planning.previous_plans_failed')),
      findsOneWidget,
    );
  });
}
