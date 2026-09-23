/// Chips with one fixed meaning act at once, with no model turn (mp-464,
/// ai-cost ticket 11), driven through the REAL VanaChatController from the
/// chat screen. The chat transport counts every request it sees: a fixed
/// chip makes none and runs its action on `vana-action` with the label as
/// `chip`; a chip Vana named herself, "Adjust" and the composer still make
/// one. The tap becomes the athlete's bubble, Vana writes no line, and the
/// shopping-list chip leaves the screen for the Shopping segment.
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

/// The chat transport, counting. Every turn that reaches it is a model turn.
class _CountingChatRepo extends Fake implements VanaChatRepository {
  _CountingChatRepo(this.history);

  final List<VanaMessage> history;
  final List<(String?, String?)> turns = [];

  int get chatRequests => turns.length;

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
    turns.add((message, inputMode?.wire));
    // An `async*` generator, not Stream.value: the controller breaks out of
    // its `await for` on `done`, which awaits the subscription's cancel, and
    // a value stream's cancel future belongs to the root zone, where fake
    // async never runs it (the companion tests hit the same wall).
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

/// `vana-action`, recording. Answers from a canned map keyed by type.
class _RecordingActions extends Fake implements VanaActionClient {
  final List<UiAction> ran = [];
  final Map<String, VanaActionResult> byType = {};

