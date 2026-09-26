/// A read that fails in the planning chat says so with a Retry
/// (testing-wave 129):
///
/// - 88-011: "New meal plan" offline showed an empty chat and no message;
///   the opener's failure now stays on screen with a Retry that asks for the
///   same opener, and Browse from the plus menu says why it cannot open.
/// - 88-012: an opened conversation whose history failed looked like a brand
///   new plan ("New meal plan", "Your plan · 0 meals"); it now says it could
///   not load, keeps the composer shut, and loads on Retry.
///
/// Driven through the REAL VanaChatController from the chat screen; the
/// chat transport is a fake that fails until told otherwise.
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
import 'package:mealvana_endurance/features/meal_planning/data/vana_exceptions.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_plan.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/ui_action.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/user_memory.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_conversation_kind.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_input_mode.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_message.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_moment.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_situation.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_stream_event.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/screens/vana_chat_screen.dart';

import '../../../ai_credits/helpers/counting_credits_repository.dart';
import '../../helpers/container.dart';
import '../helpers/test_content.dart';

/// Fails the history read and every turn while [offline]; online, the
/// history is one athlete turn and a turn is one line of Vana's.
class _FlakyRepo extends Fake implements VanaChatRepository {
  bool offline = true;

  /// What a failed read throws while [offline]; the socket by default.
  VanaException failure = const VanaOfflineException('socket');
  int historyReads = 0;
  final List<Map<String, Object?>> turns = [];

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
    turns.add({'opener': opener, 'newPlan': newPlan});
    if (offline) throw failure;
    Stream<VanaStreamEvent> events() async* {
      yield const VanaTextEvent('Three dinners to start.');
      yield const VanaDoneEvent();
    }

    return VanaChatResponse(
      conversationId: 'conv-new',
      kind: kind,
      events: events(),
    );
  }

  @override
  Future<List<VanaMessage>> fetchMessages(String conversationId) async {
    historyReads++;
    if (offline) throw failure;
    return [
      VanaMessage(
        id: 'u-1',
        conversationId: conversationId,
        role: VanaMessageRole.user,
        content: 'Plan my race week',
        createdAt: DateTime(2026, 9, 22, 6, 59),
      ),
    ];
  }

  @override
  Future<String> createConversation(VanaConversationKind kind) async =>
      'conv-created';
}

/// `vana-action`: no draft, and no conversations list (offline too).
class _Actions extends Fake implements VanaActionClient {
  @override
  Future<VanaActionResult> run(UiAction action) async =>
      throw const VanaOfflineException('socket');
}

class _NoPlan extends MealPlanController {
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
  late _FlakyRepo repo;

  Future<void> pumpScreen(WidgetTester tester, VanaChatScreen screen) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    repo = _FlakyRepo();
    final router = GoRouter(
      initialLocation: '/vana',
      routes: [GoRoute(path: '/vana', builder: (_, __) => screen)],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...baseOverrides(),
          contentServiceProvider.overrideWith(testContentService),
          vanaChatRepositoryProvider.overrideWithValue(repo),
          mealPlanControllerProvider.overrideWith(_NoPlan.new),
          userMemoryRepositoryProvider.overrideWithValue(_FakeMemoryRepo()),
          vanaActionClientProvider.overrideWithValue(_Actions()),
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
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  final failed = find.byKey(const ValueKey('meal_planning.chat_failed_read'));
  final retry = find.byKey(const ValueKey('meal_planning.chat_retry'));
  String title(WidgetTester tester) => tester
      .widget<Text>(find.byKey(const ValueKey('meal_planning.chat_title')))
      .data!;

  testWidgets('an opened conversation whose history failed says so, never '
      'the empty new plan, and loads on Retry', (tester) async {
    await pumpScreen(
      tester,
      const VanaChatScreen(
        kind: VanaConversationKind.mealPlanning,
        conversationId: 'conv-old',
      ),
    );

    expect(failed, findsOneWidget);
    expect(
      tester.widget<Text>(failed).data,
      content['meal_planning.chat_history_failed'],
    );
    expect(title(tester), isNot(content['meal_planning.chat_title_planning']));
    expect(
      find.byKey(const ValueKey('meal_planning.plan_bar.hidden')),
      findsOneWidget,
      reason: 'no "Your plan · 0 meals" over an old conversation',
    );
    expect(
      tester
          .widget<TextField>(
            find.byKey(const ValueKey('meal_planning.chat_input')),
          )
          .enabled,
      isFalse,
    );
    expect(find.byType(SnackBar), findsNothing);

    repo.offline = false;
    await tester.tap(retry);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(repo.historyReads, 2);
    expect(failed, findsNothing);
    expect(find.text('Plan my race week'), findsOneWidget);
  });

  testWidgets('New meal plan offline says so; Browse says why it cannot '
      'open; Retry asks for the same opener', (tester) async {
    await pumpScreen(
      tester,
      const VanaChatScreen(
        kind: VanaConversationKind.mealPlanning,
        startOpener: true,
        newPlan: true,
      ),
    );

    expect(failed, findsOneWidget);
    expect(
      tester.widget<Text>(failed).data,
      content['meal_planning.vana_offline'],
    );

    // The plus menu's Browse, with no conversation to browse into yet.
    await tester.tap(find.byKey(const ValueKey('meal_planning.chat_attach')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(content['meal_planning.attach_browse_meals']!));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text(content['meal_planning.needs_connection']!),
      findsOneWidget,
    );

    repo.offline = false;
    await tester.tap(retry);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(failed, findsNothing);
    expect(find.text('Three dinners to start.'), findsOneWidget);
    expect(repo.turns, hasLength(2));
    expect(repo.turns.last, {'opener': true, 'newPlan': true});
  });

  // Testing-wave 122-004: a 403 pro_required on the history read says so
  // and offers no Retry; the same read can never pass until the subscription
  // says otherwise, and the router owns the paywall.
  testWidgets('a history read refused as pro_required has no Retry', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      const VanaChatScreen(
        kind: VanaConversationKind.mealPlanning,
        conversationId: 'conv-old',
      ),
    );
    // pumpScreen makes the repo; fail the next read as the server's 403 does.
    repo.failure = const ProRequiredException();
    await tester.tap(retry);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(failed, findsOneWidget);
    // A history read keeps its one line whatever refused it.
    expect(
      tester.widget<Text>(failed).data,
      content['meal_planning.chat_history_failed'],
    );
    expect(retry, findsNothing);
  });
}
