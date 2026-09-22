/// The Vana composer on an empty wallet (mp-282 §2, ticket 20): the send
/// raises the top-up sheet through the one 402 handler, one line rides above
/// the composer, the typed text comes back, and no message in the thread
/// says "out of credits". Driven through the REAL VanaChatController with the
/// transport faked to answer a 402 shaped like credits.ts sends it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/ai_credits/application/credits_controller.dart';
import 'package:mealvana_endurance/features/ai_credits/application/purchase_controller.dart';
import 'package:mealvana_endurance/features/ai_credits/data/credits_repository.dart';
import 'package:mealvana_endurance/features/ai_credits/domain/credit_wallet.dart';
import 'package:mealvana_endurance/features/ai_credits/domain/insufficient_credits_exception.dart';
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
import 'package:mealvana_endurance/features/meal_planning/domain/vana_input_mode.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_conversation_kind.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_message.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_moment.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_situation.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/screens/vana_chat_screen.dart';

import '../../helpers/container.dart';
import '../helpers/test_content.dart';
import '../../../ai_credits/helpers/counting_credits_repository.dart';

/// Answers every turn with the 402 credits.ts sends for an empty wallet.
class _EmptyWalletRepo extends Fake implements VanaChatRepository {
  final List<String?> sent = [];

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
    sent.add(message);
    throw InsufficientCreditsException.fromMap({
      'error': 'insufficient_credits',
      'message': 'You are out of AI credits. Purchase more to continue.',
      'balance': 0,
      'cost': 1,
      'allowance_monthly': 300,
      'allowance_expires_at': '2026-10-15T12:00:00+00:00',
    });
  }

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

/// The wallet as the server left it: this month's budget spent, nothing
/// bought. Whole micro-dollars of a $4.00 month (ai-cost ticket 09).
class _EmptyCredits extends CreditsController {
  @override
  Future<CreditWallet> build() async => CreditWallet.fromMap(const {
    'balance': 0,
    'allowance': 0,
    'allowance_monthly': 4000000,
    'allowance_expires_at': '2026-10-15T12:00:00+00:00',
  });
}

void main() {
  final content = loadDefaultContent();

  late _EmptyWalletRepo repo;

  setUp(() {
    repo = _EmptyWalletRepo();
    debugResetInsufficientCreditsSheet();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...baseOverrides(),
          contentServiceProvider.overrideWith(testContentService),
          vanaChatRepositoryProvider.overrideWithValue(repo),
          mealPlanControllerProvider.overrideWith(() => _NoPlan()),
          userMemoryRepositoryProvider.overrideWithValue(_FakeMemoryRepo()),
          vanaActionClientProvider.overrideWithValue(_FakeActions()),
          mealAiServiceProvider.overrideWithValue(_FakeMealAi()),
          wiredashFeedbackFilerProvider.overrideWithValue(_FakeFiler()),
          creditsControllerProvider.overrideWith(() => _EmptyCredits()),
          // The top-up sheet is a budget screen and opens the wallet's live
          // connection; give it a transport with no socket.
          creditsRepositoryProvider.overrideWithValue(
            CountingCreditsRepository(),
          ),
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
  }

  final strip = find.byKey(
    const ValueKey('meal_planning.out_of_credits_strip'),
  );

  testWidgets(
    'send on an empty wallet: the sheet, one line above the composer, the text back, no bubble',
    (tester) async {
      await pumpScreen(tester);
      expect(strip, findsNothing);

      await tester.enterText(
        find.byKey(const ValueKey('meal_planning.chat_input')),
        'what should I eat before my long run',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('meal_planning.chat_send')));
      await tester.pumpAndSettle();

      expect(repo.sent, ['what should I eat before my long run']);

      // The one line above the composer, with the copy from the content file.
      expect(strip, findsOneWidget);
      expect(
        find.text(content['meal_planning.out_of_credits_strip']!),
        findsOneWidget,
      );
      expect(
        find.text(content['meal_planning.out_of_credits_action']!),
        findsOneWidget,
      );

      // The top-up sheet is up, saying the month is used — a share, not a
      // dollar figure and not a credit count (mp-430 clause 8).
      expect(find.byKey(const ValueKey('tokens.allowance')), findsOneWidget);
      expect(
        find.text(
          content['ai_credits.usage_used']!.replaceAll('{percent}', '100'),
        ),
        findsOneWidget,
      );

      // Vana never says it in a message: no bubble at all, the turn rolled back.
      expect(find.textContaining('out of credits'), findsNothing);
      expect(find.textContaining('out of AI credits'), findsNothing);
      // The server-error snackbar the default branch used to show is not there.
      expect(find.text(content['meal_planning.server_error']!), findsNothing);

      // The typed text came back so nothing was lost.
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('meal_planning.chat_input')),
      );
      expect(field.controller!.text, 'what should I eat before my long run');
    },
  );

  testWidgets('the strip\'s Top up reopens the sheet', (tester) async {
    await pumpScreen(tester);
    await tester.enterText(
      find.byKey(const ValueKey('meal_planning.chat_input')),
      'hello',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('meal_planning.chat_send')));
    await tester.pumpAndSettle();

    // Dismiss the sheet the send raised.
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tokens.allowance')), findsNothing);
    expect(strip, findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('meal_planning.out_of_credits_top_up')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('tokens.allowance')), findsOneWidget);
  });
}
