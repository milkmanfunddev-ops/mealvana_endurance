import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/meal_planning/application/meal_detail_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/application/meal_plan_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/cooking_session.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_detail.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_plan.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_ref.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_source.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_type.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/ui_action.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/screens/meal_detail_screen.dart';

import '../helpers/test_content.dart';

/// The minimal detail layout (2026-09-03 cleanup): title + original-recipe
/// link, icon-only thumbs · prep tag, macro pills, plain Ingredients /
/// Directions / Swaps labels — and none of the removed clutter (keyword
/// tags, why prose, attribution quote card, fits row, macros disclosure,
/// "Save to mine" label). Labels come from `content_defaults.json`, so these
/// assertions see what the app will actually render.
void main() {
  final content = loadDefaultContent();

  /// A salmon-quinoa-style library meal that used to carry every removed
  /// element: tags, why, Sygo attribution quote, fits row, macros row.
  final detail = MealDetail(
    meal: MealRef(
      source: MealSource.library,
      id: 'D-100',
      name: 'Salmon, quinoa, asparagus & spinach salad',
      mealType: MealType.dinner,
      batch: true,
      kcal: 620,
      carbsG: 52,
      proteinG: 41,
      fatG: 22,
      allergens: const ['fish'],
      dietsOk: const ['mediterranean', 'omnivore', 'pescatarian'],
      why: 'Dinner: salmon, tofu or steak with some quinoa.',
      attribution: 'Jennifer Sygo, runningmagazine.ca',
      // Number only — many library rows have prep_minutes but no prep string.
      prepMinutes: 20,
    ),
    ingredients: const [MealIngredient(name: 'salmon fillet', qty: '150 g')],
    methodSteps: const ['Cook the quinoa.', 'Sear the salmon.'],
    directions: const MealDirections(),
    sourceUrl: 'https://runningmagazine.ca/recipes/salmon-quinoa',
    source: 'Jennifer Sygo says eat your omega-3s.',
    swaps: const ['water → milk (+10g protein)'],
    servings: 2,
  );

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentServiceProvider.overrideWith(testContentService),
          mealDetailControllerProvider(
            'D-100',
          ).overrideWith(() => _FixedDetailController(detail)),
        ],
        child: const MaterialApp(home: MealDetailScreen(id: 'D-100')),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders the minimal layout', (tester) async {
    await pumpScreen(tester);

    // Title + attribution link (host from the source URL).
    expect(find.text('Salmon, quinoa, asparagus & spinach salad'), findsOneWidget);
    expect(
      find.text(content['meal_planning.detail_see_original']!),
      findsOneWidget,
    );
    expect(find.text('runningmagazine.ca'), findsOneWidget);

    // Thumbs are icon-only (keys kept), prep tag rides the same row.
    expect(
      find.byKey(const ValueKey('meal_planning.detail_thumb_up')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('meal_planning.detail_thumb_down')),
      findsOneWidget,
    );
    expect(find.text('20 min'), findsOneWidget);

    // Macro pills, not a disclosure row.
    expect(find.text('620 kcal'), findsOneWidget);
    expect(find.text('52g C'), findsOneWidget);
    expect(find.text('41g P'), findsOneWidget);
    expect(find.text('22g F'), findsOneWidget);

    // Plain section labels (uppercase via _SectionLabel).
    expect(find.text('INGREDIENTS'), findsOneWidget);
    expect(find.text('DIRECTIONS'), findsOneWidget);
    expect(find.text('Salmon fillet'), findsOneWidget);

    // Swaps hide behind the ⇄ on the Ingredients label until toggled.
    expect(find.text('water → milk (+10g protein)'), findsNothing);
    await tester.tap(
      find.byKey(const ValueKey('meal_planning.detail_swaps_toggle')),
    );
    await tester.pumpAndSettle();
    expect(find.text('water → milk (+10g protein)'), findsOneWidget);

    // Heart header button is icon-only but still keyed.
    expect(
      find.byKey(const ValueKey('meal_planning.detail_save_to_mine')),
      findsOneWidget,
    );
  });

  testWidgets('none of the removed clutter renders', (tester) async {
    await pumpScreen(tester);

    // Keyword tags, why prose, quote card, fits row, old labels.
    expect(find.text('Fish'), findsNothing);
    expect(find.text('Batch 2'), findsNothing);
    expect(find.text('Everyday'), findsNothing);
    expect(find.text('Dinner: salmon, tofu or steak with some quinoa.'), findsNothing);
    expect(find.text('Jennifer Sygo'), findsNothing);
    expect(find.text('Jennifer Sygo, runningmagazine.ca'), findsNothing);
    expect(find.text('Fits: mediterranean, omnivore, pescatarian'), findsNothing);
    // Old labels — literals here because their content keys were removed.
    expect(find.text('I like this'), findsNothing);
    expect(find.text('Not for me'), findsNothing);
    expect(find.text('Save to mine'), findsNothing);
    expect(find.text('One serving'), findsNothing);
    expect(find.text('HOW TO COOK'), findsNothing);
    expect(find.text('Show carbs / protein'), findsNothing);
  });

  group('"Add to plan" (?pick= from the Vana browse screen)', () {
    Finder addButton() =>
        find.byKey(const ValueKey('meal_planning.detail_add_to_plan'));

    /// Through a real GoRouter: the button pops `true` back to the browse
    /// screen, which needs a stack to pop.
    Future<void> pumpPick(
      WidgetTester tester, {
      required _RecordingPlanController plan,
      String? pick = 'conv-1',
    }) async {
      final router = GoRouter(
        initialLocation: '/browse/detail',
        routes: [
          GoRoute(
            path: '/browse',
            builder: (_, __) => const Scaffold(body: Text('browse')),
            routes: [
              GoRoute(
                path: 'detail',
                builder: (_, __) => MealDetailScreen(
                  id: 'D-100',
                  pickConversationId: pick,
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
            mealDetailControllerProvider(
              'D-100',
            ).overrideWith(() => _FixedDetailController(detail)),
            mealPlanControllerProvider.overrideWith(() => plan),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
    }

    testWidgets('absent without a pick conversation', (tester) async {
      await pumpScreen(tester);
      expect(addButton(), findsNothing);
    });

    testWidgets('picks into the conversation draft, toasts and pops true', (
      tester,
    ) async {
      final plan = _RecordingPlanController();
      await pumpPick(tester, plan: plan);
      expect(
        find.text(content['meal_planning.detail_add_to_plan']!),
        findsOneWidget,
      );

      await tester.ensureVisible(addButton());
      await tester.tap(addButton());
      await tester.pumpAndSettle();

      final pick = plan.picks.single;
      expect(pick.meals.single.id, 'D-100');
      expect(pick.meals.single.source, MealSource.library);
      expect(pick.servings, 4);
      expect(pick.conversationId, 'conv-1');
      expect(
        find.text(content['meal_planning.browse_added_toast']!),
        findsOneWidget,
      );
      // Popped back to the browse screen.
      expect(find.text('browse'), findsOneWidget);
      expect(addButton(), findsNothing);
    });
  });

  testWidgets('thumbs-down vote shows the muted undo note', (tester) async {
    await pumpScreen(tester);

    expect(
      find.text(content['meal_planning.detail_thumbs_down_note']!),
      findsNothing,
    );
    await tester.tap(
      find.byKey(const ValueKey('meal_planning.detail_thumb_down')),
    );
    await tester.pump();

    expect(
      find.text(content['meal_planning.detail_thumbs_down_note']!),
      findsOneWidget,
    );
  });
}

/// Serves a fixed detail; [vote] updates state locally so the screen's
/// optimistic-render contract is exercised without the remote.
class _FixedDetailController extends MealDetailController {
  _FixedDetailController(this.detail);

  final MealDetail detail;

  @override
  Future<MealDetail> build(String id) async => detail;

  @override
  Future<void> vote(int vote, {String? reason}) async {
    state = AsyncData(detail.copyWith(vote: vote));
  }
}

/// Records every `pickMeals` instead of running the remote-ack action.
class _RecordingPlanController extends MealPlanController {
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
    return null;
  }
}
