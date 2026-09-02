import 'dart:async';


import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/providers/user_id_provider.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/logging_service.dart';
import '../../ai_credits/domain/insufficient_credits_exception.dart';
import '../data/user_memory_repository.dart';
import '../data/vana_chat_repository.dart';
import '../data/vana_exceptions.dart';
import '../domain/meal_plan.dart';
import '../domain/vana_conversation_kind.dart';
import '../domain/vana_message.dart';
import '../domain/vana_part.dart';
import '../domain/vana_stream_event.dart';
import '../domain/week_start.dart';
import 'meal_plan_controller.dart';

part 'vana_chat_controller.g.dart';

/// Why the last turn failed — the presentation layer maps each to copy.
enum VanaChatErrorKind {
  offline,
  unauthenticated,
  rateLimited,
  insufficientCredits,
  proRequired,
  server,
  unknown,
}

/// Immutable state of one Vana conversation screen.
class VanaChatState {
  const VanaChatState({
    required this.kind,
    this.conversationId,
    this.messages = const [],
    this.isStreaming = false,
    this.statusTool,
    this.draftPlan,
    this.error,
    this.retryAfterSeconds,
    this.historyLoaded = false,
  });

  final VanaConversationKind kind;

  /// Null until the first turn (the server creates the conversation).
  final String? conversationId;

  /// Persisted turns plus the in-flight assistant message (always last while
  /// [isStreaming]).
  final List<VanaMessage> messages;
  final bool isStreaming;

  /// The tool the model is currently running (`status` line) — drives the
  /// "Finding options…" line. Null when idle.
  final String? statusTool;

  /// The latest `batch` plan folded from this conversation — the plan bar.
  /// Also written into Drift through [MealPlanController].
  final MealPlan? draftPlan;

  /// Last failure; the screen shows it and calls [VanaChatController.clearError].
  final VanaChatErrorKind? error;

  /// For [VanaChatErrorKind.rateLimited]: "Give me N seconds".
  final int? retryAfterSeconds;

  /// True once history (or "no history") has been resolved.
  final bool historyLoaded;

  /// 403 `pro_required` — the screen routes to `/pro`.
  bool get proRequired => error == VanaChatErrorKind.proRequired;

  bool get isPlanning => kind == VanaConversationKind.mealPlanning;

  VanaChatState copyWith({
    String? conversationId,
    List<VanaMessage>? messages,
    bool? isStreaming,
    String? statusTool,
    bool clearStatus = false,
    MealPlan? draftPlan,
    VanaChatErrorKind? error,
    int? retryAfterSeconds,
    bool clearError = false,
    bool? historyLoaded,
  }) => VanaChatState(
    kind: kind,
    conversationId: conversationId ?? this.conversationId,
    messages: messages ?? this.messages,
    isStreaming: isStreaming ?? this.isStreaming,
    statusTool: clearStatus ? null : (statusTool ?? this.statusTool),
    draftPlan: draftPlan ?? this.draftPlan,
    error: clearError ? null : (error ?? this.error),
    retryAfterSeconds: clearError
        ? null
        : (retryAfterSeconds ?? this.retryAfterSeconds),
    historyLoaded: historyLoaded ?? this.historyLoaded,
  );
}

/// One Vana conversation (planning or general), keyed by kind + id.
///
/// Streams turns from [VanaChatRepository], accumulates text and parts into
/// the last message, folds `batch` parts into [MealPlanController] (they
/// are never rendered inline) and `memory_saved` parts into the memory
/// repository, and maps transport errors to [VanaChatErrorKind]. Chip taps
/// are plain user messages ([tapChip]).
@riverpod
class VanaChatController extends _$VanaChatController {
  VanaChatRepository get _repo => ref.read(vanaChatRepositoryProvider);
  AppLogger get _logger => ref.read(appExternalDepsProvider).logger;

  static const _context = 'VANA_CHAT_CONTROLLER';

