/// Ticket 131 (Finding 88-016, mp-235): after a confirm the athlete lands on
/// Food > Shopping and the "you're set" card sits at the top of the new
/// list, once, with Share, the reminder chip, Lay it across the week and
/// Adjust. Closing it or leaving Shopping keeps it gone.
///
/// The Food screen and its Plan and Shopping segments are real; the plan
/// controller is a stand-in whose confirm does what the real one does to
/// the card (`youreSetControllerProvider.confirmed`), which
/// `application/meal_plan_controller_test.dart` proves through the real
/// notifier from the producer's `confirm_plan` answer.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/daily_macros/presentation/providers/daily_macros_controller.dart';
import 'package:mealvana_endurance/features/kroger/application/kroger_availability.dart';
import 'package:mealvana_endurance/features/meal_planning/application/home_service.dart';
import 'package:mealvana_endurance/features/meal_planning/application/meal_plan_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/application/previous_plans.dart';
import 'package:mealvana_endurance/features/meal_planning/application/shopping_list_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/application/vana_settings_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/application/youre_set_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_exceptions.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/home_payload.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_plan.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_part.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/week_start.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/screens/food_screen.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/screens/plan_tab.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/screens/shopping_tab.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/vana_situation_scope.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/youre_set_on_shopping.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/run_parameters.dart';
import 'package:mealvana_endurance/shared/providers/unit_system_provider.dart';

import '../../domain/fixture_helpers.dart';
import '../helpers/test_content.dart';

/// Bounded settle: the Plan tab's day-note avatar pulses while the home
/// payload loads, so `pumpAndSettle` never returns.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 150));
  }
}

const _card = ValueKey('meal_planning.confirmed_card');
const _dismiss = ValueKey('meal_planning.confirmed_dismiss');
const _share = ValueKey('meal_planning.confirmed_share');
const _remind = ValueKey('meal_planning.confirmed_remind');
const _layAcross = ValueKey('meal_planning.confirmed_lay_across');
const _adjust = ValueKey('meal_planning.confirmed_adjust');

