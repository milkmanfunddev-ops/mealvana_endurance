/// A conversation whose Draft another confirm archived (testing-wave 15-001,
/// ticket 71; mp-241, mp-676) says the athlete confirmed a different plan for
/// this week and this one is kept in their plans. The plan shows read-only:
/// no servings steppers, no remove, no Review/Confirm. "Use this plan
/// instead" copies it into this week as a new draft (mp-675) and opens it.
///
/// Driven through the REAL VanaChatController from the chat screen; the
/// draft is the producer's shape (`get_plan` answering the batch fixture
/// with `status: archived`, as `plan.ts hydrate` writes it). The plan
/// controller records what "Use this plan instead" asked for.
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
import 'package:mealvana_endurance/features/meal_planning/domain/ui_action.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/user_memory.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_conversation_kind.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_input_mode.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_message.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_moment.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_part.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_situation.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_stream_event.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/screens/vana_chat_screen.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/stepper.dart';

import '../../../ai_credits/helpers/counting_credits_repository.dart';
import '../../domain/fixture_helpers.dart';
import '../../helpers/container.dart';
import '../helpers/test_content.dart';

/// The chat transport: history only, no turns are sent in these tests.
class _ChatRepo extends Fake implements VanaChatRepository {
  _ChatRepo(this.history);

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
      conversationId: 'conv-1',
      kind: kind,
      events: events(),
    );
  }

  @override
  Future<List<VanaMessage>> fetchMessages(String conversationId) async =>
      history;

  @override
  Future<String> createConversation(VanaConversationKind kind) async =>
      'conv-created';
}

/// `vana-action`: `get_plan` answers the conversation's draft (the plan bar
/// reads it); nothing else is expected here.
class _DraftActions extends Fake implements VanaActionClient {
  _DraftActions(this.draft);

  final VanaPart draft;

  @override
  Future<VanaActionResult> run(UiAction action) async {
    if (action is GetPlanAction) {
      return VanaActionResult(parts: [draft], extras: const {});
    }
    return const VanaActionResult(parts: [], extras: {});
  }
}

/// Records what "Use this plan instead" asked to copy, answering the copy.
class _RecordingPlan extends MealPlanController {
  _RecordingPlan(this.copy);

  final MealPlan copy;
  final List<String> usedAgain = [];
  int confirms = 0;

  @override
  Future<MealPlan?> build() async => null;

  @override
  Future<void> applyServerPlan(MealPlan plan) async {}

  @override
  Future<MealPlan?> usePlanAgain(String id) async {
    usedAgain.add(id);
    return copy;
  }

  @override
  Future<MealPlan?> confirmPlan({
    String? date,
    String? conversationId,
    String? planId,
  }) async {
    confirms++;
    return null;
  }
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
  // The producer's answer for this conversation's plan: the batch fixture as
  // `get_plan` returns it once a later confirm archived the draft.
  final raw = loadFixture('batch');
  final part = Map<String, dynamic>.of(
    (raw['parts'] as List).first as Map<String, dynamic>,
  );
  part['plan'] = {
    ...(part['plan'] as Map<String, dynamic>),
    'status': 'archived',
  };
  final archivedPart = VanaPart.fromJson(part)!;
  final archived = (archivedPart as VanaBatchPart).plan;
  final copy = archived.copyWith(id: 'plan-copy', status: MealPlanStatus.draft);

  final history = [
    VanaMessage(
      id: 'a-1',
      conversationId: 'conv-1',
      role: VanaMessageRole.assistant,
      content: 'Two dinners are in.',
      parts: const [],
      createdAt: DateTime(2026, 9, 22, 7, 8),
    ),
  ];

  late _RecordingPlan plan;

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    plan = _RecordingPlan(copy);
    final router = GoRouter(
      initialLocation: '/vana',
      routes: [
        GoRoute(
          path: '/vana',
          builder: (_, __) => const VanaChatScreen(
            kind: VanaConversationKind.mealPlanning,
            conversationId: 'conv-1',
          ),
        ),
        // Where the copy opens: the plan view, whose Confirm makes it
        // this week's plan (ticket 73).
        GoRoute(
          path: '/food/plans/:id',
          builder: (_, state) =>
              Scaffold(body: Text('plan ${state.pathParameters['id']}')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...baseOverrides(),
          contentServiceProvider.overrideWith(testContentService),
          vanaChatRepositoryProvider.overrideWithValue(_ChatRepo(history)),
          mealPlanControllerProvider.overrideWith(() => plan),
          userMemoryRepositoryProvider.overrideWithValue(_FakeMemoryRepo()),
          vanaActionClientProvider.overrideWithValue(
            _DraftActions(archivedPart),
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
  }

  final content = loadDefaultContent();

  testWidgets(
    'an archived draft says it was replaced, with no Confirm and no servings '
    'controls',
    (tester) async {
      await pumpScreen(tester);

      expect(
        find.text(content['meal_planning.plan_bar_replaced']!),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('meal_planning.plan_bar.review')),
        findsNothing,
        reason: 'no Review, so no way to the Confirm',
      );
      expect(
        find.byKey(const ValueKey('meal_planning.plan_bar.use_instead')),
        findsOneWidget,
      );

      // Expanded, the meals are there, read-only.
      await tester.tap(
        find.byKey(const ValueKey('meal_planning.plan_bar.minimized')),
      );
      await tester.pumpAndSettle();
      for (final m in archived.meals) {
        expect(find.text(m.name), findsWidgets);
        expect(
          find.byKey(ValueKey('meal_planning.plan_bar.tile_${m.id}')),
          findsOneWidget,
        );
      }
      expect(find.byType(ServingsStepper), findsNothing);
      expect(find.byIcon(Icons.close), findsNothing, reason: 'no remove');
      expect(
        find.byKey(const ValueKey('meal_planning.review_sheet.confirm')),
        findsNothing,
      );
      expect(plan.confirms, 0);
    },
  );

  testWidgets(
    'Use this plan instead copies the plan as this week\'s new draft and '
    'opens it',
    (tester) async {
      await pumpScreen(tester);

      await tester.tap(
        find.byKey(const ValueKey('meal_planning.plan_bar.use_instead')),
      );
      await tester.pumpAndSettle();

      expect(plan.usedAgain, [archived.id]);
      expect(find.text('plan plan-copy'), findsOneWidget);
    },
  );
}