  @override
  FutureOr<VanaChatState> build({
    required VanaConversationKind kind,
    String? conversationId,
  }) async {
    if (conversationId == null || conversationId.isEmpty) {
      return VanaChatState(kind: kind, historyLoaded: true);
    }
    try {
      final messages = await _repo.fetchMessages(conversationId);
      MealPlan? latestPlan;
      for (final m in messages) {
        for (final p in m.parts) {
          if (p is VanaBatchPart) latestPlan = p.plan;
        }
      }
      return VanaChatState(
        kind: kind,
        conversationId: conversationId,
        messages: _stripBatchParts(messages),
        draftPlan: latestPlan,
        historyLoaded: true,
      );
    } catch (e, st) {
      _logger.error(
        'Failed to load Vana history',
        context: _context,
        error: e,
        stackTrace: st,
        data: {'conversationId': conversationId},
      );
      return VanaChatState(
        kind: kind,
        conversationId: conversationId,
        historyLoaded: true,
        error: _errorKind(e),
      );
    }
  }

  // ── Turns ──────────────────────────────────────────────────────────────────

  /// Vana's first turn: the scripted planning opener (frame + three
  /// dinners) or the general greeting. Creates the conversation server-side
  /// when there is none. Failures leave the empty state (an opener is a
  /// nicety, except `pro_required`, which is surfaced).
  Future<void> loadOpener({String? anchorDate}) async {
    // The opener can be requested in the screen's first post-frame callback,
    // before this notifier's async build() has resolved — writes made before
    // initialization completes are clobbered by the initializer's return.
    await future;
    final current = state.value ?? VanaChatState(kind: kind);
    if (current.isStreaming || current.messages.isNotEmpty) return;
    await _turn(current, message: null, opener: true, anchorDate: anchorDate);
  }

