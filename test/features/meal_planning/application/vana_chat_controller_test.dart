/// VanaChatController: streaming turns fold into messages, `batch` parts
/// go to the plan controller (never inline), `status` drives the status
/// line, and transport errors map to VanaChatErrorKind.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/ai_credits/domain/insufficient_credits_exception.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/feedback/data/wiredash_feedback_filer.dart';
import 'package:mealvana_endurance/features/feedback/domain/typed_feedback.dart';
import 'package:mealvana_endurance/features/meal_logging/application/meal_ai_service.dart';
import 'package:mealvana_endurance/features/meal_planning/application/meal_plan_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/application/vana_chat_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/application/vana_write_refetcher.dart';
import 'package:mealvana_endurance/features/meal_planning/data/user_memory_repository.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_action_client.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_chat_repository.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_exceptions.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_plan.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/memory_kind.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/ui_action.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/user_memory.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_input_mode.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_conversation_kind.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_fixed_chip.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_message.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_moment.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_situation.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_part.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_stream_event.dart';

import '../domain/fixture_helpers.dart';
import '../helpers/container.dart';
import '../presentation/helpers/test_content.dart';

class _FakeChatRepo extends Fake implements VanaChatRepository {
  _FakeChatRepo({
    this.events = const [],
    this.history = const [],
    this.throwOnStream,
  });

  List<VanaStreamEvent> events;
  List<VanaMessage> history;
  Object? throwOnStream;
  final List<Map<String, Object?>> calls = [];

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
    calls.add({
      'message': message,
      'conversationId': conversationId,
      'opener': opener,
      'anchorDate': anchorDate,
      'situation': situation?.toJson(),
      'moment': moment?.toWire(),
      'newPlan': newPlan,
      'inputMode': inputMode?.wire,
    });
    if (throwOnStream != null) throw throwOnStream!;
    return VanaChatResponse(
      conversationId: 'conv-server',
      kind: kind,
      events: Stream.fromIterable(events),
    );
  }

  @override
  Future<List<VanaMessage>> fetchMessages(String conversationId) async =>
      history;

  @override
  Future<String> createConversation(VanaConversationKind kind) async =>
      'conv-created';
}

/// Answers `vana-action` calls from a canned map keyed by action type and
/// records every action it ran.
class _FakeActionClient extends Fake implements VanaActionClient {
  final Map<String, VanaActionResult> byType = {};
  final Map<String, Object> failByType = {};
  final List<UiAction> ran = [];

  /// `build()` loads the conversation's own draft with `get_plan`; kept out
  /// of [ran] so the per-feature sequences below stay exact.
  final List<GetPlanAction> draftLoads = [];

  @override
  Future<VanaActionResult> run(UiAction action) async {
    if (action is GetPlanAction) {
      draftLoads.add(action);
    } else {
      ran.add(action);
    }
    final failure = failByType[action.type];
    if (failure != null) throw failure;
    return byType[action.type] ?? const VanaActionResult(parts: [], extras: {});
  }
}

class _FakeMealAiService extends Fake implements MealAiService {
  final List<int> uploadedLengths = [];
  Object? failWith;

  @override
  Future<String> uploadPhotoBytes(
    Uint8List bytes, {
    String extension = 'jpg',
  }) async {
    if (failWith != null) throw failWith!;
    uploadedLengths.add(bytes.length);
    return 'user-1/photo.$extension';
  }
}

/// Records folded plans instead of touching Drift.
class _RecordingPlanController extends MealPlanController {
  final List<MealPlan> applied = [];

  @override
  Future<MealPlan?> build() async => null;

  @override
  Future<void> applyServerPlan(MealPlan plan) async => applied.add(plan);
}

/// Stands in for the Wiredash SDK: records what the controller files.
class _FakeFeedbackFiler extends Fake implements WiredashFeedbackFiler {
  final List<TypedFeedback> filed = [];
  Object? failWith;

  @override
  Future<void> file(TypedFeedback feedback) async {
    if (failWith != null) throw failWith!;
    filed.add(feedback);
  }
}

/// Records which receipts asked for a refetch instead of touching the sync
/// coordinator (playtest §10).
class _FakeRefetcher extends Fake implements VanaWriteRefetcher {
  final List<VanaReceiptPart> after_ = [];
  Object? failWith;

  @override
  Future<void> after(VanaReceiptPart part) async {
    if (failWith != null) throw failWith!;
    after_.add(part);
  }
}

class _FakeMemoryRepo extends Fake implements UserMemoryRepository {
  final List<UserMemory> applied = [];

  @override
  Future<void> applyServerMemory(
    UserMemory memory, {
    required String userId,
  }) async => applied.add(memory);
}

List<VanaStreamEvent> eventsFromFixture(String name) =>
    (loadFixture(name)['lines'] as List)
        .cast<Map<String, dynamic>>()
        .map(VanaStreamEvent.fromJson)
        .whereType<VanaStreamEvent>()
        .toList();