  @override
  Future<VanaActionResult> run(UiAction action) async {
    if (action is GetPlanAction) {
      return const VanaActionResult(parts: [], extras: {});
    }
    ran.add(action);
    return byType[action.type] ?? const VanaActionResult(parts: [], extras: {});
  }
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

VanaMessage _assistant(
  String id,
  String content,
  List<VanaPart> parts,
  int s,
) => VanaMessage(
  id: id,
  conversationId: 'conv-1',
  role: VanaMessageRole.assistant,
  content: content,
  parts: parts,
  createdAt: DateTime(2026, 9, 22, 12, 0, s),
);

void main() {
  final content = loadDefaultContent();
  final picker = VanaPart.fromJson(loadFixture('meal_picker'))!;
  final pantry = VanaPart.fromJson(loadFixture('pantry'))!;
  final batch = VanaPart.fromJson(
    (loadFixture('batch')['parts'] as List).first as Map<String, dynamic>,
  )!;

  /// A planning conversation as the screen loads it: the opener's fork, the
  /// first picker (its strip carries "Draft my whole week"), a pantry card,
  /// and the post-confirm question.
  final history = [
    _assistant('a-1', 'Chattanooga is 11 days out.', const [
      VanaChoicesPart(options: ['Same as last time', 'Something new']),
    ], 1),
    _assistant('a-2', '', [picker], 2),
    _assistant('a-3', '', [pantry], 3),
    _assistant('a-4', '', const [
      VanaChoicesPart(
        options: ['Open shopping list', 'Lay it across the week', 'Adjust'],
      ),
    ], 4),
  ];

  late _CountingChatRepo repo;
  late _RecordingActions actions;
  late GoRouter router;

  setUp(() {
    repo = _CountingChatRepo(history);
    actions = _RecordingActions();
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    // Tall enough that every chip of the four turns is on screen.
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    router = GoRouter(
      initialLocation: '/vana',
      routes: [
        GoRoute(
          path: '/vana',
          builder: (_, __) => const VanaChatScreen(
            kind: VanaConversationKind.mealPlanning,
            conversationId: 'conv-1',
          ),
        ),
        GoRoute(
          path: '/main',
          builder: (_, __) => const Scaffold(body: Text('main shell')),
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          ...baseOverrides(),
          contentServiceProvider.overrideWith(testContentService),
          vanaChatRepositoryProvider.overrideWithValue(repo),
          mealPlanControllerProvider.overrideWith(() => _NoPlan()),
          userMemoryRepositoryProvider.overrideWithValue(_FakeMemoryRepo()),
          vanaActionClientProvider.overrideWithValue(actions),
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

  /// Let a turn land. The typing indicator animates while a turn is in
  /// flight, so never pumpAndSettle with one open.
  Future<void> settleTurn(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> tapChip(WidgetTester tester, String label) async {
    final chip = find.byKey(ValueKey('meal_planning.choice_chip_$label'));
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await settleTurn(tester);
  }

  final proseBubbles = find.byKey(const ValueKey('meal_planning.prose_bubble'));

  testWidgets('"Same as last time" runs same_as_last_time with the label, '
      'makes no chat request, and Vana writes no line', (tester) async {
    actions.byType['same_as_last_time'] = VanaActionResult(
      parts: [batch],
      extras: const {'tapMessageId': 'u-1', 'messageId': 'a-5'},
    );
    await pumpScreen(tester);
    expect(proseBubbles, findsOneWidget, reason: 'the opener\'s line');

    await tapChip(tester, 'Same as last time');

    expect(actions.ran.map((a) => a.type), ['same_as_last_time']);
    expect(actions.ran.single.chip, 'Same as last time');
    expect(actions.ran.single.conversationId, 'conv-1');
    expect(repo.chatRequests, 0);
    // The chip and the athlete's bubble; no new line from Vana.
    expect(find.text('Same as last time'), findsNWidgets(2));
    expect(proseBubbles, findsOneWidget);
  });

  testWidgets('a chip Vana named herself and "Adjust" still go to Vana, as '
      'taps', (tester) async {
    await pumpScreen(tester);

    await tapChip(tester, 'Something new');
    await tapChip(tester, 'Adjust');

    expect(actions.ran, isEmpty);
    expect(repo.turns, [('Something new', 'tap'), ('Adjust', 'tap')]);
  });

  testWidgets('"Draft my whole week" under the first picker runs draft_week '
      'with no chat request', (tester) async {
    actions.byType['draft_week'] = VanaActionResult(
      parts: [batch],
      extras: const {'tapMessageId': 'u-2', 'messageId': 'a-6'},
    );
    await pumpScreen(tester);

    final draft = find.byKey(const ValueKey('meal_planning.chip_draft_week'));
    await tester.ensureVisible(draft);
    await tester.tap(draft);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(actions.ran.map((a) => a.type), ['draft_week']);
    expect(actions.ran.single.chip, content['meal_planning.chip_draft_week']);
    expect(repo.chatRequests, 0);
    expect(proseBubbles, findsOneWidget);
  });

  testWidgets('the batch and coverage answers run set_setting with the label '
      'and no chat request', (tester) async {
    repo = _CountingChatRepo([
      _assistant('a-1', 'Two things to settle.', const [
        VanaChoicesPart(options: ['Batch cook', 'Cook most nights']),
      ], 1),
      _assistant('a-2', '', const [
        VanaChoicesPart(
          options: ['Dinners only', 'Dinners and lunches', 'Every meal'],
        ),
      ], 2),
    ]);
    await pumpScreen(tester);

    await tapChip(tester, 'Cook most nights');
    await tapChip(tester, 'Dinners and lunches');

    expect(
      actions.ran.map((a) => '${(a as SetSettingAction).key.wire}=${a.value}'),
      ['batch_cooking=false', 'coverage_scope=dinners_lunches'],
    );
    expect(actions.ran.map((a) => a.chip), [
      'Cook most nights',
      'Dinners and lunches',
    ]);
    expect(repo.chatRequests, 0);
  });

  testWidgets('"Use these" on the pantry card runs set_pantry with the app\'s '
      'line as the tap and no chat request', (tester) async {
    await pumpScreen(tester);

    final use = find.byKey(const ValueKey('meal_planning.pantry_use'));
    await tester.ensureVisible(use);
    await tester.tap(use);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final set = actions.ran.single as SetPantryAction;
    expect(set.items, ['eggs', 'rice', 'chicken thighs']);
    expect(set.chip, 'I have eggs, rice, chicken thighs on hand — use these');
    expect(repo.chatRequests, 0);
    expect(
      find.text('I have eggs, rice, chicken thighs on hand — use these'),
      findsOneWidget,
      reason: 'the app\'s line is the athlete\'s bubble',
    );
  });

  testWidgets('"Lay it across the week" runs plan_week and draws the week '
      'with no line', (tester) async {
    actions.byType['plan_week'] = VanaActionResult(
      parts: [VanaPart.fromJson(loadFixture('week'))!],
      extras: const {'tapMessageId': 'u-3', 'messageId': 'a-7'},
    );
    await pumpScreen(tester);

    await tapChip(tester, 'Lay it across the week');

    expect(actions.ran.map((a) => a.type), ['plan_week']);
    expect(repo.chatRequests, 0);
    expect(proseBubbles, findsOneWidget);
  });

  testWidgets('"Open shopping list" records the tap and leaves for the '
      'Shopping segment', (tester) async {
    await pumpScreen(tester);

    await tapChip(tester, 'Open shopping list');
    await tester.pumpAndSettle();

    expect(actions.ran.map((a) => a.type), ['open_shopping_list']);
    expect(actions.ran.single.chip, 'Open shopping list');
    expect(repo.chatRequests, 0);
    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/main?tab=food&food=shopping',
    );
    expect(find.text('main shell'), findsOneWidget);
  });
}
