/// The Review sheet's Confirm sends the conversation's own plan (testing-wave
/// 16-001, ticket 34): the chat's plan bar shows THIS conversation's draft,
/// so Confirm names it (plan id and conversation id) and the server never
/// falls back to "the week's active plan", which put the week's old
/// confirmed plan first and archived the Draft on screen.
///
/// Driven through the REAL VanaChatController from the chat screen; the
/// plan controller records what the sheet asked it to confirm.
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
import 'package:mealvana_endurance/features/meal_planning/domain/vana_part.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_situation.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_stream_event.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/screens/vana_chat_screen.dart';

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

/// Records what the Review sheet asked to confirm.
class _RecordingPlan extends MealPlanController {
  final List<({String? planId, String? conversationId, String? date})>
  confirms = [];

  @override
  Future<MealPlan?> build() async => null;

  @override
  Future<void> applyServerPlan(MealPlan plan) async {}

  @override
  Future<MealPlan?> confirmPlan({
    String? date,
    String? conversationId,
    String? planId,
  }) async {
    confirms.add((planId: planId, conversationId: conversationId, date: date));
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
  final batch = VanaPart.fromJson(
    (loadFixture('batch')['parts'] as List).first as Map<String, dynamic>,
  )!;
  final draft = (batch as VanaBatchPart).plan;

  final history = [
    VanaMessage(
      id: 'a-1',
      conversationId: 'conv-1',
      role: VanaMessageRole.assistant,
      content: 'Three dinners are in.',
      parts: const [],
      createdAt: DateTime(2026, 9, 24, 9, 23),
    ),
  ];

  late _RecordingPlan plan;

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    plan = _RecordingPlan();
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
        // Where a confirmed plan lands the athlete (the shopping list).
        GoRoute(
          path: '/main',
          builder: (_, __) => const Scaffold(body: Text('shopping')),
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
          vanaActionClientProvider.overrideWithValue(_DraftActions(batch)),
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

  testWidgets(
    'Confirm from the Review sheet names the conversation and its plan',
    (tester) async {
      await pumpScreen(tester);

      final review = find.byKey(
        const ValueKey('meal_planning.plan_bar.review'),
      );
      expect(review, findsOneWidget, reason: 'the plan bar shows the draft');
      await tester.tap(review);
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const ValueKey('meal_planning.review_sheet.confirm')),
      );
      await tester.pumpAndSettle();

      final sent = plan.confirms.single;
      expect(sent.conversationId, 'conv-1');
      expect(sent.planId, draft.id);
      expect(find.text('shopping'), findsOneWidget);
    },
  );
}
