/// A resumed meal-plan conversation reads right (testing-wave ticket 48):
///
/// - 15-003: the meal cards tick the meals that are in THIS conversation's
///   plan (the draft `get_plan` answers on open, the one the plan bar
///   shows), not only the ones picked since the screen opened.
/// - 16-005, and ticket 97 (16-006, 18-007): a resumed conversation is
///   headed by its plan's week and state ("Aug 30 week · Draft"), the same
///   title as its row in the list, never "New meal plan"; a new one keeps
///   "New meal plan".
/// - 15-002: a trailing question in Vana's bubble that equals the choice
///   prompt under it shows once (the prompt keeps it; Vana's words are
///   otherwise untouched, mp-007/008).
///
/// Driven through the REAL VanaChatController and conversations controller
/// from the chat screen, with producer-shaped history and plan.
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
import 'package:mealvana_endurance/features/meal_planning/domain/meal_plan_status.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_ref.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_source.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_type.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/plan_meal.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/ui_action.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/user_memory.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_conversation.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_conversation_kind.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_input_mode.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_message.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_moment.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_part.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_situation.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_stream_event.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/screens/vana_chat_screen.dart';

import '../../../ai_credits/helpers/counting_credits_repository.dart';
import '../../domain/fixture_helpers.dart';
import '../../helpers/container.dart';
import '../helpers/test_content.dart';

/// The chat transport: stored history.
class _ChatRepo extends Fake implements VanaChatRepository {
  _ChatRepo({required this.history});

  final List<VanaMessage> history;

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
      conversationId: 'conv-new',
      kind: kind,
      events: events(),
    );
  }

  @override
  Future<List<VanaMessage>> fetchMessages(String conversationId) async =>
      history;
}

/// `vana-action`: `get_plan` answers the conversation's plan and
/// `list_conversations` the conversations list (ticket 126).
class _PlanActions extends Fake implements VanaActionClient {
  _PlanActions(this.plan, {required this.conversations});

  final MealPlan? plan;
  final List<VanaConversationSummary> conversations;

  @override
  Future<VanaActionResult> run(UiAction action) async {
    final p = plan;
    if (action is GetPlanAction && p != null) {
      return VanaActionResult(
        parts: [VanaBatchPart(plan: p)],
        extras: const {},
      );
    }
    if (action is ListConversationsAction) {
      return VanaActionResult(
        parts: const [],
        extras: {
          'conversations': [for (final c in conversations) c.toJson()],
        },
      );
    }
    return const VanaActionResult(parts: [], extras: {});
  }
}

class _NoActivePlan extends MealPlanController {
  @override
  Future<MealPlan?> build() async => null;

  @override
  Future<void> applyServerPlan(MealPlan plan) async {}
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
  const question =
      'How much cooking do you want to do this week: batch one or two meals '
      'at a time and eat them across the days, or make most nights fresh?';

  MealRef card(String id, String name) => MealRef(
    source: MealSource.library,
    id: id,
    name: name,
    mealType: MealType.dinner,
  );

  /// The conversation's plan as `get_plan` answers it (producer-shaped
  /// `batch` fixture) holding the library meals [ids].
  MealPlan planHolding(List<String> ids) {
    final fixture = VanaActionResult.fromJson(loadFixture('batch')).plan!;
    return fixture.copyWith(
      conversationId: 'conv-1',
      meals: [
        for (final id in ids)
          PlanMeal(
            id: 'pm-$id',
            planId: fixture.id,
            source: MealSource.library,
            libraryMealId: id,
            name: id,
            mealType: MealType.dinner,
            servings: 3,
            servingsLeft: 3,
          ),
      ],
    );
  }

  List<VanaMessage> history({String opener = 'Here is your week. $question'}) =>
      [
        VanaMessage(
          id: 'a-1',
          conversationId: 'conv-1',
          role: VanaMessageRole.assistant,
          content: opener,
          parts: const [
            VanaChoicesPart(
              question: question,
              options: ['Batch cook', 'Mostly fresh'],
            ),
          ],
          createdAt: DateTime(2026, 9, 22, 7, 8),
        ),
        VanaMessage(
          id: 'a-2',
          conversationId: 'conv-1',
          role: VanaMessageRole.assistant,
          content: 'Three dinners to start.',
          parts: [
            VanaMealPickerPart(
              title: 'Dinners',
              mealType: MealType.dinner,
              meals: [
                card('D-024', 'Injera with shiro wot'),
                card('D-099', 'Salmon quinoa bowl'),
              ],
            ),
          ],
          createdAt: DateTime(2026, 9, 22, 7, 9),
        ),
      ];