void main() {
  late _FakeChatRepo repo;
  late _RecordingPlanController planController;
  late _FakeMemoryRepo memoryRepo;
  late _FakeActionClient actions;
  late _FakeMealAiService mealAi;
  late _FakeFeedbackFiler filer;
  late _FakeRefetcher refetcher;

  setUp(() {
    repo = _FakeChatRepo();
    planController = _RecordingPlanController();
    memoryRepo = _FakeMemoryRepo();
    actions = _FakeActionClient();
    mealAi = _FakeMealAiService();
    filer = _FakeFeedbackFiler();
    refetcher = _FakeRefetcher();
  });

  ({VanaChatController notifier, List<VanaChatState> seen}) make({
    VanaConversationKind kind = VanaConversationKind.mealPlanning,
    String? conversationId,
  }) {
    final container = testContainer([
      ...baseOverrides(),
      // The fixed chips the app draws itself are matched by their content
      // value ("Draft my whole week", "Use what I have").
      contentServiceProvider.overrideWith(testContentService),
      vanaChatRepositoryProvider.overrideWithValue(repo),
      mealPlanControllerProvider.overrideWith(() => planController),
      userMemoryRepositoryProvider.overrideWithValue(memoryRepo),
      vanaActionClientProvider.overrideWithValue(actions),
      mealAiServiceProvider.overrideWithValue(mealAi),
      wiredashFeedbackFilerProvider.overrideWithValue(filer),
      vanaWriteRefetcherProvider.overrideWithValue(refetcher),
    ]);
    final provider = vanaChatControllerProvider(
      kind: kind,
      conversationId: conversationId,
    );
    final seen = <VanaChatState>[];
    container.listen(provider, (_, next) {
      if (next.hasValue) seen.add(next.value!);
    });
    return (notifier: container.read(provider.notifier), seen: seen);
  }

  test(
    'opener fixture streams into one assistant message with a picker',
    () async {
      repo.events = eventsFromFixture('opener');
      final (:notifier, :seen) = make();
      await notifier.future;

      await notifier.loadOpener(anchorDate: '2026-09-01');

      final s = notifier.state.value!;
      expect(s.conversationId, 'conv-server');
      expect(s.isStreaming, isFalse);
      expect(s.statusTool, isNull);
      expect(s.messages, hasLength(1));
      expect(s.messages.single.isUser, isFalse);
      expect(s.messages.single.parts.single, isA<VanaMealPickerPart>());
      expect(repo.calls.single['opener'], isTrue);
      expect(repo.calls.single['anchorDate'], '2026-09-01');
      expect(repo.calls.single['newPlan'], isFalse);
      // The status line was visible mid-stream.
      expect(seen.any((st) => st.statusTool == 'suggestMeals'), isTrue);
    },
  );

  test(
    '"New meal plan" opener carries the new_plan intent to the server',
    () async {
      // Lee, 2026-09-16: tapping "New meal plan" over a confirmed week opened
      // with "are you here to log a meal, swap something, or adjust the week
      // ahead?". The intent rides the opener request so the server builds a
      // fresh plan and never asks about the old one.
      repo.events = eventsFromFixture('opener');
      final (:notifier, seen: _) = make();
      await notifier.future;

      await notifier.loadOpener(newPlan: true);

      expect(repo.calls.single['opener'], isTrue);
      expect(repo.calls.single['newPlan'], isTrue);
      expect(notifier.state.value!.conversationId, 'conv-server');
      expect(notifier.state.value!.messages, hasLength(1));
    },
  );

  test('a moment\'s opener is written into a conversation that already has '
      'turns, and carries the moment', () async {
    repo.history = [
      VanaMessage(
        id: 'm1',
        conversationId: 'conv-today',
        role: VanaMessageRole.user,
        content: 'What should I eat today?',
        createdAt: DateTime(2026, 9, 11, 9),
      ),
      VanaMessage(
        id: 'm2',
        conversationId: 'conv-today',
        role: VanaMessageRole.assistant,
        content: 'Oats at breakfast.',
        createdAt: DateTime(2026, 9, 11, 9),
      ),
    ];
    repo.events = const [VanaTextEvent('Your tempo run is at 5:30.')];
    final (:notifier, seen: _) = make(
      kind: VanaConversationKind.general,
      conversationId: 'conv-today',
    );
    await notifier.future;

    // Without a moment an opener never lands on a conversation with turns.
    await notifier.loadOpener();
    expect(repo.calls, isEmpty);

    final moment = VanaMoment(
      kind: VanaMomentKind.preWorkout,
      activityId: 'act-run',
      title: 'Tempo run',
      activityType: ActivityType.running,
      startsAt: DateTime(2026, 9, 11, 17, 30),
      windowOpensAt: DateTime(2026, 9, 11, 16, 30),
      closesAt: DateTime(2026, 9, 11, 17, 30),
      rings: false,
    );
    await notifier.loadOpener(moment: moment);

    expect(repo.calls.single['opener'], isTrue);
    expect(repo.calls.single['conversationId'], 'conv-today');
    expect(repo.calls.single['moment'], {
      'kind': 'pre_workout',
      'activity_id': 'act-run',
      'window_minutes': 60,
    });
    final messages = notifier.state.value!.messages;
    expect(messages, hasLength(3));
    expect(messages.last.content, 'Your tempo run is at 5:30.');
  });

  test(
    'send: text deltas accumulate, batch folds into the plan, memory_saved stored',
    () async {
      final batch = VanaPart.fromJson(
        (loadFixture('batch')['parts'] as List).first as Map<String, dynamic>,
      )!;
      repo.events = [
        const VanaTextEvent('Added. '),
        const VanaStatusEvent('updateBatch'),
        VanaUiEvent(batch),
        const VanaUiEvent(
          VanaMemorySavedPart(
            memory: UserMemory(
              id: 'mem-1',
              kind: MemoryKind.preference,
              fact: 'Likes lentils',
              confidence: 0.9,
              lastConfirmedAt: '2026-09-01T12:00:00Z',
            ),
          ),
        ),
        const VanaTextEvent('\n'),
        const VanaTextEvent('Next: lunches?'),
        const VanaDoneEvent(),
      ];
      final (:notifier, :seen) = make(conversationId: 'conv-1');
      await notifier.future;

      await notifier.tapChip('I like these');

      final s = notifier.state.value!;
      expect(repo.calls.single['message'], 'I like these');
      expect(repo.calls.single['conversationId'], 'conv-1');
      expect(s.messages, hasLength(2));
      expect(s.messages.first.isUser, isTrue);
      final reply = s.messages.last;
      expect(reply.content, 'Added. \nNext: lunches?');
      expect(
        reply.parts.whereType<VanaBatchPart>(),
        isEmpty,
        reason: 'batch is plan-bar state',
      );
      expect(reply.parts.single, isA<VanaMemorySavedPart>());
      expect(s.draftPlan!.id, (batch as VanaBatchPart).plan.id);
      expect(planController.applied.single.id, batch.plan.id);
      expect(memoryRepo.applied.single.fact, 'Likes lentils');
      expect(seen.any((st) => st.statusTool == 'updateBatch'), isTrue);
      expect(s.isStreaming, isFalse);
    },
  );

  group('feedback_saved files one Wiredash entry (ticket 26)', () {
    // The part exactly as `stream.ts` emits it: `{type:'ui', part:<tool output>}`,
    // with the server's own fixture as the part (producer-shaped, never a
    // Dart builder's output).
    List<VanaStreamEvent> feedbackTurn() => [
      VanaStreamEvent.fromJson({
        'type': 'ui',
        'part': loadFixture('feedback_saved'),
      })!,
      const VanaDoneEvent(),
    ];

    test('the entry carries the words, the sentiment and the conversation id, '
        'and the acknowledgement row is unchanged', () async {
      repo.events = feedbackTurn();
      final (:notifier, seen: _) = make(kind: VanaConversationKind.general);
      await notifier.future;

      await notifier.send(
        'You keep suggesting fish on weeknights, I never make it',
      );

      final entry = filer.filed.single;
      expect(entry.message, loadFixture('feedback_saved')['message']);
      expect(entry.sentiment, 'negative');
      expect(entry.about, 'vana');
      expect(
        entry.conversationId,
        'conv-server',
        reason: 'the id the server answered with, not the pre-turn null',
      );

      // The athlete still sees the server-authored row and nothing else.
      final reply = notifier.state.value!.messages.last;
      expect(reply.isUser, isFalse);
      expect(reply.content, isEmpty);
      final part = reply.parts.single as VanaFeedbackSavedPart;
      expect(part.message, entry.message);
      expect(part.sentiment, FeedbackSentiment.negative);
      expect(part.about, FeedbackAbout.vana);
    });

    test(
      'a Wiredash failure is logged and never reaches the athlete',
      () async {
        repo.events = feedbackTurn();
        filer.failWith = StateError('wiredash down');
        final (:notifier, seen: _) = make(kind: VanaConversationKind.general);
        await notifier.future;

        await notifier.send('You keep suggesting fish');

        final s = notifier.state.value!;
        expect(s.error, isNull);
        expect(s.messages.last.parts.single, isA<VanaFeedbackSavedPart>());
        expect(filer.filed, isEmpty);
      },
    );

    test('a turn without feedback files nothing', () async {
      repo.events = const [VanaTextEvent('Two dinners left.'), VanaDoneEvent()];
      final (:notifier, seen: _) = make(conversationId: 'conv-1');
      await notifier.future;

      await notifier.send('What is left?');

      expect(filer.filed, isEmpty);
    });
  });

  test(
    'history: batch parts are stripped from bubbles and seed draftPlan',
    () async {
      final batch =
          VanaPart.fromJson(
                (loadFixture('batch')['parts'] as List).first
                    as Map<String, dynamic>,
              )!
              as VanaBatchPart;
      repo.history = [
        VanaMessage(
          id: 'm-1',
          conversationId: 'conv-1',
          role: VanaMessageRole.assistant,
          content: 'Here is your week',
          parts: [batch],
          createdAt: DateTime.utc(2026, 9, 1),
        ),
      ];
      final (:notifier, seen: _) = make(conversationId: 'conv-1');
      final s = await notifier.future;
      expect(s.historyLoaded, isTrue);
      expect(s.messages.single.parts, isEmpty);
      expect(s.draftPlan!.id, batch.plan.id);
    },
  );

  group('rewindAndSend (plan Phase 6.1)', () {
    VanaBatchPart batchPart() =>
        VanaPart.fromJson(
              (loadFixture('batch')['parts'] as List).first
                  as Map<String, dynamic>,
            )!
            as VanaBatchPart;

    List<VanaMessage> history() => [
      VanaMessage(
        id: 'm-1',
        conversationId: 'conv-1',
        role: VanaMessageRole.assistant,
        content: 'Three dinners',
        createdAt: DateTime.utc(2026, 9, 1, 8),
      ),
      VanaMessage(
        id: 'm-2',
        conversationId: 'conv-1',
        role: VanaMessageRole.user,
        content: 'I like these',
        createdAt: DateTime.utc(2026, 9, 1, 8, 1),
      ),
      // A plan-touching assistant turn: its batch seeds draftPlan.
      VanaMessage(
        id: 'm-3',
        conversationId: 'conv-1',
        role: VanaMessageRole.assistant,
        content: 'Added.',
        parts: [batchPart()],
        createdAt: DateTime.utc(2026, 9, 1, 8, 2),
      ),
      VanaMessage(
        id: 'm-4',
        conversationId: 'conv-1',
        role: VanaMessageRole.user,
        content: 'Cheaper please',
        createdAt: DateTime.utc(2026, 9, 1, 8, 3),
      ),
      VanaMessage(
        id: 'm-5',
        conversationId: 'conv-1',
        role: VanaMessageRole.assistant,
        content: 'Swapped two.',
        createdAt: DateTime.utc(2026, 9, 1, 8, 4),
      ),
    ];

    // ---- conversation draft on load (a new plan starts empty)
    test('build asks get_plan for THIS conversation and uses its plan over the '
        'transcript', () async {
      repo.history = history();
      final draft = batchPart();
      actions.byType['get_plan'] = VanaActionResult(
        parts: [draft],
        extras: const {},
      );
      final (:notifier, seen: _) = make(conversationId: 'conv-1');
      final state = await notifier.future;
      expect(actions.draftLoads.single.conversationId, 'conv-1');
      expect(state.draftPlan?.id, draft.plan.id);
    });

    test(
      'no draft yet → no plan bar, even when the transcript is empty',
      () async {
        repo.history = const [];
        final (:notifier, seen: _) = make(conversationId: 'conv-1');
        final state = await notifier.future;
        expect(actions.draftLoads, hasLength(1));
        expect(state.draftPlan, isNull);
      },
    );

    test('a new conversation (no id) never calls the server', () async {
      final (:notifier, seen: _) = make(conversationId: null);
      final state = await notifier.future;
      expect(actions.draftLoads, isEmpty);
      expect(state.draftPlan, isNull);
    });

    // ---- refreshDraft: writes made on another screen (Browse meals)
    test(
      'refreshDraft re-asks get_plan and mirrors the returned draft',
      () async {
        repo.history = history();
        final (:notifier, seen: _) = make(conversationId: 'conv-1');
        final before = await notifier.future;
        expect(actions.draftLoads, hasLength(1));

        // The browse screen picked into the draft while the chat was covered
        // — a plan the transcript's batch part has never seen.
        final draft = VanaBatchPart(
          plan: MealPlan.fromJson({
            ...batchPart().plan.toJson(),
            'id': 'plan-after-browse',
          }),
        );
        actions.byType['get_plan'] = VanaActionResult(
          parts: [draft],
          extras: const {},
        );
        await notifier.refreshDraft();

        expect(actions.draftLoads, hasLength(2));
        expect(actions.draftLoads.last.conversationId, 'conv-1');
        final after = notifier.state.value!;
        expect(after.draftPlan?.id, draft.plan.id);
        expect(after.draftPlan?.id, isNot(before.draftPlan?.id));
        // The transcript is untouched — only the draft moved.
        expect(after.messages, before.messages);
        expect(planController.applied, isEmpty, reason: 'mirror only');
      },
    );

    test('refreshDraft keeps the current draft when the server has none or '
        'is unreachable', () async {
      repo.history = history();
      final loaded = batchPart();
      actions.byType['get_plan'] = VanaActionResult(
        parts: [loaded],
        extras: const {},
      );
      final (:notifier, seen: _) = make(conversationId: 'conv-1');
      await notifier.future;

      actions.byType.remove('get_plan');
      await notifier.refreshDraft();
      expect(notifier.state.value!.draftPlan?.id, loaded.plan.id);

      actions.failByType['get_plan'] = const VanaOfflineException('offline');
      await notifier.refreshDraft();
      expect(notifier.state.value!.draftPlan?.id, loaded.plan.id);
      expect(notifier.state.value!.error, isNull);
    });

    test('refreshDraft is a no-op for a conversation with no id', () async {
      final (:notifier, seen: _) = make(conversationId: null);
      await notifier.future;
      await notifier.refreshDraft();
      expect(actions.draftLoads, isEmpty);
    });

    test('past a plan-touching turn: restored batch folds, transcript cut, '
        'edited text sent on the same conversation', () async {
      repo.history = history();
      final restored = batchPart();
      actions.byType['rewind'] = VanaActionResult(
        parts: [restored],
        extras: const {'removed': 4},
      );
      repo.events = const [VanaTextEvent('Fresh answer'), VanaDoneEvent()];
      final (:notifier, :seen) = make(conversationId: 'conv-1');
      await notifier.future;

      await notifier.rewindAndSend('m-2', 'I like these but vegan');

      final rewind = actions.ran.single as RewindAction;
      expect(rewind.conversationId, 'conv-1');
      expect(rewind.messageId, 'm-2');
      // The snapshot plan went to the plan controller.
      expect(planController.applied.single.id, restored.plan.id);
      // Then the edited text went out as a normal turn on conv-1.
      expect(repo.calls.single['message'], 'I like these but vegan');
      expect(repo.calls.single['conversationId'], 'conv-1');
      final s = notifier.state.value!;
      expect(s.messages.map((m) => m.id).take(1), ['m-1']);
      expect(s.messages, hasLength(3), reason: 'm-1 + new user + reply');
      expect(s.messages[1].isUser, isTrue);
      expect(s.messages[1].content, 'I like these but vegan');
      expect(s.messages.last.content, 'Fresh answer');
      expect(s.draftPlan!.id, restored.plan.id);
      expect(s.isStreaming, isFalse);
      // The send was blocked while the rewind was in flight.
      expect(seen.any((st) => st.isStreaming), isTrue);
    });

    test('no batch back clears the local draft plan', () async {
      repo.history = history();
      actions.byType['rewind'] = const VanaActionResult(
        parts: [],
        extras: {'removed': 5},
      );
      repo.events = const [VanaDoneEvent()];
      final (:notifier, seen: _) = make(conversationId: 'conv-1');
      final before = await notifier.future;
      expect(before.draftPlan, isNotNull);

      await notifier.rewindAndSend('m-2', 'start over');

      expect(notifier.state.value!.draftPlan, isNull);
      expect(planController.applied, isEmpty);
      expect(notifier.state.value!.messages.first.id, 'm-1');
    });

    test(
      'a failed rewind keeps the transcript and reports the error',
      () async {
        repo.history = history();
        actions.failByType['rewind'] = const VanaOfflineException('down');
        final (:notifier, seen: _) = make(conversationId: 'conv-1');
        await notifier.future;

        await notifier.rewindAndSend('m-4', 'never mind');

        final s = notifier.state.value!;
        expect(s.error, VanaChatErrorKind.offline);
        expect(s.messages, hasLength(5));
        expect(s.isStreaming, isFalse);
        expect(
          repo.calls,
          isEmpty,
          reason: 'no chat turn after a failed rewind',
        );
      },
    );

    test('an unknown message id degrades to a plain send', () async {
      repo.history = history();
      repo.events = const [VanaDoneEvent()];
      final (:notifier, seen: _) = make(conversationId: 'conv-1');
      await notifier.future;

      await notifier.rewindAndSend('optimistic_123', 'hello');

      expect(actions.ran, isEmpty);
      expect(repo.calls.single['message'], 'hello');
    });
  });

  group('pantry (plan Phase 7.3)', () {
    test('sendPantryPhoto uploads, runs pantry_photo and appends the '
        'persisted assistant message', () async {
      actions.byType['pantry_photo'] = VanaActionResult(
        parts: VanaPart.listFromJson([loadFixture('pantry')]),
        extras: const {'messageId': 'msg-9'},
      );
      final (:notifier, :seen) = make(conversationId: 'conv-1');
      await notifier.future;

      await notifier.sendPantryPhoto(Uint8List(12), extension: 'jpg');

      expect(mealAi.uploadedLengths, [12]);
      final action = actions.ran.single as PantryPhotoAction;
      expect(action.conversationId, 'conv-1');
      expect(action.photoPath, 'user-1/photo.jpg');
      final s = notifier.state.value!;
      expect(s.messages.single.id, 'msg-9');
      expect(s.messages.single.isUser, isFalse);
      expect(s.isStreaming, isFalse);
      expect(s.statusTool, isNull);
      expect(s.error, isNull);
      // The status line named the client-side tool while it ran.
      expect(
        seen.any(
          (st) =>
              st.isStreaming &&
              st.statusTool == VanaChatController.pantryPhotoTool,
        ),
        isTrue,
      );
    });

    test(
      'sendPantryPhoto creates the conversation when there is none',
      () async {
        actions.byType['pantry_photo'] = const VanaActionResult(
          parts: [],
          extras: {'messageId': 'msg-1'},
        );
        final (:notifier, seen: _) = make();
        await notifier.future;

        await notifier.sendPantryPhoto(Uint8List(3));

        expect(
          (actions.ran.single as PantryPhotoAction).conversationId,
          'conv-created',
        );
        expect(notifier.state.value!.conversationId, 'conv-created');
      },
    );

    test('an upload failure rolls back the placeholder', () async {
      mealAi.failWith = const MealAiException(
        kind: MealAiFailureKind.offline,
        userMessage: 'offline',
      );
      final (:notifier, seen: _) = make(conversationId: 'conv-1');
      await notifier.future;

      await notifier.sendPantryPhoto(Uint8List(3));

      final s = notifier.state.value!;
      expect(s.error, VanaChatErrorKind.offline);
      expect(s.messages, isEmpty);
      expect(s.isStreaming, isFalse);
      expect(actions.ran, isEmpty);
    });

    test('usePantry records the items at once with the app\'s line as the '
        'tap, and sends Vana nothing (mp-464)', () async {
      actions.byType['set_pantry'] = VanaActionResult(
        parts: const [
          VanaMemorySavedPart(
            memory: UserMemory(
              id: 'mem-p',
              kind: MemoryKind.setting,
              fact: 'Has on hand: eggs, rice',
              confidence: 1,
              lastConfirmedAt: '2026-09-22T12:00:00Z',
            ),
          ),
        ],
        extras: const {'tapMessageId': 'u-9', 'messageId': 'a-9'},
      );
      final (:notifier, seen: _) = make(conversationId: 'conv-1');
      await notifier.future;

      await notifier.usePantry([
        'eggs',
        'rice',
      ], message: 'I have eggs, rice on hand — use these');

      final set = actions.ran.single as SetPantryAction;
      expect(set.conversationId, 'conv-1');
      expect(set.items, ['eggs', 'rice']);
      expect(set.chip, 'I have eggs, rice on hand — use these');
      expect(repo.calls, isEmpty, reason: 'no model turn');
      final s = notifier.state.value!;
      expect(s.messages.map((m) => m.id), ['u-9', 'a-9']);
      expect(s.messages.first.content, 'I have eggs, rice on hand — use these');
      expect(s.messages.last.content, '', reason: 'Vana writes no line');
      expect(s.messages.last.parts.single, isA<VanaMemorySavedPart>());
      expect(memoryRepo.applied.single.fact, 'Has on hand: eggs, rice');
      expect(s.isStreaming, isFalse);
    });

    test(
      'usePantry: a failed set_pantry rolls the tap back and reports it',
      () async {
        actions.failByType['set_pantry'] = const VanaRateLimitedException(
          retryAfterSeconds: 5,
        );
        final (:notifier, seen: _) = make(conversationId: 'conv-1');
        await notifier.future;

        await notifier.usePantry(['eggs'], message: 'use these');

        expect(repo.calls, isEmpty);
        expect(notifier.state.value!.messages, isEmpty);
        expect(notifier.state.value!.error, VanaChatErrorKind.rateLimited);
        expect(notifier.state.value!.retryAfterSeconds, 5);
      },
    );
  });

  // mp-464 clause 1 (ai-cost ticket 11): a chip whose next step is fixed acts
  // at once on the no-model endpoint, with the label as the stored tap.
  group('chips that act at once (mp-464)', () {
    final batch =
        VanaPart.fromJson(
              (loadFixture('batch')['parts'] as List).first
                  as Map<String, dynamic>,
            )!
            as VanaBatchPart;

    test('"Draft my whole week" runs draft_week with the label, sends no chat '
        'request, folds the batch and draws no turn', () async {
      actions.byType['draft_week'] = VanaActionResult(
        parts: [batch],
        extras: const {'tapMessageId': 'u-1', 'messageId': 'a-1'},
      );
      final (:notifier, :seen) = make(conversationId: 'conv-1');
      await notifier.future;

      await notifier.tapChip('Draft my whole week');

      final ran = actions.ran.single as DraftWeekAction;
      expect(ran.conversationId, 'conv-1');
      expect(ran.chip, 'Draft my whole week');
      expect(ran.toJson()['payload'], {
        'conversationId': 'conv-1',
        'chip': 'Draft my whole week',
      });
      expect(repo.calls, isEmpty, reason: 'no model turn');
      final s = notifier.state.value!;
      // The athlete's bubble stays with its stored id; a batch alone is plan
      // bar state, so there is no assistant turn to draw.
      expect(s.messages.map((m) => (m.id, m.isUser, m.content)), [
        ('u-1', true, 'Draft my whole week'),
      ]);
      expect(s.draftPlan!.id, batch.plan.id);
      expect(planController.applied.single.id, batch.plan.id);
      expect(
        seen.any((st) => st.isStreaming && st.statusTool == 'draftWeek'),
        isTrue,
        reason: 'the status line names the tool the chip stands in for',
      );
      expect(s.isStreaming, isFalse);
      expect(s.statusTool, isNull);
    });

    test('a coverage answer records the setting; the memory row is the turn, '
        'with no line', () async {
      actions.byType['set_setting'] = const VanaActionResult(
        parts: [
          VanaMemorySavedPart(
            memory: UserMemory(
              id: 'mem-c',
              kind: MemoryKind.setting,
              fact: 'Plans dinners only',
              confidence: 1,
              lastConfirmedAt: '2026-09-22T12:00:00Z',
            ),
          ),
        ],
        extras: {'tapMessageId': 'u-2', 'messageId': 'a-2'},
      );
      final (:notifier, seen: _) = make(conversationId: 'conv-1');
      await notifier.future;

      await notifier.tapChip('Dinners only');

      final ran = actions.ran.single as SetSettingAction;
      expect(ran.key.wire, 'coverage_scope');
      expect(ran.value, 'dinners');
      expect(ran.chip, 'Dinners only');
      expect(repo.calls, isEmpty);
      final reply = notifier.state.value!.messages.last;
      expect(reply.id, 'a-2');
      expect(reply.isUser, isFalse);
      expect(reply.content, '');
      expect(reply.parts.single, isA<VanaMemorySavedPart>());
      expect(memoryRepo.applied.single.fact, 'Plans dinners only');
    });

    test('the batch answers map to batch_cooking true and false', () async {
      final (:notifier, seen: _) = make(conversationId: 'conv-1');
      await notifier.future;

      await notifier.tapChip('Batch cook');
      await notifier.tapChip('cook most nights');

      expect(actions.ran.map((a) => (a as SetSettingAction).value), [
        true,
        false,
      ]);
      expect(repo.calls, isEmpty);
    });

    test('"Open shopping list" records the tap, draws nothing, and names '
        'where the app goes', () async {
      actions.byType['open_shopping_list'] = const VanaActionResult(
        parts: [],
        extras: {'tapMessageId': 'u-3', 'messageId': 'a-3'},
      );
      final (:notifier, seen: _) = make(conversationId: 'conv-1');
      await notifier.future;

      final chip = notifier.fixedChipFor('Open shopping list');
      expect(chip, VanaFixedChip.openShoppingList);
      expect(chip!.navigatesTo, '/main?tab=food&food=shopping');
      await notifier.tapChip('Open shopping list');

      expect(actions.ran.single, isA<OpenShoppingListAction>());
      expect(actions.ran.single.chip, 'Open shopping list');
      expect(repo.calls, isEmpty);
      final s = notifier.state.value!;
      expect(s.messages.map((m) => (m.id, m.isUser)), [('u-3', true)]);
    });

    test('"Lay it across the week" and "Use what I have" bring their widget '
        'with no line', () async {
      actions.byType['plan_week'] = VanaActionResult(
        parts: [VanaPart.fromJson(loadFixture('week'))!],
        extras: const {'tapMessageId': 'u-4', 'messageId': 'a-4'},
      );
      actions.byType['ask_pantry'] = VanaActionResult(
        parts: [VanaPart.fromJson(loadFixture('pantry'))!],
        extras: const {'tapMessageId': 'u-5', 'messageId': 'a-5'},
      );
      final (:notifier, seen: _) = make(conversationId: 'conv-1');
      await notifier.future;

      await notifier.tapChip('Lay it across the week');
      await notifier.tapChip('Use what I have');

      expect(actions.ran.map((a) => a.type), ['plan_week', 'ask_pantry']);
      expect(repo.calls, isEmpty);
      final messages = notifier.state.value!.messages;
      expect(messages.map((m) => m.id), ['u-4', 'a-4', 'u-5', 'a-5']);
      expect(messages[1].parts.single, isA<VanaWeekPart>());
      expect(messages[1].content, '');
      expect(messages[3].parts.single, isA<VanaPantryPart>());
      expect(messages[3].content, '');
    });

    test(
      '"Same as last time" on a conversation with no id creates one first',
      () async {
        actions.byType['same_as_last_time'] = VanaActionResult(
          parts: [batch],
          extras: const {'tapMessageId': 'u-6', 'messageId': 'a-6'},
        );
        final (:notifier, seen: _) = make();
        await notifier.future;

        await notifier.tapChip('Same as last time');

        expect(actions.ran.single.conversationId, 'conv-created');
        expect(notifier.state.value!.conversationId, 'conv-created');
        expect(notifier.state.value!.draftPlan!.id, batch.plan.id);
      },
    );

    test('a chip Vana named herself, "Adjust" and a typed message still go '
        'to Vana, as taps and typed', () async {
      repo.events = const [VanaDoneEvent()];
      final (:notifier, seen: _) = make(conversationId: 'conv-1');
      await notifier.future;

      await notifier.tapChip('Something new');
      await notifier.tapChip('Adjust');
      await notifier.tapChip('Different protein');
      await notifier.send('swap the fish for chicken');

      expect(actions.ran, isEmpty, reason: 'nothing acted at once');
      expect(repo.calls.map((c) => [c['message'], c['inputMode']]), [
        ['Something new', 'tap'],
        ['Adjust', 'tap'],
        ['Different protein', 'tap'],
        ['swap the fish for chicken', 'typed'],
      ]);
    });

    test('a failed action rolls the tap back and reports the error', () async {
      actions.failByType['draft_week'] = const VanaOfflineException('offline');
      final (:notifier, seen: _) = make(conversationId: 'conv-1');
      await notifier.future;

      await notifier.tapChip('Draft my whole week');

      final s = notifier.state.value!;
      expect(s.messages, isEmpty);
      expect(s.isStreaming, isFalse);
      expect(s.error, VanaChatErrorKind.offline);
      expect(repo.calls, isEmpty);
    });

    test(
      'a stored assistant turn with nothing to draw is not a bubble',
      () async {
        repo.history = [
          VanaMessage(
            id: 'u-1',
            conversationId: 'conv-1',
            role: VanaMessageRole.user,
            content: 'Open shopping list',
            createdAt: DateTime(2026, 9, 22, 12),
          ),
          // The tap's stored turn: a tool part of a kind the app does not draw
          // parsed to nothing, and no text.
          VanaMessage(
            id: 'a-1',
            conversationId: 'conv-1',
            role: VanaMessageRole.assistant,
            content: '',
            createdAt: DateTime(2026, 9, 22, 12, 0, 1),
          ),
          VanaMessage(
            id: 'u-2',
            conversationId: 'conv-1',
            role: VanaMessageRole.user,
            content: 'Draft my whole week',
            createdAt: DateTime(2026, 9, 22, 12, 1),
          ),
          // A draft-week tap's stored turn: its only part was the batch.
          VanaMessage(
            id: 'a-2',
            conversationId: 'conv-1',
            role: VanaMessageRole.assistant,
            content: '',
            parts: [batch],
            createdAt: DateTime(2026, 9, 22, 12, 1, 1),
          ),
        ];
        final (:notifier, seen: _) = make(conversationId: 'conv-1');
        final s = await notifier.future;

        expect(s.messages.map((m) => m.id), ['u-1', 'u-2']);
        expect(
          s.draftPlan!.id,
          batch.plan.id,
          reason: 'the batch still counts',
        );
      },
    );
  });

  // Lee's playtest 2026-09-16 §10: a receipt is the cue to refetch the
  // offline-first store it names; Undo runs the receipt's own action.
  group('receipt (Vana writes)', () {
    List<VanaStreamEvent> receiptTurn(String fixture) => [
      VanaStreamEvent.fromJson({'type': 'ui', 'part': loadFixture(fixture)})!,
      const VanaTextEvent('Done.'),
      const VanaDoneEvent(),
    ];

    test('a receipt in the stream lands in the transcript and asks for the '
        'entity it names to be refetched', () async {
      repo.events = receiptTurn('receipt');
      final (:notifier, seen: _) = make(kind: VanaConversationKind.general);
      await notifier.future;

      await notifier.send('delete my Ironman, yes');
      await settle();

      final reply = notifier.state.value!.messages.last;
      final part = reply.parts.single as VanaReceiptPart;
      expect(part.action, VanaReceiptAction.deleteEvent);
      expect(reply.content, 'Done.');
      expect(refetcher.after_.single.entity, VanaReceiptEntity.event);
      expect(actions.ran, isEmpty, reason: 'the stream write is the server\'s');
    });

    test('a failed refetch is logged, never shown', () async {
      repo.events = receiptTurn('receipt_no_undo');
      refetcher.failWith = StateError('sync down');
      final (:notifier, seen: _) = make(conversationId: 'conv-1');
      await notifier.future;

      await notifier.send('start over');
      await settle();

      final s = notifier.state.value!;
      expect(s.error, isNull);
      expect(s.messages.last.parts.single, isA<VanaReceiptPart>());
    });

    test('undoReceipt sends the receipt\'s params verbatim as undo_receipt '
        'and refetches from the answering receipt', () async {
      final part = VanaPart.fromJson(loadFixture('receipt')) as VanaReceiptPart;
      final answered = VanaPart.fromJson({
        ...loadFixture('receipt_no_undo'),
        'action': 'undo',
        'entity': 'event',
        'summary': 'Put back IRONMAN Cozumel',
      })!;
      actions.byType['undo_receipt'] = VanaActionResult(
        parts: [answered],
        extras: const {},
      );
      final (:notifier, seen: _) = make(kind: VanaConversationKind.general);
      await notifier.future;

      await notifier.undoReceipt(part);

      final undo = actions.ran.single as UndoReceiptAction;
      expect(undo.toJson()['payload'], part.undo!.params);
      expect(
        (undo.toJson()['payload'] as Map)['row'],
        loadFixture('receipt')['undo']['params']['row'],
      );
      expect(refetcher.after_.single.action, VanaReceiptAction.undo);
      expect(refetcher.after_.single.entity, VanaReceiptEntity.event);
    });

    test('undoReceipt surfaces a failed action to the caller', () async {
      final part = VanaPart.fromJson(loadFixture('receipt')) as VanaReceiptPart;
      actions.failByType['undo_receipt'] = const VanaServerException(
        400,
        'boom',
      );
      final (:notifier, seen: _) = make(kind: VanaConversationKind.general);
      await notifier.future;

      await expectLater(
        notifier.undoReceipt(part),
        throwsA(isA<VanaServerException>()),
      );
      expect(refetcher.after_, isEmpty);
    });

    test('a receipt without an undo is a no-op', () async {
      final part =
          VanaPart.fromJson(loadFixture('receipt_no_undo')) as VanaReceiptPart;
      final (:notifier, seen: _) = make(kind: VanaConversationKind.general);
      await notifier.future;
      await notifier.undoReceipt(part);
      expect(actions.ran, isEmpty);
    });
  });

  group('errors', () {
    test(
      '403 pro_required → proRequired flag, optimistic turn rolled back',
      () async {
        repo.throwOnStream = const ProRequiredException();
        final (:notifier, seen: _) = make();
        await notifier.future;

        await notifier.send('hello');

        final s = notifier.state.value!;
        expect(s.error, VanaChatErrorKind.proRequired);
        expect(s.proRequired, isTrue);
        expect(s.messages, isEmpty);
        expect(s.isStreaming, isFalse);

        notifier.clearError();
        expect(notifier.state.value!.error, isNull);
      },
    );

    test(
      '402 → insufficientCredits; the turn rolls back and no message says so (mp-282)',
      () async {
        // The 402 body as credits.ts sends it, with the Allowance fields.
        repo.throwOnStream = InsufficientCreditsException.fromMap({
          'error': 'insufficient_credits',
          'message': 'You are out of AI credits. Purchase more to continue.',
          'balance': 0,
          'cost': 1,
          'allowance_monthly': 300,
          'allowance_expires_at': '2026-10-15T12:00:00+00:00',
        });
        final (:notifier, :seen) = make();
        await notifier.future;

        await notifier.send('plan my week');

        final s = notifier.state.value!;
        expect(s.error, VanaChatErrorKind.insufficientCredits);
        expect(s.isStreaming, isFalse);
        expect(
          s.messages,
          isEmpty,
          reason: 'the optimistic pair is rolled back',
        );
        // Nothing Vana ever showed mentions credits — the sheet is the answer.
        for (final state in seen) {
          for (final m in state.messages) {
            expect(m.content.toLowerCase(), isNot(contains('credit')));
          }
        }
        expect(repo.calls.single['message'], 'plan my week');
      },
    );

    test('429 → rateLimited with retryAfterSeconds', () async {
      repo.throwOnStream = const VanaRateLimitedException(retryAfterSeconds: 9);
      final (:notifier, seen: _) = make();
      await notifier.future;
      await notifier.send('hello');
      expect(notifier.state.value!.error, VanaChatErrorKind.rateLimited);
      expect(notifier.state.value!.retryAfterSeconds, 9);
    });

    test('offline → offline; a mid-stream error line keeps the text', () async {
      repo.throwOnStream = const VanaOfflineException('down');
      final (:notifier, seen: _) = make();
      await notifier.future;
      await notifier.send('hello');
      expect(notifier.state.value!.error, VanaChatErrorKind.offline);

      repo.throwOnStream = null;
      repo.events = const [
        VanaTextEvent('Partial'),
        VanaErrorEvent('model hiccup'),
        VanaDoneEvent(),
      ];
      notifier.clearError();
      await notifier.send('again');
      final s = notifier.state.value!;
      expect(s.error, VanaChatErrorKind.server);
      expect(s.messages.last.content, 'Partial');
    });

    test('a second send while streaming is ignored', () async {
      final gate = Completer<void>();
      repo.events = const [VanaDoneEvent()];
      final (:notifier, seen: _) = make();
      await notifier.future;
      // Hold the stream open by delaying the repo response.
      final slow = _FakeChatRepo(events: const [VanaDoneEvent()]);
      repo.events = slow.events;
      unawaited(notifier.send('first').then((_) => gate.complete()));
      await notifier.send('second');
      await gate.future;
      expect(repo.calls.map((c) => c['message']), ['first']);
    });
  });

  // mp-464 clause 7 / ai-cost ticket 05: every message says whether it was
  // tapped or typed, so the saving the fixed-label chips make is measurable
  // against the chip taps that still cost a turn. Driven through the real
  // notifier — the write path is the request the repository sends.
  group('tap or typed rides every message', () {
    test(
      'the composer types, a chip taps, and the opener says neither',
      () async {
        repo.events = const [VanaDoneEvent()];
        final (:notifier, seen: _) = make();
        await notifier.future;

        await notifier.loadOpener(anchorDate: '2026-09-22');
        await notifier.send('what should I eat tonight?');
        await notifier.tapChip('I like these');

        expect(repo.calls.map((c) => [c['opener'], c['inputMode']]), [
          [true, null],
          [false, 'typed'],
          [false, 'tap'],
        ]);
      },
    );

    test('"Use these" on the pantry card is a tap the server logs itself: '
        'no chat request carries it', () async {
      repo.events = const [VanaDoneEvent()];
      actions.byType['set_pantry'] = const VanaActionResult(
        parts: [],
        extras: {},
      );
      final (:notifier, seen: _) = make(conversationId: 'conv-1');
      await notifier.future;

      await notifier.usePantry(const [
        'eggs',
        'rice',
      ], message: 'I have eggs and rice on hand');

      expect(repo.calls, isEmpty);
      expect(actions.ran.single.chip, 'I have eggs and rice on hand');
    });

    test('an edited athlete turn is typed, not tapped', () async {
      repo.events = const [VanaDoneEvent()];
      final (:notifier, seen: _) = make();
      await notifier.future;

      // No conversation id and no such message: rewindAndSend degrades to a
      // plain send, which is still the athlete typing.
      await notifier.rewindAndSend('no-such-message', 'actually, pasta');

      expect(repo.calls.single['inputMode'], 'typed');
    });
  });
}