  /// Send a user message.
  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final current = state.value ?? VanaChatState(kind: kind);
    if (current.isStreaming) return;
    await _turn(current, message: trimmed, opener: false);
  }

  /// Chip taps send the chip label as the next user message (02 §6).
  Future<void> tapChip(String label) => send(label);

  void clearError() {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(clearError: true));
  }

  Future<void> _turn(
    VanaChatState before, {
    required String? message,
    required bool opener,
    String? anchorDate,
  }) async {
    final now = DateTime.now();
    final convId = before.conversationId ?? '';
    final optimistic = <VanaMessage>[
      ...before.messages,
      if (message != null)
        VanaMessage(
          id: 'optimistic_${now.millisecondsSinceEpoch}',
          conversationId: convId,
          role: VanaMessageRole.user,
          content: message,
          createdAt: now,
        ),
      VanaMessage(
        id: 'streaming_${now.millisecondsSinceEpoch}',
        conversationId: convId,
        role: VanaMessageRole.assistant,
        content: '',
        createdAt: now,
      ),
    ];
    state = AsyncData(
      before.copyWith(
        messages: optimistic,
        isStreaming: true,
        clearStatus: true,
        clearError: true,
      ),
    );

    try {
      final response = await _repo.streamChat(
        message: message,
        conversationId: before.conversationId,
        kind: kind,
        opener: opener,
        anchorDate:
            anchorDate ?? (opener && before.isPlanning ? todayIso() : null),
      );
      final resolvedId = response.conversationId.isNotEmpty
          ? response.conversationId
          : before.conversationId;

      await for (final event in response.events) {
        if (!ref.mounted) return;
        final current = state.value;
        if (current == null) break;
        final next = await _apply(current, event, resolvedId);
        if (!ref.mounted) return;
        state = AsyncData(next);
        if (event is VanaDoneEvent) break;
      }

      if (!ref.mounted) return;
      final finished = state.value ?? before;
      final last = finished.messages.isEmpty ? null : finished.messages.last;
      final emptyOpener =
          opener &&
          last != null &&
          !last.isUser &&
          last.content.isEmpty &&
          last.parts.isEmpty;
      state = AsyncData(
        finished.copyWith(
          conversationId: resolvedId,
          messages: emptyOpener
              ? finished.messages.sublist(0, finished.messages.length - 1)
              : finished.messages,
          isStreaming: false,
          clearStatus: true,
        ),
      );
    } catch (e, st) {
      if (!ref.mounted) return;
      _logger.error(
        'Vana turn failed',
        context: _context,
        error: e,
        stackTrace: st,
        data: {'kind': kind.wire, 'opener': opener},
      );
      // Roll back the optimistic pair; keep everything that was persisted.
      state = AsyncData(
        before.copyWith(
          isStreaming: false,
          clearStatus: true,
          error: _errorKind(e),
          retryAfterSeconds: e is VanaRateLimitedException
              ? e.retryAfterSeconds
              : null,
        ),
      );
    }
  }

  Future<VanaChatState> _apply(
    VanaChatState current,
    VanaStreamEvent event,
    String? conversationId,
  ) async {
    final messages = [...current.messages];
    final lastIndex = messages.length - 1;
    switch (event) {
      case VanaTextEvent(:final delta):
        if (lastIndex >= 0) {
          messages[lastIndex] = messages[lastIndex].appendText(delta);
        }
        return current.copyWith(
          conversationId: conversationId,
          messages: messages,
          clearStatus: true,
        );
      case VanaUiEvent(:final part):
        if (part is VanaBatchPart) {
          await _foldPlan(part.plan);
          return current.copyWith(
            conversationId: conversationId,
            draftPlan: part.plan,
            clearStatus: true,
          );
        }
        if (part is VanaMemorySavedPart) {
          await _foldMemory(part);
        }
        if (lastIndex >= 0) {
          messages[lastIndex] = messages[lastIndex].appendPart(part);
        }
        return current.copyWith(
          conversationId: conversationId,
          messages: messages,
          clearStatus: true,
        );
      case VanaStatusEvent(:final tool):
        return current.copyWith(
          conversationId: conversationId,
          statusTool: tool,
        );
      case VanaErrorEvent(:final message):
        _logger.error('Vana stream error: $message', context: _context);
        return current.copyWith(
          conversationId: conversationId,
          error: VanaChatErrorKind.server,
          clearStatus: true,
        );
      case VanaDoneEvent():
        return current.copyWith(
          conversationId: conversationId,
          clearStatus: true,
        );
    }
  }

  Future<void> _foldPlan(MealPlan plan) async {
    try {
      await ref.read(mealPlanControllerProvider.notifier).applyServerPlan(plan);
    } catch (e, st) {
      _logger.error(
        'Failed to fold batch part into the plan',
        context: _context,
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> _foldMemory(VanaMemorySavedPart part) async {
    try {
      final userId = await ref.read(userIdProvider.future);
      await ref
          .read(userMemoryRepositoryProvider)
          .applyServerMemory(part.memory, userId: userId);
    } catch (e) {
      _logger.warning(
        'Failed to store memory_saved part locally',
        context: _context,
        error: e,
      );
    }
  }

  /// `batch` parts are plan-bar state, never bubbles (02 §3).
  static List<VanaMessage> _stripBatchParts(List<VanaMessage> messages) => [
    for (final m in messages)
      m.parts.any((p) => p is VanaBatchPart)
          ? m.copyWith(
              parts: List.unmodifiable(
                m.parts.where((p) => p is! VanaBatchPart),
              ),
            )
          : m,
  ];

  static VanaChatErrorKind _errorKind(Object e) => switch (e) {
    VanaOfflineException() => VanaChatErrorKind.offline,
    VanaUnauthenticatedException() => VanaChatErrorKind.unauthenticated,
    VanaRateLimitedException() => VanaChatErrorKind.rateLimited,
    ProRequiredException() => VanaChatErrorKind.proRequired,
    InsufficientCreditsException() => VanaChatErrorKind.insufficientCredits,
    VanaServerException() => VanaChatErrorKind.server,
    _ => VanaChatErrorKind.unknown,
  };
}
