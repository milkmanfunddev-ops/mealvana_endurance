import 'dart:async';
import 'dart:typed_data';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/providers/user_id_provider.dart';
import '../../../shared/services/app_external_deps.dart';
import '../../../shared/services/logging_service.dart';
import '../../ai_credits/domain/insufficient_credits_exception.dart';
import '../../content/application/content_service.dart';
import '../../feedback/data/wiredash_feedback_filer.dart';
import '../../feedback/domain/typed_feedback.dart';
import '../../meal_logging/application/meal_ai_service.dart';
import '../data/user_memory_repository.dart';
import '../data/vana_action_client.dart';
import '../data/vana_chat_repository.dart';
import '../data/vana_exceptions.dart';
import '../domain/meal_plan.dart';
import '../domain/ui_action.dart';
import '../domain/vana_input_mode.dart';
import '../domain/vana_conversation_kind.dart';
import '../domain/vana_fixed_chip.dart';
import '../domain/vana_message.dart';
import '../domain/vana_moment.dart';
import '../domain/vana_part.dart';
import '../domain/vana_stream_event.dart';
import '../domain/week_start.dart';
import 'meal_plan_controller.dart';
import 'vana_situation_controller.dart';
import 'vana_write_refetcher.dart';
import 'vana_ambient_conversation_controller.dart';

part 'vana_chat_controller.g.dart';

/// Why the last turn failed — the presentation layer maps each to copy.
enum VanaChatErrorKind {
  offline,
  unauthenticated,
  rateLimited,
  insufficientCredits,
  proRequired,

  /// The AI Gateway refused US — our key's monthly budget hard-stopped, or the
  /// key is gone (mp-437). Distinct from [insufficientCredits] on purpose: the
  /// athlete's own budget is fine, so the top-up sheet must never appear.
  aiUnavailable,
  server,
  unknown,
}

/// A read the screen could not make, which it shows with a Retry
/// ([VanaChatController.retryFailedRead]) instead of an empty chat
/// (testing-wave 129, Findings 88-011, 88-012).
enum VanaChatFailedRead {
  /// The conversation's history did not load: never the empty new-plan
  /// screen, which would let the athlete write into what looks like a new
  /// plan.
  history,

  /// Vana's first turn did not come.
  opener,
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
    this.failedRead,
    this.unsentMessage,
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

  /// The read that failed and waits for a Retry, with [error] saying why.
  /// Survives [VanaChatController.clearError]; the next turn or the Retry
  /// clears it.
  final VanaChatFailedRead? failedRead;

  /// The athlete's message whose turn failed and was rolled back: the Ask
  /// Vana sheet keeps it on screen with the error line, and Retry sends it
  /// again (88-022). Cleared when the next turn starts.
  final String? unsentMessage;

  /// 403 `pro_required` — the screen warns and refreshes the subscription
  /// status; the router moves onto the paywall when the SDK agrees.
  bool get proRequired => error == VanaChatErrorKind.proRequired;

  bool get isPlanning => kind == VanaConversationKind.mealPlanning;

  VanaChatState copyWith({
    String? conversationId,
    List<VanaMessage>? messages,
    bool? isStreaming,
    String? statusTool,
    bool clearStatus = false,
    MealPlan? draftPlan,
    bool clearDraftPlan = false,
    VanaChatErrorKind? error,
    int? retryAfterSeconds,
    bool clearError = false,
    bool? historyLoaded,
    VanaChatFailedRead? failedRead,
    bool clearFailedRead = false,
    String? unsentMessage,
    bool clearUnsent = false,
  }) => VanaChatState(
    kind: kind,
    conversationId: conversationId ?? this.conversationId,
    messages: messages ?? this.messages,
    isStreaming: isStreaming ?? this.isStreaming,
    statusTool: clearStatus ? null : (statusTool ?? this.statusTool),
    draftPlan: clearDraftPlan ? null : (draftPlan ?? this.draftPlan),
    error: clearError ? null : (error ?? this.error),
    retryAfterSeconds: clearError
        ? null
        : (retryAfterSeconds ?? this.retryAfterSeconds),
    historyLoaded: historyLoaded ?? this.historyLoaded,
    failedRead: clearFailedRead ? null : (failedRead ?? this.failedRead),
    unsentMessage: clearUnsent ? null : (unsentMessage ?? this.unsentMessage),
  );
}

