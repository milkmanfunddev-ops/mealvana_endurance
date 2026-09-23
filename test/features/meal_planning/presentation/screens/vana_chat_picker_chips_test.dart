/// The picker's own chips fetch the next picker with no model turn (mp-464,
/// approved as mp-477; ai-cost ticket 12), driven through the REAL
/// VanaChatController from the chat screen. The chat transport counts every
/// request it sees: "Other options", "No recipe only" and "Under 20 min" make
/// none and run `next_picker` with the label as `chip`; "I like these" /
/// `Next: <type>` make none when the server brings the next type's picker,
/// and exactly one, as a tap, when it hands the step back to Vana (a fork
/// question or the wrap-up). "Different protein" still goes to her.
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
import 'package:mealvana_endurance/features/meal_planning/domain/meal_type.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/ui_action.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/user_memory.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_conversation_kind.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_fixed_chip.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_input_mode.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_message.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_moment.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_part.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_situation.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_stream_event.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/screens/vana_chat_screen.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/picker_chips.dart';

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
  _RecordingActions(this.draft);

  /// The conversation's draft, as `get_plan` answers it: the plan bar and
  /// the strip's filters read it.
  final VanaPart draft;
  final List<UiAction> ran = [];
  final Map<String, VanaActionResult> byType = {};

  @override
  Future<VanaActionResult> run(UiAction action) async {
    if (action is GetPlanAction) {
      return VanaActionResult(parts: [draft], extras: const {});
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
  final batch = VanaPart.fromJson(
    (loadFixture('batch')['parts'] as List).first as Map<String, dynamic>,
  )!;

  /// Vana's dinner picker, with the draft holding dinners: the strip shows
  /// "Next: Lunch", "Other options" and the three filters.
  final history = [
    _assistant('a-1', 'Carbs before Thursday.', [picker], 1),
  ];

  late _CountingChatRepo repo;
  late _RecordingActions actions;

  setUp(() {
    repo = _CountingChatRepo(history);
    actions = _RecordingActions(batch);
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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
    final chip = find.byKey(ValueKey('meal_planning.choice_chip_$label')).first;
    await tester.ensureVisible(chip);
    await tester.tap(chip);
    await settleTurn(tester);
  }

  final proseBubbles = find.byKey(const ValueKey('meal_planning.prose_bubble'));
  final pickers = find.byType(PickerChips);

  /// The next picker as `next_picker` answers it: a different dinner set.
  VanaActionResult nextPicker(String mealType) => VanaActionResult(
    parts: [
      VanaPart.fromJson({
        ...loadFixture('meal_picker'),
        'mealType': mealType,
        'title': 'Tap any — they go straight into your plan',
      })!,
    ],
    extras: const {'tapMessageId': 'u-2', 'messageId': 'a-2'},
  );

  for (final (label, kind) in [
    ('Other options', 'more'),
    ('No recipe only', 'no_recipe'),
    ('Under 20 min', 'under_20'),
  ]) {
    testWidgets('"$label" runs next_picker ($kind) with the label, makes no '
        'chat request, and the picker lands with no line from Vana', (
      tester,
    ) async {
      actions.byType['next_picker'] = nextPicker('dinner');
      await pumpScreen(tester);
      expect(pickers, findsOneWidget);

      await tapChip(tester, label);

      final ran = actions.ran.single as NextPickerAction;
      expect(ran.chipKind, kind);
      expect(ran.chip, label);
      expect(ran.conversationId, 'conv-1');
      expect(ran.mealType, isNull);
      expect(repo.chatRequests, 0);
      expect(pickers, findsNWidgets(2), reason: 'the next picker is drawn');
      expect(proseBubbles, findsOneWidget, reason: 'only her earlier line');
    });
  }

  testWidgets('"Next: Lunch" brings the lunch picker with no chat request '
      'when that is the whole next step', (tester) async {
    actions.byType['next_picker'] = nextPicker('lunch');
    await pumpScreen(tester);

    await tapChip(tester, 'Next: Lunch');

    final ran = actions.ran.single as NextPickerAction;
    expect(ran.chipKind, 'next');
    expect(ran.mealType, MealType.lunch);
    expect(ran.toPayloadJson(), {
      'conversationId': 'conv-1',
      'chip': 'Next: Lunch',
      'chipKind': 'next',
      'mealType': 'lunch',
    });
    expect(repo.chatRequests, 0);
    expect(pickers, findsNWidgets(2));
    expect(proseBubbles, findsOneWidget);
  });

  testWidgets('"Next: Lunch" goes to Vana as a tap when the next step is a '
      'question or the wrap-up, with one bubble for the tap', (tester) async {
    actions.byType['next_picker'] = const VanaActionResult(
      parts: [],
      extras: {'toVana': true, 'reason': 'ask'},
    );
    await pumpScreen(tester);

    await tapChip(tester, 'Next: Lunch');

    expect(actions.ran.map((a) => a.type), ['next_picker']);
    expect(repo.turns, [('Next: Lunch', 'tap')]);
    expect(
      find.text('Next: Lunch'),
      findsNWidgets(2),
      reason: 'the chip and one athlete bubble, never two',
    );
  });

  testWidgets('"Different protein" still goes to Vana, as a tap, with no '
      'action', (tester) async {
    await pumpScreen(tester);

    await tapChip(tester, 'Different protein');

    expect(actions.ran, isEmpty);
    expect(repo.turns, [('Different protein', 'tap')]);
  });

  test('the resolver reads every picker chip from the content system', () {
    final resolver = VanaFixedChipResolver((key) => content[key] ?? key);
    VanaPickerChipTap? of(String label) => resolver.picker(label);
    expect(of('Other options')?.chip, VanaPickerChip.more);
    expect(of('  no recipe ONLY ')?.chip, VanaPickerChip.noRecipe);
    expect(of('Under 20 min')?.chip, VanaPickerChip.under20);
    expect(of('I like these')?.chip, VanaPickerChip.next);
    expect(of('I like these')?.mealType, isNull);
    expect(of('Next: Breakfast')?.mealType, MealType.breakfast);
    expect(of('Next: Snack')?.chip, VanaPickerChip.next);
    for (final hers in ['Different protein', "That's my week", 'Adjust']) {
      expect(of(hers), isNull, reason: '$hers stays with Vana');
      expect(resolver.match(hers), isNull);
    }
  });
}
