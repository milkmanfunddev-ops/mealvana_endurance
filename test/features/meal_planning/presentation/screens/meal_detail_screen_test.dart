import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/content/domain/content_keys.dart';
import 'package:mealvana_endurance/features/meal_planning/application/meal_detail_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/application/meal_plan_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/cooking_session.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/directions_origin.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_detail.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_plan.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_ref.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_source.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_type.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/ui_action.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/screens/meal_detail_screen.dart';
import 'package:mealvana_endurance/shared/providers/is_admin_provider.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/meal_photo_view.dart';

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

  late _FixedDetailController controller;

  Future<void> pumpScreen(WidgetTester tester, {bool admin = false}) async {
    controller = _FixedDetailController(detail);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          contentServiceProvider.overrideWith(testContentService),
          isAdminProvider.overrideWith((ref) async => admin),
          mealDetailControllerProvider('D-100').overrideWith(() => controller),
        ],
        child: const MaterialApp(home: MealDetailScreen(id: 'D-100')),
      ),
    );
    await tester.pump();
  }

  testWidgets('renders the minimal layout', (tester) async {
    await pumpScreen(tester);

    // Title + attribution link (host from the source URL).
    expect(
      find.text('Salmon, quinoa, asparagus & spinach salad'),
      findsOneWidget,
    );
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

  // ── Admin review box (mp-144 clause 3) ────────────────────────────────
  group('admin review box', () {
    final boxKey = const ValueKey('meal_planning.detail_admin_review');

    testWidgets('an athlete never sees the box', (tester) async {
      await pumpScreen(tester);
      await tester.pump();
      expect(find.byKey(boxKey), findsNothing);
      expect(
        find.text(content['meal_planning.detail_review_title']!),
        findsNothing,
      );
    });

    testWidgets('an admin sees it under the thumbs and sends one review', (
      tester,
    ) async {
      await pumpScreen(tester, admin: true);
      await tester.pump();
      expect(find.byKey(boxKey), findsOneWidget);

      // Box sits below the thumbs row.
      final thumbsY = tester
          .getTopLeft(
            find.byKey(const ValueKey('meal_planning.detail_thumb_up')),
          )
          .dy;
      expect(tester.getTopLeft(find.byKey(boxKey)).dy, greaterThan(thumbsY));

      // Send is disabled until a verdict and a reason are given.
      await tester.tap(
        find.byKey(const ValueKey('meal_planning.detail_review_send')),
        warnIfMissed: false,
      );
      await tester.pump();
      expect(controller.reviews, isEmpty);

      await tester.tap(
        find.byKey(const ValueKey('meal_planning.detail_review_not_good')),
      );
      await tester.enterText(
        find.byKey(const ValueKey('meal_planning.detail_review_why')),
        'Sauce drowns the pasta.',
      );
      await tester.pump();
      await tester.tap(
        find.byKey(const ValueKey('meal_planning.detail_review_send')),
      );
      await tester.pump();
      await tester.pump();

      expect(controller.reviews, [(false, 'Sauce drowns the pasta.')]);
      expect(
        find.text(content['meal_planning.detail_review_sent']!),
        findsOneWidget,
      );
      // The box clears for the next comment.
      expect(find.text('Sauce drowns the pasta.'), findsNothing);
    });
  });

  testWidgets('none of the removed clutter renders', (tester) async {
    await pumpScreen(tester);

    // Keyword tags, why prose, quote card, fits row, old labels.
    expect(find.text('Fish'), findsNothing);
    expect(find.text('Batch 2'), findsNothing);
    expect(find.text('Everyday'), findsNothing);
    expect(
      find.text('Dinner: salmon, tofu or steak with some quinoa.'),
      findsNothing,
    );
    expect(find.text('Jennifer Sygo'), findsNothing);
    expect(find.text('Jennifer Sygo, runningmagazine.ca'), findsNothing);
    expect(
      find.text('Fits: mediterranean, omnivore, pescatarian'),
      findsNothing,
    );
    // Old labels — literals here because their content keys were removed.
    expect(find.text('I like this'), findsNothing);
    expect(find.text('Not for me'), findsNothing);
    expect(find.text('Save to mine'), findsNothing);
    expect(find.text('One serving'), findsNothing);
    expect(find.text('HOW TO COOK'), findsNothing);
    expect(find.text('Show carbs / protein'), findsNothing);
  });

  /// The recipe screen shows one Dish photo or nothing, and one credit line
  /// only when the photo carries one (ADR 0003). Details are the producer's
  /// `get_meal` payload (`_shared/vana/meals.ts`) with the photo fields a real
  /// row sends.
  group('the photo and its credit', () {
    MealDetail fromProducer(Map<String, dynamic> photo) {
      final json =
          jsonDecode(
                File(
                  'test/features/meal_planning/fixtures/meal_detail.json',
                ).readAsStringSync(),
              )['meal']
              as Map<String, dynamic>;
      return MealDetail.fromJson({...json, ...photo});
    }

    Future<void> pumpDetail(WidgetTester tester, MealDetail d) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            contentServiceProvider.overrideWith(testContentService),
            mealDetailControllerProvider(
              d.meal.id,
            ).overrideWith(() => _FixedDetailController(d)),
          ],
          child: MaterialApp(home: MealDetailScreen(id: d.meal.id)),
        ),
      );
      await tester.pump();
    }

    const creditLine = 'Photo by Alisha Mishra on Pexels';
    final credited = {
      'photo': {
        'url': 'https://images.pexels.com/1346342.jpeg',
        'credit': creditLine,
        'creditUrl': 'https://www.pexels.com/photo/vegetable-shake-1346342/',
      },
    };

    testWidgets('a Dish photo shows, with its one credit line under it', (
      tester,
    ) async {
      await pumpDetail(tester, fromProducer(credited));

      expect(find.byType(MealPhotoHero), findsOneWidget);
      expect(find.text(creditLine), findsOneWidget);
      // One line, not one per photograph as the Mosaic used to need.
      expect(find.textContaining('Photo by'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('meal_planning.detail_photo_credit')),
        findsOneWidget,
      );
    });

    testWidgets('a photo of ours shows clean: no credit line', (tester) async {
      await pumpDetail(
        tester,
        fromProducer({
          'photo': {
            'url': 'https://vlmtsdzpnjnavdgytcmi.supabase.co/storage/v1/'
                'object/public/meal-images/photos/D-048.jpg',
            'credit': null,
            'creditUrl': null,
          },
        }),
      );

      expect(find.byType(MealPhotoHero), findsOneWidget);
      expect(find.textContaining('Photo'), findsNothing);
      expect(
        find.byKey(const ValueKey('meal_planning.detail_photo_credit')),
        findsNothing,
      );
    });

    testWidgets('a credit with no link is plain text, not a tap target', (
      tester,
    ) async {
      await pumpDetail(
        tester,
        fromProducer({
          'photo': {
            'url': 'https://images.pexels.com/1346342.jpeg',
            'credit': creditLine,
            'creditUrl': null,
          },
        }),
      );

      expect(find.text(creditLine), findsOneWidget);
      expect(
        find.byKey(const ValueKey('meal_planning.detail_photo_credit')),
        findsNothing,
      );
    });

    testWidgets('no photo: the screen opens at the meal name', (tester) async {
      await pumpDetail(tester, fromProducer({}));

      expect(find.byType(MealPhotoHero), findsNothing);
      expect(find.textContaining('Photo by'), findsNothing);
      // Nothing is drawn above the title but the header row.
      final title = tester.getTopLeft(
        find.text('Marathon Bolognese over pasta'),
      );
      final backButton = tester.getBottomLeft(
        find.byKey(const ValueKey('meal_planning.detail_save_to_mine')),
      );
      expect(title.dy, lessThan(backButton.dy + 40));
    });

    testWidgets('a photo that fails to load leaves no trace', (tester) async {
      await pumpDetail(tester, fromProducer(credited));
      // flutter_test answers every image request with HTTP 400.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
      await tester.pump();

      expect(find.byType(Image), findsNothing);
      expect(
        find.descendant(
          of: find.byType(MealPhotoHero),
          matching: find.byType(Icon),
        ),
        findsNothing,
      );
    });
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
                builder: (_, __) =>
                    MealDetailScreen(id: 'D-100', pickConversationId: pick),
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

  // ── Directions origin (mp-146 / ticket 32) ─────────────────────────────
  group('directions say where the steps came from', () {
    Future<void> pumpWith(WidgetTester tester, MealDirections d) async {
      controller = _FixedDetailController(detail.copyWith(directions: d));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            contentServiceProvider.overrideWith(testContentService),
            isAdminProvider.overrideWith((ref) async => false),
            mealDetailControllerProvider(
              'D-100',
            ).overrideWith(() => controller),
          ],
          child: const MaterialApp(home: MealDetailScreen(id: 'D-100')),
        ),
      );
      await tester.pump();
    }

    testWidgets('verbatim steps read "as published by X" with the link', (
      tester,
    ) async {
      await pumpWith(
        tester,
        const MealDirections(
          origin: DirectionsOrigin.source,
          sourceName: 'Jennifer Sygo',
          sourceUrl: 'https://runningmagazine.ca/recipes/salmon-quinoa',
          verbatim: true,
        ),
      );
      expect(
        find.text(
          ContentKeys.format(content['meal_planning.origin_verbatim']!, {
            'name': 'Jennifer Sygo',
          }),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('meal_planning.detail_origin_link')),
        findsOneWidget,
      );
    });

    testWidgets('AI-written steps keep the sparkle badge and tooltip', (
      tester,
    ) async {
      await pumpWith(
        tester,
        const MealDirections(origin: DirectionsOrigin.aiGenerated),
      );
      expect(
        find.text(content['meal_planning.badge_ai_generated']!),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is Tooltip &&
              w.message == content['meal_planning.cook_ai_disclaimer'],
        ),
        findsOneWidget,
      );
    });

    testWidgets('a simple assembly says so', (tester) async {
      await pumpWith(
        tester,
        const MealDirections(origin: DirectionsOrigin.assemblySimple),
      );
      expect(
        find.text(content['meal_planning.origin_assembly']!),
        findsOneWidget,
      );
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

  /// Reviews the screen asked for, as (isGood, why).
  final List<(bool, String)> reviews = [];

  @override
  Future<void> review({required bool isGood, required String why}) async {
    reviews.add((isGood, why));
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
