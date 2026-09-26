/// Testing-wave 134 (Findings 118-004, 110-009): a general (not
/// meal-planning) conversation has no draft of its own, so a Browse pick from
/// it goes into the plan the Plan tab shows, and after Done the chat's plan
/// bar shows that plan with Remove. A `/vana?c=<id>` link with no `mode`
/// opens the conversation as its own kind, so a general conversation no
/// longer reads "New meal plan".
///
/// Driven through the REAL VanaChatController from the chat screen; the
/// Plan tab's plan is the producer's shape (the `batch` fixture) served by a
/// recording plan controller.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/features/ai_credits/application/credits_controller.dart';
import 'package:mealvana_endurance/features/ai_credits/application/purchase_controller.dart';
import 'package:mealvana_endurance/features/ai_credits/data/credits_repository.dart';
import 'package:mealvana_endurance/features/ai_credits/domain/credit_wallet.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/feedback/data/wiredash_feedback_filer.dart';
import 'package:mealvana_endurance/features/feedback/domain/typed_feedback.dart';
import 'package:mealvana_endurance/features/meal_logging/application/meal_ai_service.dart';
import 'package:mealvana_endurance/features/meal_planning/application/meal_plan_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/data/user_memory_repository.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_action_client.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_chat_repository.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_plan.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/ui_action.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/user_memory.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_conversation_kind.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_input_mode.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_message.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_moment.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_situation.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_stream_event.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/screens/vana_chat_route.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/screens/vana_chat_screen.dart';

import '../../../ai_credits/helpers/counting_credits_repository.dart';
import '../../domain/fixture_helpers.dart';
import '../../helpers/container.dart';
import '../helpers/test_content.dart';

/// The chat transport: history only, no turns are sent in these tests. The
/// conversation's kind is what the `vana_conversations` row says.
class _ChatRepo extends Fake implements VanaChatRepository {
  _ChatRepo(this.history, {this.kinds = const {}});

  final List<VanaMessage> history;
  final Map<String, VanaConversationKind> kinds;
  final List<String> kindLookups = [];

  @override
  Future<VanaChatResponse> streamChat({
    String? message,
    String? conversationId,
    required VanaConversationKind kind,
    bool opener = false,
    String? anchorDate,
    String? timezone,
    VanaSituation? situation,
    VanaMoment? moment,
    bool newPlan = false,
    VanaInputMode? inputMode,
  }) async {
    Stream<VanaStreamEvent> events() async* {
      yield const VanaDoneEvent();
    }

    return VanaChatResponse(
      conversationId: 'conv-1',
      kind: kind,
      events: events(),
    );
  }

  @override
  Future<List<VanaMessage>> fetchMessages(String conversationId) async =>
      history;

  @override
  Future<VanaConversationKind?> fetchConversationKind(
    String conversationId,
  ) async {
    kindLookups.add(conversationId);
    return kinds[conversationId];
  }
}

/// `vana-action`: a general conversation has no draft, so `get_plan` scoped
/// to it answers nothing; nothing else is expected here.
class _NoDraftActions extends Fake implements VanaActionClient {
  @override
  Future<VanaActionResult> run(UiAction action) async =>
      const VanaActionResult(parts: [], extras: {});
}

/// The Plan tab's plan, and what the bar's Remove asked for.
class _RecordingPlan extends MealPlanController {
  _RecordingPlan(this.plan);

  final MealPlan? plan;
  final List<String> removed = [];

  @override
  Future<MealPlan?> build() async => plan;

  @override
  Future<void> removeMeal(String planMealId) async => removed.add(planMealId);
}

class _FakeMemoryRepo extends Fake implements UserMemoryRepository {
  @override
  Future<void> applyServerMemory(
    UserMemory memory, {
    required String userId,
  }) async {}
}

class _FakeMealAi extends Fake implements MealAiService {}

class _FakeFiler extends Fake implements WiredashFeedbackFiler {
  @override
  Future<void> file(TypedFeedback feedback) async {}
}

class _OpenWallet extends CreditsController {
  @override
  Future<CreditWallet> build() async => CreditWallet.fromMap(const {
    'balance': 3000000,
    'allowance': 3000000,
    'allowance_monthly': 4000000,
    'allowance_expires_at': '2026-10-15T12:00:00+00:00',
  });
}