/// One Vana conversation (planning or general), keyed by kind + id.
///
/// Streams turns from [VanaChatRepository], accumulates text and parts into
/// the last message, folds `batch` parts into [MealPlanController] (they
/// are never rendered inline) and `memory_saved` parts into the memory
/// repository, and maps transport errors to [VanaChatErrorKind]. A chip tap
/// is a plain user message ([tapChip]), except a fixed-label chip, which
/// acts at once on the no-model endpoint ([actAtOnce], mp-464).
@riverpod
class VanaChatController extends _$VanaChatController {
  VanaChatRepository get _repo => ref.read(vanaChatRepositoryProvider);
  VanaActionClient get _actions => ref.read(vanaActionClientProvider);
  AppLogger get _logger => ref.read(appExternalDepsProvider).logger;
  VanaFixedChipResolver get _fixedChips =>
      VanaFixedChipResolver(ref.read(contentServiceProvider).getValue);

  /// The client-raised `status` tool name while a fridge photo is being
  /// read (`VanaStatusCopy` maps it to copy).
  static const pantryPhotoTool = 'pantryPhoto';

  static const _context = 'VANA_CHAT_CONTROLLER';

  /// The last opener asked for, so a Retry after a failed one asks for the
  /// same one. Reset in [build]: Riverpod reuses the notifier across an
  /// invalidate.
  ({String? anchorDate, VanaMoment? moment, bool newPlan})? _lastOpener;

  @override
  FutureOr<VanaChatState> build({
    required VanaConversationKind kind,
    String? conversationId,
  }) async {
    _lastOpener = null;
    if (conversationId == null || isNewVanaConversationKey(conversationId)) {
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
      // Picks land through vana-action, not the transcript, so the latest
      // batch part can be stale or absent: the conversation's own draft is
      // the source of truth. Offline → keep the transcript's view.
      latestPlan = await _loadDraft(conversationId) ?? latestPlan;
      return VanaChatState(
        kind: kind,
        conversationId: conversationId,
        messages: _drawable(_stripBatchParts(messages)),
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
        failedRead: VanaChatFailedRead.history,
      );
    }
  }

  /// The Retry under a failed read: the history is read again (the whole
  /// build), or the same opener is asked for again. A no-op when nothing
  /// failed, or while a turn is running (a second tap lands here).
  Future<void> retryFailedRead() async {
    final current = state.value;
    if (current == null || current.isStreaming || state.isLoading) return;
    switch (current.failedRead) {
      case VanaChatFailedRead.history:
        ref.invalidateSelf();
        await future;
      case VanaChatFailedRead.opener:
        final opener = _lastOpener;
        state = AsyncData(
          current.copyWith(clearError: true, clearFailedRead: true),
        );
        await loadOpener(
          anchorDate: opener?.anchorDate,
          moment: opener?.moment,
          newPlan: opener?.newPlan ?? false,
        );
      case null:
        return;
    }
  }

  /// The conversation's own draft (`get_plan` scoped to this conversation;
  /// null when nothing was ever picked or the server is unreachable — the
  /// caller keeps what it has).
  Future<MealPlan?> _loadDraft(String conversationId) async {
    try {
      final draft = await _actions.run(
        GetPlanAction(conversationId: conversationId),
      );
      return draft.plan;
    } catch (e) {
      _logger.warning(
        'conversation draft not loaded — keeping the current view',
        context: _context,
        error: e,
      );
      return null;
    }
  }

