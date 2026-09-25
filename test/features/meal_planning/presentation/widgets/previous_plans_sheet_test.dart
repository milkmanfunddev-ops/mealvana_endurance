import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/meal_planning/application/meal_plan_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/application/previous_plans.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_action_client.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_plan.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_plan_summary.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/week_start.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/previous_plans_sheet.dart';

import '../../domain/fixture_helpers.dart';
import '../helpers/test_content.dart';

/// The Plan tab's plan, as the sheet sees it: nothing until a test makes
/// one this week's (a Use again confirmed, ticket 97).
class _TabPlan extends MealPlanController {
  @override
  Future<MealPlan?> build() async => null;

  void becomes(MealPlan plan) => state = AsyncData(plan);
}

/// The earlier-plans sheet: rows newest first with week and meal count, the
/// week's confirmed plan tagged, a tap hands over the id and keeps the sheet
/// under the plan's view so Back lands on it where it was (ticket 97), and
/// the empty and failed states each say so.
void main() {
  const sheetKey = ValueKey('meal_planning.previous_plans_sheet');
  const planPage = ValueKey('plan_page');
  final nav = GlobalKey<NavigatorState>();

  /// What plan_tab.dart does with the id: pushes the plan's view.
  void pushPlanPage(String id) {
    nav.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(key: planPage, body: Text('plan $id')),
      ),
    );
  }

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
          mealPlanControllerProvider.overrideWith(_TabPlan.new),
        ],
        child: MaterialApp(
          navigatorKey: nav,
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

  // Ticket 73 (mp-675): a plan the athlete renamed leads with its name.
  testWidgets('a named plan shows its name, with its week under it', (
    tester,
  ) async {
    final named = [
      MealPlanSummary.fromJson({
        'id': 'plan-n',
        'name': 'Race block',
        'weekStart': '2026-09-13',
        'status': 'archived',
        'batchCooking': true,
        'mealCount': 4,
      }),
    ];
    await pumpSheet(tester, plans: () async => named, onOpen: (_) {});

    expect(find.text('Race block'), findsOneWidget);
    expect(find.text('Sep 13 – Sep 19 · 4 meals'), findsOneWidget);
  });

  // Ticket 97, Finding 17-004: the week's confirmed plan is told apart.
  testWidgets('the confirmed plan wears a Confirmed tag; a replaced one none', (
    tester,
  ) async {
    await pumpSheet(tester, plans: () async => rows, onOpen: (_) {});
    final content = loadDefaultContent();

    final tagB = find.byKey(
      const ValueKey('meal_planning.previous_plan_confirmed_plan-b'),
    );
    expect(tagB, findsOneWidget);
    expect(
      find.descendant(
        of: tagB,
        matching: find.text(content['meal_planning.plan_state_confirmed']!),
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(
        const ValueKey('meal_planning.previous_plan_confirmed_plan-a'),
      ),
      findsNothing,
    );
  });

  // Ticket 97, Finding 17-007: the plan's view opens over the sheet, so Back
  // lands on the sheet rather than the Plan tab.
  testWidgets('tapping a plan hands over its id and keeps the sheet under '
      'the plan\'s view; Back lands on the sheet', (tester) async {
    final opened = <String>[];
    await pumpSheet(
      tester,
      plans: () async => rows,
      onOpen: (id) {
        opened.add(id);
        pushPlanPage(id);
      },
    );

    await tester.tap(
      find.byKey(const ValueKey('meal_planning.previous_plan_plan-b')),
    );
    await tester.pumpAndSettle();

    expect(opened, ['plan-b']);
    expect(find.byKey(planPage), findsOneWidget);
    expect(find.byKey(sheetKey), findsNothing, reason: 'under the view');
    expect(find.byKey(sheetKey, skipOffstage: false), findsOneWidget);

    nav.currentState!.pop();
    await tester.pumpAndSettle();

    expect(find.byKey(planPage), findsNothing);
    expect(find.byKey(sheetKey), findsOneWidget);
  });

  testWidgets('Back from an earlier plan finds the sheet where it was '
      'scrolled', (tester) async {
    final many = [
      for (var i = 0; i < 25; i++)
        MealPlanSummary.fromJson({
          'id': 'plan-$i',
          'weekStart': DateTime.utc(
            2026,
            9,
            13,
          ).subtract(Duration(days: 7 * i)).toIso8601String().substring(0, 10),
          'status': 'archived',
          'batchCooking': true,
          'mealCount': 3,
        }),
    ];
    await pumpSheet(tester, plans: () async => many, onOpen: pushPlanPage);
    final last = find.byKey(
      const ValueKey('meal_planning.previous_plan_plan-24'),
    );
    await tester.scrollUntilVisible(
      last,
      200,
      scrollable: find
          .descendant(
            of: find.byKey(sheetKey),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    final offset = tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byKey(sheetKey),
                matching: find.byType(Scrollable),
              )
              .first,
        )
        .position
        .pixels;
    expect(offset, greaterThan(0));

    await tester.tap(last);
    await tester.pumpAndSettle();
    nav.currentState!.pop();
    await tester.pumpAndSettle();

    expect(find.byKey(sheetKey), findsOneWidget);
    expect(last.hitTestable(), findsOneWidget, reason: 'still scrolled to it');
    expect(
      tester
          .state<ScrollableState>(
            find
                .descendant(
                  of: find.byKey(sheetKey),
                  matching: find.byType(Scrollable),
                )
                .first,
          )
          .position
          .pixels,
      offset,
    );
  });

  // A Use again confirmed from the plan's view makes it this week's plan:
  // the athlete's business is now the Plan tab, so the sheet goes too.
  testWidgets('the sheet closes when this week\'s plan changes under it', (
    tester,
  ) async {
    await pumpSheet(tester, plans: () async => rows, onOpen: pushPlanPage);
    await tester.tap(
      find.byKey(const ValueKey('meal_planning.previous_plan_plan-b')),
    );
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(planPage)),
    );
    final confirmed = VanaActionResult.fromJson(loadFixture('batch')).plan!;
    (container.read(mealPlanControllerProvider.notifier) as _TabPlan).becomes(
      confirmed,
    );
    // The view closes itself after the confirm, as the real one does.
    nav.currentState!.pop();
    await tester.pumpAndSettle();

    expect(find.byKey(planPage), findsNothing);
    expect(find.byKey(sheetKey, skipOffstage: false), findsNothing);
  });

  // Ticket 49, Finding 17-001: every plan the server lists can be reached.
  testWidgets('twenty-five plans scroll to the oldest with no overflow', (
    tester,
  ) async {
    final many = [
      for (var i = 0; i < 25; i++)
        MealPlanSummary.fromJson({
          'id': 'plan-$i',
          'weekStart': DateTime.utc(
            2026,
            9,
            13,
          ).subtract(Duration(days: 7 * i)).toIso8601String().substring(0, 10),
          'status': 'archived',
          'batchCooking': true,
          'mealCount': 3,
        }),
    ];
    final opened = <String>[];
    await pumpSheet(tester, plans: () async => many, onOpen: opened.add);
    expect(tester.takeException(), isNull);

    final last = find.byKey(
      const ValueKey('meal_planning.previous_plan_plan-24'),
    );
    await tester.scrollUntilVisible(
      last,
      200,
      scrollable: find
          .descendant(
            of: find.byKey(
              const ValueKey('meal_planning.previous_plans_sheet'),
            ),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(last);
    await tester.pumpAndSettle();
    expect(opened, ['plan-24']);
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
