/// VanaChatController: streaming turns fold into messages, `batch` parts
/// go to the plan controller (never inline), `status` drives the status
/// line, and transport errors map to VanaChatErrorKind.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_planning/application/meal_plan_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/application/vana_chat_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/data/user_memory_repository.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_chat_repository.dart';
import 'package:mealvana_endurance/features/meal_planning/data/vana_exceptions.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_plan.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/memory_kind.dart';
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

  setUp(() {
    repo = _FakeChatRepo();
    planController = _RecordingPlanController();
    memoryRepo = _FakeMemoryRepo();
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