  Future<void> pumpScreen(
    WidgetTester tester, {
    String? conversationId = 'conv-1',
    bool startOpener = false,
    MealPlan? plan,
    List<VanaMessage>? messages,
    String? title,
    VanaConversationPlan? rowPlan,
  }) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/vana',
      routes: [
        GoRoute(
          path: '/vana',
          builder: (_, __) => VanaChatScreen(
            kind: VanaConversationKind.mealPlanning,
            conversationId: conversationId,
            startOpener: startOpener,
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...baseOverrides(),
          contentServiceProvider.overrideWith(testContentService),
          vanaChatRepositoryProvider.overrideWithValue(
            _ChatRepo(history: messages ?? history()),
          ),
          mealPlanControllerProvider.overrideWith(_NoActivePlan.new),
          userMemoryRepositoryProvider.overrideWithValue(_FakeMemoryRepo()),
          vanaActionClientProvider.overrideWithValue(
            _PlanActions(
              plan,
              conversations: [
                VanaConversationSummary(
                  id: 'conv-1',
                  kind: VanaConversationKind.mealPlanning,
                  title: title,
                  createdAt: '2026-09-22T07:08:00Z',
                  plan: rowPlan,
                ),
              ],
            ),
          ),
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

  Finder ticked(String id) => find.descendant(
    of: find.byKey(ValueKey('meal_planning.picker_tick_$id')),
    matching: find.byIcon(Icons.check),
  );

  group('meal cards (15-003)', () {
    testWidgets('a card for a meal in the conversation plan shows ticked', (
      tester,
    ) async {
      await pumpScreen(tester, plan: planHolding(['D-024']));

      expect(
        find.byKey(const ValueKey('meal_planning.picker_tick_D-024')),
        findsOneWidget,
      );
      expect(ticked('D-024'), findsOneWidget);
      expect(ticked('D-099'), findsNothing);
    });

    testWidgets('with no plan, no card is ticked', (tester) async {
      await pumpScreen(tester);

      expect(ticked('D-024'), findsNothing);
      expect(ticked('D-099'), findsNothing);
    });
  });

  group('header (16-005, ticket 97)', () {
    final newPlan = content['meal_planning.chat_title_planning']!;

    testWidgets(
      'a resumed conversation is headed by its plan\'s week and state, '
      'not the row\'s stored title',
      (tester) async {
        // The `batch` fixture's plan: the week of Aug 30, a draft.
        await pumpScreen(
          tester,
          plan: planHolding(['D-024']),
          title: "This week's plan",
        );

        expect(find.text('Aug 30 week · Draft'), findsOneWidget);
        expect(find.text("This week's plan"), findsNothing);
        expect(find.text(newPlan), findsNothing);
      },
    );

    testWidgets(
      'with no draft in the chat, the header is the row\'s title from the '
      'list',
      (tester) async {
        await pumpScreen(
          tester,
          rowPlan: const VanaConversationPlan(
            weekStart: '2026-09-13',
            status: MealPlanStatus.confirmed,
            mealCount: 4,
          ),
        );

        expect(find.text('Sep 13 week · Confirmed'), findsOneWidget);
        expect(find.text(newPlan), findsNothing);
      },
    );

    testWidgets('a resumed conversation with history and no plan reads '
        '"No plan yet"', (tester) async {
      await pumpScreen(tester, title: "This week's plan");

      expect(
        find.text(content['meal_planning.conv_plan_none']!),
        findsOneWidget,
      );
      expect(find.text(newPlan), findsNothing);
    });

    testWidgets(
      'a conversation just made from the list (no title, no meals) keeps '
      '"New meal plan"',
      (tester) async {
        await pumpScreen(tester, messages: const []);

        expect(find.text(newPlan), findsOneWidget);
      },
    );
  });

  group('repeated question (15-002)', () {
    int occurrences(WidgetTester tester, String text) {
      var n = 0;
      for (final w in tester.widgetList<Widget>(
        find.byWidgetPredicate(
          (w) => w is Text || w is SelectableText || w is RichText,
        ),
      )) {
        final s = switch (w) {
          Text(:final data, :final textSpan) =>
            data ?? textSpan?.toPlainText() ?? '',
          SelectableText(:final data, :final textSpan) =>
            data ?? textSpan?.toPlainText() ?? '',
          _ => '',
        };
        n += text.allMatches(s).length;
      }
      return n;
    }

    testWidgets('a trailing question equal to the choice prompt shows once', (
      tester,
    ) async {
      await pumpScreen(tester);

      expect(occurrences(tester, question), 1);
      // The rest of Vana's bubble is untouched.
      expect(occurrences(tester, 'Here is your week.'), 1);
    });

    testWidgets('a bubble whose last line differs from the prompt keeps it', (
      tester,
    ) async {
      await pumpScreen(
        tester,
        messages: history(opener: 'Here is your week. What matters most?'),
      );

      expect(occurrences(tester, 'What matters most?'), 1);
      expect(occurrences(tester, question), 1);
    });
  });
}
