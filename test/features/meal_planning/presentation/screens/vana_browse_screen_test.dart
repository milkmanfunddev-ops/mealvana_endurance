import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/meal_planning/application/meal_catalog_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/application/meal_plan_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/data/meal_library_remote_data_source.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_action_client.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_exceptions.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/cooking_session.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_plan.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_ref.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_source.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_type.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/plan_meal.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/ui_action.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/screens/vana_browse_screen.dart';

import '../../domain/fixture_helpers.dart';
import '../helpers/test_content.dart';

/// `/vana/browse?c=` — the catalog with an Add affordance on every card:
/// a tap picks into THIS conversation's draft at the default servings,
/// ticks the card and toasts; a failure leaves the card untouched; "Done"
/// pops back to the chat. Rendered through a real GoRouter so `context.pop`
/// has a stack to pop.
void main() {
  final content = loadDefaultContent();

  /// A catalog meal with its numbers, as `search_meals` sends one.
  MealRef recipe(String id, String name) => MealRef(
    source: MealSource.library,
    id: id,
    name: name,
    mealType: MealType.dinner,
    kind: MealKind.recipe,
    kcal: 600,
    carbsG: 70,
    proteinG: 35,
    fatG: 15,
  );

  /// A library meal added without its numbers (mp-678): the row as the
  /// database sends it, every number null.
  final blank = MealLibraryRemoteDataSource.rowToMealRef({
    'id': 'AD-103',
    'name': 'Farro & cauliflower bowl',
    'meal_type': 'dinner',
    'source': 'library',
    'kind': 'recipe',
    'kcal': null,
    'carbs_g': null,
    'protein_g': null,
    'fat_g': null,
  })!;

  final catalog = MealCatalogState(
    recipes: [recipe('D-1', 'Salmon quinoa bowl'), recipe('D-2', 'Dal')],
    assemblies: [recipe('A-1', 'Toast and eggs')],
    railsFromServer: true,
  );

  /// The conversation's plan as Drift holds it (producer-shaped `batch`
  /// fixture, its meals replaced by the ids this catalog shows).
  MealPlan planHolding(List<String> libraryIds) {
    final fixture = VanaActionResult.fromJson(loadFixture('batch')).plan!;
    return fixture.copyWith(
      conversationId: 'conv-1',
      meals: [
        for (final id in libraryIds)
          PlanMeal(
            id: 'pm-$id',
            planId: fixture.id,
            source: MealSource.library,
            libraryMealId: id,
            name: id,
            mealType: MealType.dinner,
            servings: 4,
            servingsLeft: 4,
          ),
      ],
    );
  }

  Future<GoRouter> pumpScreen(
    WidgetTester tester, {
    required _RecordingPlanController plan,
    MealPlan? inPlan,
    MealCatalogState? catalogState,
  }) async {
    final router = GoRouter(
      initialLocation: '/vana/browse?c=conv-1',
      routes: [
        GoRoute(
          path: '/vana',
          builder: (_, __) => const Scaffold(body: Text('chat')),
          routes: [
            GoRoute(
              path: 'browse',
              builder: (_, state) => VanaBrowseScreen(
                conversationId: state.uri.queryParameters['c']!,
              ),
            ),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentServiceProvider.overrideWith(testContentService),
          mealCatalogControllerProvider.overrideWith(
            () => _FixedCatalogController(catalogState ?? catalog),
          ),
          mealPlanControllerProvider.overrideWith(() => plan),
          conversationDraftProvider(
            'conv-1',
          ).overrideWith((ref) => Stream.value(inPlan)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    return router;
  }

  Finder addButton(String id) =>
      find.byKey(ValueKey('meal_planning.browse_add_$id'));

  testWidgets('every rail card carries an Add button', (tester) async {
    await pumpScreen(tester, plan: _RecordingPlanController());

    expect(find.text(content['meal_planning.browse_title']!), findsOneWidget);
    expect(addButton('D-1'), findsOneWidget);
    expect(addButton('D-2'), findsOneWidget);
    expect(addButton('A-1'), findsOneWidget);
  });

  testWidgets('Add picks into the conversation draft, ticks and toasts', (
    tester,
  ) async {
    final plan = _RecordingPlanController();
    await pumpScreen(tester, plan: plan);

    await tester.tap(addButton('D-1'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final pick = plan.picks.single;
    expect(pick.meals.single.id, 'D-1');
    expect(pick.meals.single.source, MealSource.library);
    expect(pick.servings, VanaBrowseScreen.defaultServings);
    expect(pick.conversationId, 'conv-1');

    // Ticked: the check icon inside this card's button, the plus gone.
    expect(
      find.descendant(of: addButton('D-1'), matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: addButton('D-1'), matching: find.byIcon(Icons.add)),
      findsNothing,
    );
    // The other cards are untouched.
    expect(
      find.descendant(of: addButton('D-2'), matching: find.byIcon(Icons.add)),
      findsOneWidget,
    );
    expect(
      find.text(content['meal_planning.browse_added_toast']!),
      findsOneWidget,
    );

    // A ticked card does not pick again.
    await tester.tap(addButton('D-1'), warnIfMissed: false);
    await tester.pump();
    expect(plan.picks, hasLength(1));
  });

  testWidgets('a failed pick leaves the card un-ticked and warns', (
    tester,
  ) async {
    final plan = _RecordingPlanController(
      failWith: const NeedsConnectionException('pick_meals'),
    );
    await pumpScreen(tester, plan: plan);

    await tester.tap(addButton('D-2'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(plan.picks, hasLength(1));
    expect(
      find.descendant(of: addButton('D-2'), matching: find.byIcon(Icons.add)),
      findsOneWidget,
    );
    expect(
      find.text(content['meal_planning.needs_connection']!),
      findsOneWidget,
    );
  });

  /// Testing-wave 129 (Finding 88-013): a pick cut off by the network fell
  /// into the server error ("Something went wrong"). It says it needs a
  /// connection, the same as one refused before sending.
  testWidgets('Add offline says it needs a connection, not something went '
      'wrong', (tester) async {
    final plan = _RecordingPlanController(
      failWith: const VanaOfflineException('socket'),
    );
    await pumpScreen(tester, plan: plan);

    await tester.tap(addButton('D-2'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(plan.picks, hasLength(1));
    expect(
      find.descendant(of: addButton('D-2'), matching: find.byIcon(Icons.add)),
      findsOneWidget,
    );
    expect(
      find.text(content['meal_planning.needs_connection']!),
      findsOneWidget,
    );
    expect(find.text(content['meal_planning.server_error']!), findsNothing);
  });

  /// Testing-wave 18-003: reopened Browse showed meals already in the
  /// draft with a plain plus, because the ticks lived only in the screen's
  /// own state. The conversation's plan is what decides a tick.
  testWidgets('opens with the meals already in the conversation plan ticked', (
    tester,
  ) async {
    final plan = _RecordingPlanController();
    await pumpScreen(tester, plan: plan, inPlan: planHolding(['D-2']));
    await tester.pump();

    expect(
      find.descendant(of: addButton('D-2'), matching: find.byIcon(Icons.check)),
      findsOneWidget,
    );
    expect(
      find.descendant(of: addButton('D-1'), matching: find.byIcon(Icons.add)),
      findsOneWidget,
    );
    expect(plan.picks, isEmpty);
  });

  /// Testing-wave 18-001: a tap on the tick fell through to the card, whose
  /// body opened the detail, and its Add to plan added the meal again.
  testWidgets('a tap on a ticked card picks nothing and opens nothing', (
    tester,
  ) async {
    final plan = _RecordingPlanController();
    await pumpScreen(tester, plan: plan, inPlan: planHolding(['D-2']));
    await tester.pump();

    await tester.tap(addButton('D-2'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(plan.picks, isEmpty);
    expect(
      find.byKey(const ValueKey('meal_planning.vana_browse_screen')),
      findsOneWidget,
      reason: 'the tap never reached the card body (no detail push)',
    );
    expect(find.text(content['meal_planning.browse_added']!), findsWidgets);
  });

  /// mp-678 (testing-wave 74 / 61-001): a meal with missing numbers stays
  /// listed, but its Add says it can't go in a plan and never asks the server.
  testWidgets('a meal with missing numbers is listed, its Add unavailable', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final plan = _RecordingPlanController();
    await pumpScreen(
      tester,
      plan: plan,
      catalogState: catalog.copyWith(recipes: [blank, ...catalog.recipes]),
    );

    final message = content['meal_planning.browse_no_numbers']!;
    expect(find.text('Farro & cauliflower bowl'), findsOneWidget);
    expect(addButton('AD-103'), findsOneWidget);
    expect(
      tester.getSemantics(addButton('AD-103')),
      isSemantics(label: message, isButton: true),
    );

    await tester.tap(addButton('AD-103'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(plan.picks, isEmpty, reason: 'the server is never asked');
    expect(find.text(message), findsOneWidget);
    expect(
      find.byKey(const ValueKey('meal_planning.vana_browse_screen')),
      findsOneWidget,
      reason: 'the tap never reached the card body (no detail push)',
    );
    // A meal with its numbers beside it still adds.
    await tester.tap(addButton('D-1'));
    await tester.pump();
    expect(plan.picks.single.meals.single.id, 'D-1');
    handle.dispose();
  });

  /// Testing-wave 18-005: the filter menu showed the active filters by
  /// colour only; VoiceOver read all seven items as plain buttons.
  testWidgets('the filter menu marks the active filters as selected', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpScreen(
      tester,
      plan: _RecordingPlanController(),
      catalogState: catalog.copyWith(
        mealType: MealType.dinner,
        kind: MealKind.recipe,
      ),
    );

    await tester.tap(find.byKey(const ValueKey('meal_planning.filter_button')));
    await tester.pumpAndSettle();

    Finder item(String key) => find.descendant(
      of: find.byType(PopupMenuItem<String>),
      matching: find.text(content[key]!),
    );

    expect(
      tester.getSemantics(item('meal_planning.meal_type_dinner')),
      isSemantics(isButton: true, isSelected: true),
    );
    expect(
      tester.getSemantics(item('meal_planning.filter_recipes')),
      isSemantics(isButton: true, isSelected: true),
    );
    expect(
      tester.getSemantics(item('meal_planning.meal_type_lunch')),
      isSemantics(isButton: true, isSelected: false),
    );
    expect(
      tester.getSemantics(item('meal_planning.filter_any_type')),
      isSemantics(isButton: true, isSelected: false),
    );
    handle.dispose();
  });

  testWidgets('Done pops back to the chat', (tester) async {
    await pumpScreen(tester, plan: _RecordingPlanController());

    await tester.tap(find.byKey(const ValueKey('meal_planning.browse_done')));
    await tester.pumpAndSettle();

    expect(find.text('chat'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('meal_planning.vana_browse_screen')),
      findsNothing,
    );
  });
}

/// Serves a fixed catalog; no search, no server rails.
class _FixedCatalogController extends MealCatalogController {
  _FixedCatalogController(this.fixed);

  final MealCatalogState fixed;

  @override
  FutureOr<MealCatalogState> build(CatalogSurface surface) => fixed;
}

/// Records every `pickMeals` instead of running the remote-ack action.
class _RecordingPlanController extends MealPlanController {
  _RecordingPlanController({this.failWith});

  final Object? failWith;
  final List<PickMealsAction> picks = [];

  @override
  Future<MealPlan?> build() async => null;

  @override
  Future<MealPlan?> pickMeals(
    List<MealPick> meals, {
    int? servings,
    CookingSession? session,
    bool sendSession = false,
    String? conversationId,
    String? planId,
  }) async {
    picks.add(
      PickMealsAction(
        meals: meals,
        servings: servings,
        conversationId: conversationId,
      ),
    );
    if (failWith != null) throw failWith!;
    return null;
  }
}