  /// Re-read this conversation's draft from the server and mirror it into
  /// the chat state — for writes that happened on another screen (the
  /// "Browse meals" screen picks straight into the draft, then pops back).
  /// A conversation with no id yet has nothing to reload.
  Future<void> refreshDraft() async {
    await future;
    final id = state.value?.conversationId;
    if (id == null || id.isEmpty) return;
    final plan = await _loadDraft(id);
    if (!ref.mounted || plan == null) return;
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(draftPlan: plan));
  }

  // ── Turns ──────────────────────────────────────────────────────────────────

  /// Vana's first turn: the scripted planning opener (frame + three
  /// dinners) or the general greeting. Creates the conversation server-side
  /// when there is none. Failures leave the empty state (an opener is a
  /// nicety, except `pro_required`, which is surfaced).
  ///
  /// With a [moment] it is the moment's opener (vana-moment spec VM-1), and
  /// it lands even on a conversation that already has turns: the moment
  /// starts a new exchange there.
  ///
  /// [newPlan] is the Plan tab's "New meal plan": the server gives the
  /// plan-building opener whatever the week already holds, and never asks
  /// whether the athlete meant to log, swap or adjust the old plan.
  Future<void> loadOpener({
    String? anchorDate,
    VanaMoment? moment,
    bool newPlan = false,
  }) async {
    // The opener can be requested in the screen's first post-frame callback,
    // before this notifier's async build() has resolved — writes made before
    // initialization completes are clobbered by the initializer's return.
    await future;
    final current = state.value ?? VanaChatState(kind: kind);
    if (current.isStreaming) return;
    if (moment == null && current.messages.isNotEmpty) return;
    _lastOpener = (anchorDate: anchorDate, moment: moment, newPlan: newPlan);
    await _turn(
      current,
      message: null,
      opener: true,
      anchorDate: anchorDate,
      moment: moment,
      newPlan: newPlan,
    );
  }

  /// Send a user message.
  ///
  /// [inputMode] is what the athlete did to send it (mp-464 clause 7): it
  /// rides the request and is recorded on the call row, and nothing about the
  /// turn depends on it. It defaults to [VanaInputMode.typed] because the
  /// composer is the only caller that does not say — a chip goes through
  /// [tapChip] or [usePantry].
  Future<void> send(
    String text, {
    VanaInputMode inputMode = VanaInputMode.typed,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final current = state.value ?? VanaChatState(kind: kind);
    if (current.isStreaming) return;
    await _turn(current, message: trimmed, opener: false, inputMode: inputMode);
  }

  /// The chip a tapped [label] resolves to when it acts at once (mp-464
  /// clause 1), or null when the tap is Vana's: a chip she named herself,
  /// "Adjust", "Different protein". The screen reads it to know whether the
  /// tap also navigates ([VanaFixedChip.navigatesTo]).
  VanaFixedChip? fixedChipFor(String label) => _fixedChips.match(label);

  /// The picker chip a tapped [label] is ("Other options", the two filters,
  /// "I like these", `Next: <type>`), or null (ticket 12).
  VanaPickerChipTap? pickerChipFor(String label) => _fixedChips.picker(label);

  /// Whether a tap on [label] goes to the no-model endpoint first: a fixed
  /// chip or a picker chip. The screen spends the strip only for the rest.
  bool actsAtOnce(String label) =>
      fixedChipFor(label) != null || pickerChipFor(label) != null;

  /// A chip tap. A fixed-label chip runs its step at once with no model turn
  /// ([actAtOnce]); so does a picker chip, which brings the next picker
  /// unless its next step is Vana's. Every other label is the next user
  /// message (02 §6), marked as a tap so the log can tell it from typed turns.
  Future<void> tapChip(String label) async {
    final chip = fixedChipFor(label);
    if (chip != null) {
      return actAtOnce(
        label: label,
        statusTool: chip.statusTool,
        action: (conversationId) =>
            chip.action(conversationId: conversationId, label: label),
      );
    }
    final picker = pickerChipFor(label);
    if (picker != null) {
      return actAtOnce(
        label: label,
        statusTool: VanaPickerChip.statusTool,
        action: (conversationId) =>
            picker.action(conversationId: conversationId, label: label),
      );
    }
    return send(label, inputMode: VanaInputMode.tap);
  }

  /// Run a fixed step with no model turn (mp-464 clauses 3 to 5, ticket 11).
  ///
  /// [label] is what the athlete tapped and becomes their bubble; the action
  /// carries it as `chip`, so the server stores the tap and what it produced
  /// in the conversation (Vana reads both on her next turn) and logs a tap
  /// that drew nothing. The result lands as an assistant turn with no text
  /// and no line in her voice: `batch` parts fold into the plan bar,
  /// `memory_saved` into the memory store, and whatever is left to draw is
  /// the turn. A result with nothing to draw is no turn at all. While it
  /// runs the transcript shows the [statusTool]'s status line. A
  /// conversation with no id yet is created first, as the fridge photo does.
  ///
  /// A failure rolls the tap back: nothing was stored, so nothing stays on
  /// screen, and the error reaches the screen the way a turn's does.
  ///
  /// A result that hands the tap back (`toVana`: a picker chip whose next
  /// step is a question or the wrap-up, ticket 12) ran and stored nothing:
  /// the tap is taken back off the screen and sent to Vana as a tapped
  /// message instead.
  Future<void> actAtOnce({
    required String label,
    required String statusTool,
    required UiAction Function(String conversationId) action,
  }) async {
    final current = state.value ?? VanaChatState(kind: kind);
    if (current.isStreaming) return;

    final now = DateTime.now();
    final tapId = 'tap_${now.millisecondsSinceEpoch}';
    final placeholderId = 'acting_${now.millisecondsSinceEpoch}';
    var conversationId = current.conversationId;
    state = AsyncData(
      current.copyWith(
        messages: [
          ...current.messages,
          VanaMessage(
            id: tapId,
            conversationId: conversationId ?? '',
            role: VanaMessageRole.user,
            content: label,
            createdAt: now,
          ),
          VanaMessage(
            id: placeholderId,
            conversationId: conversationId ?? '',
            role: VanaMessageRole.assistant,
            content: '',
            createdAt: now,
          ),
        ],
        isStreaming: true,
        statusTool: statusTool,
        clearError: true,
      ),
    );

    try {
      if (conversationId == null || conversationId.isEmpty) {
        conversationId = await _repo.createConversation(kind);
      }
      final result = await _actions.run(action(conversationId));
      if (!ref.mounted) return;
      if (result.toVana) {
        _logger.info(
          'chip "$label" → Vana',
          context: _context,
          data: {'conversationId': conversationId},
        );
        return _turn(
          current.copyWith(conversationId: conversationId),
          message: label,
          opener: false,
          inputMode: VanaInputMode.tap,
        );
      }
      MealPlan? plan;
      final drawn = <VanaPart>[];
      for (final part in result.parts) {
        if (part is VanaBatchPart) {
          plan = part.plan;
          continue;
        }
        if (part is VanaMemorySavedPart) await _foldMemory(part);
        drawn.add(part);
      }
      if (plan != null) await _foldPlan(plan);
      if (!ref.mounted) return;
      final latest = state.value ?? current;
      final settled = conversationId;
      state = AsyncData(
        latest.copyWith(
          conversationId: settled,
          messages: [
            for (final m in latest.messages)
              if (m.id == tapId)
                m.copyWith(
                  id: result.tapMessageId ?? tapId,
                  conversationId: settled,
                )
              else if (m.id != placeholderId)
                m,
            if (drawn.isNotEmpty)
              VanaMessage(
                id: result.messageId ?? placeholderId,
                conversationId: settled,
                role: VanaMessageRole.assistant,
                content: '',
                parts: drawn,
                createdAt: DateTime.now(),
              ),
          ],
          isStreaming: false,
          clearStatus: true,
          draftPlan: plan,
        ),
      );
      _logger.info(
        'chip "$label" → ${result.parts.map((p) => p.kind).join(',')}',
        context: _context,
        data: {'conversationId': settled, 'stored': result.messageId != null},
      );
    } catch (e, st) {
      if (!ref.mounted) return;
      _logger.error(
        'Vana chip "$label" failed',
        context: _context,
        error: e,
        stackTrace: st,
      );
      // Roll the tap back; keep the conversation id if one was made.
      state = AsyncData(
        current.copyWith(
          conversationId: conversationId,
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

  void clearError() {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(clearError: true));
  }

  // ── Edit-and-rewind (plan §5 Phase 6.1) ────────────────────────────────────

  /// Re-send an edited athlete turn: `rewind` deletes [messageId] and
  /// everything after it server-side and restores the draft plan to its
  /// snapshot after the previous assistant turn; the returned `batch` (if
  /// any) folds into the plan controller, the local transcript is cut at
  /// the same point, and [text] then goes out as a normal message.
  ///
  /// A message id the transcript does not hold (already rewound, or an
  /// optimistic id that never persisted) degrades to a plain [send].
  Future<void> rewindAndSend(String messageId, String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final current = state.value ?? VanaChatState(kind: kind);
    if (current.isStreaming) return;

    final conversationId = current.conversationId;
    final index = current.messages.indexWhere((m) => m.id == messageId);
    if (conversationId == null || conversationId.isEmpty || index < 0) {
      await _turn(
        current,
        message: trimmed,
        opener: false,
        inputMode: VanaInputMode.typed,
      );
      return;
    }

    // Block a second send while the rewind is in flight.
    state = AsyncData(
      current.copyWith(isStreaming: true, clearStatus: true, clearError: true),
    );
    try {
      final result = await _actions.run(
        RewindAction(conversationId: conversationId, messageId: messageId),
      );
      if (!ref.mounted) return;
      final plan = result.plan;
      if (plan != null) await _foldPlan(plan);
      if (!ref.mounted) return;
      _logger.info(
        'rewind → removed ${result.removed ?? '?'} message(s)',
        context: _context,
        data: {'conversationId': conversationId, 'messageId': messageId},
      );
      // No batch back means the snapshot had no plan: the local draft is
      // cleared; Drift keeps its row until the next `batch` overwrites it.
      final rewound = current.copyWith(
        messages: current.messages.sublist(0, index),
        isStreaming: false,
        draftPlan: plan,
        clearDraftPlan: plan == null,
        clearStatus: true,
        clearError: true,
      );
      state = AsyncData(rewound);
      await _turn(
        rewound,
        message: trimmed,
        opener: false,
        inputMode: VanaInputMode.typed,
      );
    } catch (e, st) {
      if (!ref.mounted) return;
      _logger.error(
        'Vana rewind failed',
        context: _context,
        error: e,
        stackTrace: st,
        data: {'conversationId': conversationId, 'messageId': messageId},
      );
      state = AsyncData(
        current.copyWith(
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

  // ── Ingredients on hand (plan §5 Phase 7.3) ────────────────────────────────

  /// "Snap my fridge": upload [bytes] to the `meal-photos` bucket (the
  /// meal-logging upload path) and run `pantry_photo`. The server persists
  /// the returned `pantry` part as an assistant message; the same message
  /// (id = `messageId`) is appended locally. While it runs the transcript
  /// shows a placeholder turn with the [pantryPhotoTool] status line.
  /// Creates the conversation first when there is none yet.
  Future<void> sendPantryPhoto(
    Uint8List bytes, {
    String extension = 'jpg',
  }) async {
    final current = state.value ?? VanaChatState(kind: kind);
    if (current.isStreaming) return;

    final now = DateTime.now();
    final placeholderId = 'pantry_${now.millisecondsSinceEpoch}';
    var conversationId = current.conversationId;
    state = AsyncData(
      current.copyWith(
        messages: [
          ...current.messages,
          VanaMessage(
            id: placeholderId,
            conversationId: conversationId ?? '',
            role: VanaMessageRole.assistant,
            content: '',
            createdAt: now,
          ),
        ],
        isStreaming: true,
        statusTool: pantryPhotoTool,
        clearError: true,
      ),
    );

    try {
      if (conversationId == null || conversationId.isEmpty) {
        conversationId = await _repo.createConversation(kind);
      }
      final photoPath = await ref
          .read(mealAiServiceProvider)
          .uploadPhotoBytes(bytes, extension: extension);
      final result = await _actions.run(
        PantryPhotoAction(conversationId: conversationId, photoPath: photoPath),
      );
      if (!ref.mounted) return;
      final latest = state.value ?? current;
      state = AsyncData(
        latest.copyWith(
          conversationId: conversationId,
          messages: [
            for (final m in latest.messages)
              if (m.id != placeholderId) m,
            VanaMessage(
              id: result.messageId ?? placeholderId,
              conversationId: conversationId,
              role: VanaMessageRole.assistant,
              content: '',
              parts: result.parts,
              createdAt: DateTime.now(),
            ),
          ],
          isStreaming: false,
          clearStatus: true,
        ),
      );
    } catch (e, st) {
      if (!ref.mounted) return;
      _logger.error(
        'Vana pantry photo failed',
        context: _context,
        error: e,
        stackTrace: st,
      );
      // Roll back the placeholder; keep the conversation id if one was made.
      state = AsyncData(
        current.copyWith(
          conversationId: conversationId,
          isStreaming: false,
          clearStatus: true,
          error: _errorKind(e),
        ),
      );
    }
  }

  /// "Use these" on a `pantry` card: `set_pantry` records [items] on the
  /// conversation at once, with no model turn (mp-464 clause 1). [message]
  /// is the screen's rendered "I have … on hand" line: it becomes the
  /// athlete's bubble and the stored turn, so Vana plans with the items the
  /// next time a turn reaches her.
  Future<void> usePantry(List<String> items, {required String message}) =>
      actAtOnce(
        label: message,
        statusTool: 'setPantry',
        action: (conversationId) => SetPantryAction(
          conversationId: conversationId,
          items: items,
          chip: message,
        ),
      );

  Future<void> _turn(
    VanaChatState before, {
    required String? message,
    required bool opener,
    String? anchorDate,
    VanaMoment? moment,
    bool newPlan = false,
    VanaInputMode? inputMode,
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
        clearFailedRead: true,
        clearUnsent: true,
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
        // Whatever screen is underneath — read at send time, never stored.
        situation: ref.read(vanaSituationControllerProvider.notifier).current(),
        moment: moment,
        newPlan: newPlan,
        inputMode: inputMode,
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
      // An empty reply is dropped after an opener, and after a stream that
      // ended on an error line (a gateway refusal, mp-437): otherwise the
      // empty bubble would sit in the thread under the error's snackbar.
      final emptyReply =
          (opener || finished.error != null) &&
          last != null &&
          !last.isUser &&
          last.content.isEmpty &&
          last.parts.isEmpty;
      state = AsyncData(
        finished.copyWith(
          conversationId: resolvedId,
          messages: emptyReply
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
      // A failed opener waits for its Retry; a failed message is kept as
      // unsent so the athlete never loses what they wrote.
      final errorKind = _errorKind(e);
      // A spent budget or a lapsed Pro has its own path on the screen (the
      // top-up sheet, the paywall); a Retry line would only hit it again.
      final retryable = opener &&
          errorKind != VanaChatErrorKind.insufficientCredits &&
          errorKind != VanaChatErrorKind.proRequired;
      state = AsyncData(
        before.copyWith(
          isStreaming: false,
          clearStatus: true,
          error: errorKind,
          retryAfterSeconds: e is VanaRateLimitedException
              ? e.retryAfterSeconds
              : null,
          failedRead: retryable ? VanaChatFailedRead.opener : null,
          clearFailedRead: !retryable,
          unsentMessage: message,
          clearUnsent: message == null,
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
        if (part is VanaFeedbackSavedPart) {
          await _fileFeedback(part, conversationId);
        }
        if (part is VanaReceiptPart) {
          // Never awaited: the card lands now, the store catches up behind it.
          unawaited(_refetchAfter(part));
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
      case VanaErrorEvent(:final message, :final code):
        _logger.error(
          'Vana stream error: $message${code == null ? '' : ' ($code)'}',
          context: _context,
        );
        // The gateway refusing us mid-stream is our fault, not the athlete's
        // wallet: its own kind, so the screen never raises the top-up sheet.
        return current.copyWith(
          conversationId: conversationId,
          error: code == VanaUnavailableException.code
              ? VanaChatErrorKind.aiUnavailable
              : VanaChatErrorKind.server,
          clearStatus: true,
        );
      case VanaDoneEvent():
        return current.copyWith(
          conversationId: conversationId,
          clearStatus: true,
        );
    }
  }

  /// A plan write that happened outside the stream (a tap on a picker card,
  /// the plan bar's steppers/remove/swap) returned this conversation's draft:
  /// mirror it into the chat state so the plan bar shows it immediately.
  void applyDraftPlan(MealPlan? plan) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(draftPlan: plan, clearDraftPlan: plan == null),
    );
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

  /// A `feedback_saved` part is the server's word that the row landed in
  /// `user_feedback`; the device then files the same words into Wiredash so
  /// typed feedback sits in the inbox with shaken reports (mp-245 clause 6,
  /// ticket 26). Filing never touches the turn: the acknowledgement row is
  /// already the reply, and a Wiredash failure is only logged.
  Future<void> _fileFeedback(
    VanaFeedbackSavedPart part,
    String? conversationId,
  ) async {
    try {
      await ref
          .read(wiredashFeedbackFilerProvider)
          .file(
            TypedFeedback(
              message: part.message,
              sentiment: part.sentiment.name,
              about: part.about.name,
              conversationId: conversationId,
            ),
          );
    } catch (e) {
      _logger.warning(
        'Failed to file feedback_saved part to Wiredash',
        context: _context,
        error: e,
      );
    }
  }

  /// The Undo button on a receipt card (playtest §10): runs the receipt's
  /// own `undo_receipt` action, then refetches whatever the answering
  /// receipt names. Throws on failure so the card can say so; a receipt
  /// with no undo is a no-op.
  Future<void> undoReceipt(VanaReceiptPart part) async {
    final undo = part.undo;
    if (undo == null) return;
    final result = await _actions.run(UndoReceiptAction(params: undo.params));
    for (final p in result.parts) {
      if (p is VanaReceiptPart) await _refetchAfter(p);
    }
  }

  /// A server-side write bypassed the device's offline-first stores: pull
  /// the one the receipt names (`VanaWriteRefetcher`). A failed pull is
  /// only logged — the next screen open syncs anyway.
  Future<void> _refetchAfter(VanaReceiptPart part) async {
    try {
      await ref.read(vanaWriteRefetcherProvider).after(part);
    } catch (e, st) {
      _logger.warning(
        'Refetch after a Vana write failed',
        context: _context,
        error: e,
        stackTrace: st,
        data: {'entity': part.entity.wire, 'action': part.action.wire},
      );
    }
  }

  /// A stored assistant turn with nothing to draw — a chip's tap whose only
  /// result was a `batch`, or one the app has no widget for — is not a
  /// bubble (mp-464 clause 3: no line, and no empty bubble standing in for
  /// one).
  static List<VanaMessage> _drawable(List<VanaMessage> messages) => [
    for (final m in messages)
      if (m.isUser || m.content.isNotEmpty || m.parts.isNotEmpty) m,
  ];

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
    VanaUnavailableException() => VanaChatErrorKind.aiUnavailable,
    InsufficientCreditsException() => VanaChatErrorKind.insufficientCredits,
    VanaServerException() => VanaChatErrorKind.server,
    // The fridge-photo upload reports through the meal-logging exception.
    MealAiException(kind: MealAiFailureKind.offline) =>
      VanaChatErrorKind.offline,
    MealAiException() => VanaChatErrorKind.server,
    _ => VanaChatErrorKind.unknown,
  };
}
