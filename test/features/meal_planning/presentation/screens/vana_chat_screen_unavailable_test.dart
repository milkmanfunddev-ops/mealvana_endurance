/// The AI Gateway refusing OUR key (mp-437, ticket ai-cost 02): the athlete
/// sees "Vana is unavailable right now" from the content system, never the
/// top-up sheet and never a crash.
///
/// Driven through the REAL VanaChatController and the REAL VanaChatRepository
/// streaming path over VanaTransport; only the HTTP client is faked, and it
/// answers with the exact bodies `supabase/functions/_shared/ai/gateway_error.ts`
/// produces (`aiUnavailableBody()` with 503 before the stream, `errorLine()`
/// once it has started).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/ai_credits/application/credits_controller.dart';
import 'package:mealvana_endurance/features/ai_credits/application/purchase_controller.dart';
import 'package:mealvana_endurance/features/ai_credits/domain/credit_wallet.dart';
import 'package:mealvana_endurance/features/ai_credits/presentation/insufficient_credits_handler.dart';
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
import 'package:mealvana_endurance/features/meal_planning/domain/vana_message.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/screens/vana_chat_screen.dart';

import '../../helpers/container.dart';
import '../../helpers/fakes.dart';
import '../helpers/test_content.dart';

/// The real repository; only the two Supabase table reads are stubbed, so the
/// turn itself goes through `streamChat` → VanaTransport → the fake client.
class _RealStreamRepo extends VanaChatRepository {
  _RealStreamRepo(TransportHarness h)
    : super(
        transport: h.transport,
        supabase: h.supabase,
        logger: h.logger,
        functionName: 'vana-chat',
      );

  @override
  Future<List<VanaMessage>> fetchMessages(String conversationId) async =>
      const [];

  @override
  Future<String> createConversation(VanaConversationKind kind) async =>
      'conv-created';
}

class _NoPlan extends MealPlanController {
  @override
  Future<MealPlan?> build() async => null;
}

class _FakeActions extends Fake implements VanaActionClient {
  @override
  Future<VanaActionResult> run(UiAction action) async =>
      const VanaActionResult(parts: [], extras: {});
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

/// A wallet with plenty left: the refusal is ours, not the athlete's.
class _FullCredits extends CreditsController {
  @override
  Future<CreditWallet> build() async => CreditWallet.fromMap(const {
    'balance': 250,
    'allowance': 250,
    'allowance_monthly': 300,
    'allowance_expires_at': '2026-10-15T12:00:00+00:00',
  });
}

void main() {
  final content = loadDefaultContent();

  setUp(debugResetInsufficientCreditsSheet);

  Future<TransportHarness> pumpAndSend(
    WidgetTester tester, {
    required int status,
    required String body,
  }) async {
    final h = TransportHarness(status: status, body: body);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...baseOverrides(),
          contentServiceProvider.overrideWith(testContentService),
          vanaChatRepositoryProvider.overrideWithValue(_RealStreamRepo(h)),
          mealPlanControllerProvider.overrideWith(() => _NoPlan()),
          userMemoryRepositoryProvider.overrideWithValue(_FakeMemoryRepo()),
          vanaActionClientProvider.overrideWithValue(_FakeActions()),
          mealAiServiceProvider.overrideWithValue(_FakeMealAi()),
          wiredashFeedbackFilerProvider.overrideWithValue(_FakeFiler()),
          creditsControllerProvider.overrideWith(() => _FullCredits()),
          visibleCreditPackagesProvider.overrideWith((ref) async => const []),
        ],
        child: const MaterialApp(
          home: VanaChatScreen(
            kind: VanaConversationKind.general,
            conversationId: 'conv-1',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    await tester.enterText(
      find.byKey(const ValueKey('meal_planning.chat_input')),
      'what should I eat before my long run',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('meal_planning.chat_send')));
    // The fake HTTP body's cancel (the controller breaks out of the stream on
    // `done`) only completes on real async, not the widget tester's fake clock.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    return h;
  }

  void expectUnavailableNotTopUp(WidgetTester tester) {
    expect(tester.takeException(), isNull);
    expect(content['meal_planning.ai_unavailable'], isNotNull);
    expect(find.text(content['meal_planning.ai_unavailable']!), findsOneWidget);
    // Never the top-up sheet, never the out-of-credits strip.
    expect(find.byKey(const ValueKey('tokens.allowance')), findsNothing);
    expect(
      find.byKey(const ValueKey('meal_planning.out_of_credits_strip')),
      findsNothing,
    );
    // And not the generic server error either.
    expect(find.text(content['meal_planning.server_error']!), findsNothing);
  }

  testWidgets(
    'a refusal before the stream (503 ai_unavailable): unavailable, not the top-up sheet',
    (tester) async {
      final h = await pumpAndSend(
        tester,
        status: 503,
        body: '{"success":false,"error":"ai_unavailable"}',
      );
      expect(h.requests, hasLength(1));
      expect(
        h.requests.single.body['message'],
        'what should I eat before my long run',
      );
      expectUnavailableNotTopUp(tester);
    },
  );

  testWidgets(
    'a refusal mid-stream (error line, code ai_unavailable): unavailable, not the top-up sheet',
    (tester) async {
      await pumpAndSend(
        tester,
        status: 200,
        body:
            '{"type":"error","message":"Budget exceeded for this API key","code":"ai_unavailable"}\n'
            '{"type":"done"}\n',
      );
      expectUnavailableNotTopUp(tester);
      // The reply never started, so no empty Vana bubble is left behind.
      expect(
        find.byKey(const ValueKey('meal_planning.chat_message_1')),
        findsNothing,
      );
    },
  );
}