void main() {
  final content = loadDefaultContent();

  /// The Plan tab's plan once a Browse pick from the general chat landed:
  /// the producer's `batch` fixture cut to one meal.
  final fixture = VanaActionResult.fromJson(loadFixture('batch')).plan!;
  final onePick = fixture.copyWith(
    conversationId: null,
    meals: fixture.meals.take(1).toList(),
    recomputeCoverage: true,
  );

  final history = [
    VanaMessage(
      id: 'a-1',
      conversationId: 'conv-1',
      role: VanaMessageRole.assistant,
      content: 'Quick question, sure.',
      parts: const [],
      createdAt: DateTime(2026, 9, 26, 7, 8),
    ),
  ];

  late _RecordingPlan plan;
  late _ChatRepo repo;

  Future<void> pumpScreen(
    WidgetTester tester, {
    MealPlan? tabPlan,
    String initialLocation = '/vana',
    Map<String, VanaConversationKind> kinds = const {},
  }) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    plan = _RecordingPlan(tabPlan);
    repo = _ChatRepo(history, kinds: kinds);
    final router = GoRouter(
      initialLocation: initialLocation,
      routes: [
        // The app's `/vana` route, kind from `mode` or the conversation.
        GoRoute(
          path: '/vana',
          builder: (_, state) {
            final c = state.uri.queryParameters['c'];
            final mode = VanaConversationKind.fromWire(
              state.uri.queryParameters['mode'],
            );
            return VanaChatRoute(kind: mode, conversationId: c);
          },
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...baseOverrides(),
          contentServiceProvider.overrideWith(testContentService),
          vanaChatRepositoryProvider.overrideWithValue(repo),
          mealPlanControllerProvider.overrideWith(() => plan),
          userMemoryRepositoryProvider.overrideWithValue(_FakeMemoryRepo()),
          vanaActionClientProvider.overrideWithValue(_NoDraftActions()),
          mealAiServiceProvider.overrideWithValue(_FakeMealAi()),
          wiredashFeedbackFilerProvider.overrideWithValue(_FakeFiler()),
          creditsControllerProvider.overrideWith(() => _OpenWallet()),
          creditsRepositoryProvider.overrideWithValue(
            CountingCreditsRepository(),
          ),
          visibleCreditPackagesProvider.overrideWith((ref) async => const []),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pump(const Duration(milliseconds: 600));
  }

  group('a general chat\'s plan bar (118-004)', () {
    testWidgets(
      'after a Browse pick landed in the Plan tab\'s plan, the bar shows it '
      'and Remove takes it out',
      (tester) async {
        await pumpScreen(
          tester,
          tabPlan: onePick,
          initialLocation: '/vana?c=conv-1&mode=general',
        );

        expect(find.byType(VanaChatScreen), findsOneWidget);
        // The minimized bar: "Your plan · 1 meal", one RichText.
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is RichText &&
                w.text.toPlainText() ==
                    '${content['meal_planning.plan_bar_title']!} · '
                        '${content['meal_planning.plan_bar_count_one']!}',
          ),
          findsOneWidget,
          reason: 'the bar reads the Plan tab\'s plan, "1 meal"',
        );

        await tester.tap(
          find.byKey(const ValueKey('meal_planning.plan_bar.minimized')),
        );
        await tester.pumpAndSettle();
        final meal = onePick.meals.single;
        expect(
          find.byKey(ValueKey('meal_planning.plan_bar.tile_${meal.id}')),
          findsOneWidget,
        );
        await tester.tap(find.byIcon(Icons.close).first);
        await tester.pump();

        expect(plan.removed, [meal.id]);
      },
    );

    testWidgets('with nothing in the Plan tab\'s plan there is no bar', (
      tester,
    ) async {
      await pumpScreen(tester, initialLocation: '/vana?c=conv-1&mode=general');

      expect(
        find.byKey(const ValueKey('meal_planning.plan_bar.hidden')),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is RichText &&
              w.text.toPlainText().startsWith(
                content['meal_planning.plan_bar_title']!,
              ),
        ),
        findsNothing,
        reason: 'a general chat never shows "Your plan · 0 meals"',
      );
    });
  });

  group('/vana?c=<id> with no mode takes the kind from the conversation', () {
    testWidgets('a general conversation opens as general', (tester) async {
      await pumpScreen(
        tester,
        initialLocation: '/vana?c=conv-1',
        kinds: {'conv-1': VanaConversationKind.general},
      );

      expect(repo.kindLookups, ['conv-1']);
      final screen = tester.widget<VanaChatScreen>(find.byType(VanaChatScreen));
      expect(screen.kind, VanaConversationKind.general);
      expect(screen.conversationId, 'conv-1');
      expect(
        find.text(content['meal_planning.chat_sub_general']!),
        findsOneWidget,
      );
      expect(
        find.text(content['meal_planning.chat_title_planning']!),
        findsNothing,
        reason: 'never "New meal plan" over a general conversation',
      );
    });

    testWidgets('a meal-planning conversation opens as meal planning', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        initialLocation: '/vana?c=conv-1',
        kinds: {'conv-1': VanaConversationKind.mealPlanning},
      );

      final screen = tester.widget<VanaChatScreen>(find.byType(VanaChatScreen));
      expect(screen.kind, VanaConversationKind.mealPlanning);
    });

    testWidgets('a conversation the server cannot name falls back to meal '
        'planning, as before', (tester) async {
      await pumpScreen(tester, initialLocation: '/vana?c=conv-1');

      final screen = tester.widget<VanaChatScreen>(find.byType(VanaChatScreen));
      expect(screen.kind, VanaConversationKind.mealPlanning);
    });

    testWidgets('a mode on the link is taken as given, no lookup', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        initialLocation: '/vana?c=conv-1&mode=meal_planning',
        kinds: {'conv-1': VanaConversationKind.general},
      );

      expect(repo.kindLookups, isEmpty);
      final screen = tester.widget<VanaChatScreen>(find.byType(VanaChatScreen));
      expect(screen.kind, VanaConversationKind.mealPlanning);
    });
  });
}
