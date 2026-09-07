/// VanaChatController: streaming turns fold into messages, `batch` parts
/// go to the plan controller (never inline), `status` drives the status
/// line, and transport errors map to VanaChatErrorKind.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_logging/application/meal_ai_service.dart';
import 'package:mealvana_endurance/features/meal_planning/application/meal_plan_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/application/vana_chat_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/data/user_memory_repository.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_action_client.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_chat_repository.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_exceptions.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_plan.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/memory_kind.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/ui_action.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/user_memory.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_conversation_kind.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_message.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_part.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_stream_event.dart';

import '../domain/fixture_helpers.dart';
import '../helpers/container.dart';

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
  }) async {
    calls.add({
      'message': message,
      'conversationId': conversationId,
      'opener': opener,
      'anchorDate': anchorDate,
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

  setUp(() {
    repo = _FakeChatRepo();
    planController = _RecordingPlanController();
    memoryRepo = _FakeMemoryRepo();
    actions = _FakeActionClient();
    mealAi = _FakeMealAiService();
  });

  ({VanaChatController notifier, List<VanaChatState> seen}) make({
    VanaConversationKind kind = VanaConversationKind.mealPlanning,
    String? conversationId,
  }) {
    final container = testContainer([
      ...baseOverrides(),
      vanaChatRepositoryProvider.overrideWithValue(repo),
      mealPlanControllerProvider.overrideWith(() => planController),
      userMemoryRepositoryProvider.overrideWithValue(memoryRepo),
      vanaActionClientProvider.overrideWithValue(actions),
      mealAiServiceProvider.overrideWithValue(mealAi),
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
      // The status line was visible mid-stream.
      expect(seen.any((st) => st.statusTool == 'suggestMeals'), isTrue);
    },
  );

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
    test('refreshDraft re-asks get_plan and mirrors the returned draft', () async {
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
    });

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

    test('usePantry records the items then sends the message', () async {
      repo.events = const [VanaTextEvent('Using those.'), VanaDoneEvent()];
      final (:notifier, seen: _) = make(conversationId: 'conv-1');
      await notifier.future;

      await notifier.usePantry([
        'eggs',
        'rice',
      ], message: 'I have eggs, rice on hand — use these');

      final set = actions.ran.single as SetPantryAction;
      expect(set.conversationId, 'conv-1');
      expect(set.items, ['eggs', 'rice']);
      expect(
        repo.calls.single['message'],
        'I have eggs, rice on hand — use these',
      );
      expect(notifier.state.value!.messages.last.content, 'Using those.');
    });

    test('usePantry: a failed set_pantry sends nothing', () async {
      actions.failByType['set_pantry'] = const VanaRateLimitedException(
        retryAfterSeconds: 5,
      );
      final (:notifier, seen: _) = make(conversationId: 'conv-1');
      await notifier.future;

      await notifier.usePantry(['eggs'], message: 'use these');

      expect(repo.calls, isEmpty);
      expect(notifier.state.value!.error, VanaChatErrorKind.rateLimited);
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
}