void main() {
  final content = loadDefaultContent();
  // The producer's own `confirm_plan` answer: the confirmed plan and the
  // list the server built from it.
  final confirmed = MealPlan.fromJson(
    (loadFixture('confirm_plan')['parts'] as List).firstWhere(
          (p) => (p as Map)['kind'] == 'batch',
        )['plan']
        as Map<String, dynamic>,
  );
  final draft = MealPlan.fromJson({...confirmed.toJson(), 'status': 'draft'});
  final week = VanaPart.fromJson(loadFixture('week'))! as VanaWeekPart;

  /// The new list, as the Shopping tab reads it for [planId].
  ShoppingListState listFor(String? planId) {
    final items = confirmed.shopping;
    return ShoppingListState(
      listId: 'list-1',
      listName: 'Week of ${confirmed.weekStart}',
      listDate: DateTime.utc(2026, 8, 30),
      planId: planId,
      isConfirmed: true,
      items: items,
      byAisle: {
        for (final i in items)
          i.aisle: [...items.where((x) => x.aisle == i.aisle)],
      },
      itemCount: items.where((i) => !i.have).length,
    );
  }

  late _FakePlanController plan;
  late ProviderContainer container;

  /// The real Food screen on [initialTab], under a router so Adjust can
  /// open the chat.
  Future<void> pumpFood(
    WidgetTester tester, {
    MealPlan? current,
    FoodTab initialTab = FoodTab.plan,
    ShoppingListState? list,
  }) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    plan = _FakePlanController(current ?? draft, confirmed, week);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => FoodScreen(initialTab: initialTab),
        ),
        GoRoute(
          path: '/vana',
          builder: (_, state) =>
              Scaffold(body: Text('chat ${state.uri.query}')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentServiceProvider.overrideWith(testContentService),
          mealPlanControllerProvider.overrideWith(() => plan),
          previousPlansProvider.overrideWith((ref) async => const []),
          planPeriodProvider.overrideWith(
            (ref) => Stream.value(const PlanPeriod()),
          ),
          homeControllerProvider.overrideWith(_NoHomeController.new),
          vanaSettingsControllerProvider.overrideWith(
            _FakeSettingsController.new,
          ),
          dailyMacrosControllerProvider.overrideWith(_NoMacrosController.new),
          shoppingListControllerProvider.overrideWith(
            () => _FixedList(list ?? listFor(confirmed.id)),
          ),
          unitSystemProvider.overrideWith((ref) async => UnitSystem.imperial),
          krogerEntryVisibleProvider.overrideWithValue(false),
          krogerEntryPendingProvider.overrideWithValue(false),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    container = ProviderScope.containerOf(
      tester.element(find.byType(FoodScreen)),
    );
    await settle(tester);
  }

  Future<void> confirmFromPlanTab(WidgetTester tester) async {
    final confirm = find.byKey(const ValueKey('meal_planning.btn_confirm'));
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await settle(tester);
  }

  testWidgets(
    'Confirm on the Plan tab lands on Shopping with the card at the top',
    (tester) async {
      await pumpFood(tester);
      expect(find.byKey(_card), findsNothing);

      await confirmFromPlanTab(tester);

      expect(plan.confirms, 1);
      expect(find.byType(ShoppingTab), findsOneWidget);
      expect(find.byType(PlanTab), findsNothing);
      final card = find.byKey(_card);
      expect(card, findsOneWidget);
      // At the top of the new list: above the list's own header.
      final header = find.byKey(
        const ValueKey('meal_planning.shopping_list_name'),
      );
      expect(header, findsOneWidget);
      expect(
        tester.getTopLeft(card).dy,
        lessThan(tester.getTopLeft(header).dy),
      );
      // mp-235 details 1 and 3.
      for (final key in [_share, _remind, _layAcross, _adjust, _dismiss]) {
        expect(find.byKey(key), findsOneWidget, reason: '$key');
      }
      expect(
        find.text(content['meal_planning.confirmed_lay_across']!),
        findsOneWidget,
      );
      expect(
        find.text(content['meal_planning.confirmed_adjust']!),
        findsOneWidget,
      );
      // "Open shopping list" is not offered on the list itself.
      expect(
        find.text(content['meal_planning.review_shopping_link']!),
        findsNothing,
      );
      expect(
        find.text(content['meal_planning.confirmed_shopping_row']!),
        findsOneWidget,
      );
    },
  );

  testWidgets('a refused confirm stays on Plan and owes no card', (
    tester,
  ) async {
    await pumpFood(tester);
    plan.confirmFailsWith = const NeedsConnectionException('confirm_plan');

    await confirmFromPlanTab(tester);

    expect(find.byType(PlanTab), findsOneWidget);
    expect(find.byKey(_card, skipOffstage: false), findsNothing);
    expect(container.read(youreSetControllerProvider).value, isNull);
  });

  testWidgets('closed, the card stays gone, and does not come back', (
    tester,
  ) async {
    await pumpFood(tester);
    await confirmFromPlanTab(tester);

    await tester.tap(find.byKey(_dismiss));
    await settle(tester);
    expect(find.byKey(_card), findsNothing);

    // Away to Plan and back: still gone.
    await tester.tap(find.byKey(const ValueKey('meal_planning.tab_plan')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('meal_planning.tab_shopping')));
    await settle(tester);
    expect(find.byKey(_card), findsNothing);
    expect(container.read(youreSetControllerProvider).value, isNull);
  });

  testWidgets('leaving Shopping clears the card for the next open', (
    tester,
  ) async {
    await pumpFood(tester);
    await confirmFromPlanTab(tester);
    expect(find.byKey(_card), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('meal_planning.tab_meals')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('meal_planning.tab_shopping')));
    await settle(tester);

    expect(find.byKey(_card), findsNothing);
  });

  testWidgets(
    'a confirm from the Review sheet (card owed, landing on Shopping) shows it',
    (tester) async {
      await pumpFood(tester, current: confirmed, initialTab: FoodTab.shopping);
      expect(find.byKey(_card), findsNothing);

      // What the Review sheet's confirm leaves behind: the real notifier
      // owes the card for the confirmed plan, and the route lands on
      // Shopping (vana_chat_review_confirm_test).
      container
          .read(youreSetControllerProvider.notifier)
          .confirmed(confirmed.id);
      await settle(tester);

      expect(find.byKey(_card), findsOneWidget);
      for (final key in [_share, _remind, _layAcross, _adjust]) {
        expect(find.byKey(key), findsOneWidget, reason: '$key');
      }
    },
  );

  testWidgets('no card over a list that is not the confirmed plan\'s', (
    tester,
  ) async {
    await pumpFood(
      tester,
      current: confirmed,
      initialTab: FoodTab.shopping,
      list: listFor('another-plan'),
    );
    container.read(youreSetControllerProvider.notifier).confirmed(confirmed.id);
    await settle(tester);

    expect(find.byKey(_card), findsNothing);
  });

  testWidgets('the shell leaving the Food tab clears the card', (tester) async {
    plan = _FakePlanController(confirmed, confirmed, week);
    final visible = ValueNotifier<bool>(true);
    addTearDown(visible.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentServiceProvider.overrideWith(testContentService),
          mealPlanControllerProvider.overrideWith(() => plan),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<bool>(
              valueListenable: visible,
              builder: (_, v, _) => VanaSituationVisibility(
                visible: v,
                child: SingleChildScrollView(
                  child: YoureSetOnShopping(
                    list: listFor(confirmed.id),
                    onShowPlan: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    container = ProviderScope.containerOf(
      tester.element(find.byType(YoureSetOnShopping)),
    );
    container.read(youreSetControllerProvider.notifier).confirmed(confirmed.id);
    await settle(tester);
    expect(find.byKey(_card), findsOneWidget);

    // The athlete taps another tab in the shell, then comes back.
    visible.value = false;
    await settle(tester);
    visible.value = true;
    await settle(tester);

    expect(find.byKey(_card), findsNothing);
    expect(container.read(youreSetControllerProvider).value, isNull);
  });

  testWidgets('Lay it across the week shows the days read-only', (
    tester,
  ) async {
    await pumpFood(tester);
    await confirmFromPlanTab(tester);

    await tester.tap(find.byKey(_layAcross));
    await settle(tester);

    expect(plan.planWeeks, 1);
    expect(
      find.byKey(const ValueKey('meal_planning.week_card')),
      findsOneWidget,
    );
    expect(find.byKey(_card), findsOneWidget, reason: 'the card stays');
    // Its chip shows done and takes no second tap.
    await tester.tap(find.byKey(_layAcross));
    await settle(tester);
    expect(plan.planWeeks, 1);
  });

  testWidgets('Lay it across offline says so and keeps the card', (
    tester,
  ) async {
    await pumpFood(tester);
    await confirmFromPlanTab(tester);
    plan.planWeekFailsWith = const NeedsConnectionException('plan_week');

    await tester.tap(find.byKey(_layAcross));
    await settle(tester);

    expect(
      find.text(content['meal_planning.needs_connection']!),
      findsOneWidget,
    );
    expect(find.byKey(_card), findsOneWidget);
    expect(find.byKey(const ValueKey('meal_planning.week_card')), findsNothing);
  });

  testWidgets('Adjust opens the plan\'s conversation and closes the card', (
    tester,
  ) async {
    await pumpFood(tester);
    await confirmFromPlanTab(tester);

    await tester.tap(find.byKey(_adjust));
    await settle(tester);

    expect(
      find.text('chat c=${confirmed.conversationId}&mode=meal_planning'),
      findsOneWidget,
    );
    expect(container.read(youreSetControllerProvider).value, isNull);
  });
}

class _FakePlanController extends MealPlanController {
  _FakePlanController(this.initial, this.confirmedPlan, this.week);

  final MealPlan initial;
  final MealPlan confirmedPlan;
  final VanaWeekPart week;

  int confirms = 0;
  Exception? confirmFailsWith;
  int planWeeks = 0;
  Exception? planWeekFailsWith;

  @override
  Future<MealPlan?> build() async => initial;

  @override
  Future<void> refresh() async {}

  /// What the real confirm does on an ack: the confirmed plan becomes the
  /// tab's, and the card is owed for it.
  @override
  Future<MealPlan?> confirmPlan({
    String? date,
    String? conversationId,
    String? planId,
  }) async {
    confirms++;
    if (confirmFailsWith case final e?) throw e;
    state = AsyncData(confirmedPlan);
    ref.read(youreSetControllerProvider.notifier).confirmed(confirmedPlan.id);
    return confirmedPlan;
  }

  @override
  Future<VanaWeekPart?> planWeek() async {
    planWeeks++;
    if (planWeekFailsWith case final e?) throw e;
    return week;
  }
}

class _FixedList extends ShoppingListController {
  _FixedList(this.seed);

  final ShoppingListState seed;

  @override
  ShoppingListState build() => seed;
}

class _NoHomeController extends HomeController {
  @override
  Future<HomePayload?> build([String? date]) async => null;
}

class _FakeSettingsController extends VanaSettingsController {
  @override
  Future<VanaSettingsState> build() async => const VanaSettingsState();
}

class _NoMacrosController extends DailyMacrosController {
  @override
  Future<DailyMacrosState> build() async =>
      throw StateError('no macros in this test');
}
