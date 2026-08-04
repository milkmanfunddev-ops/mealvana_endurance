import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../shared/services/logging_service.dart';
import '../../../ai_credits/domain/insufficient_credits_exception.dart';
import '../../../ai_credits/presentation/insufficient_credits_paywall.dart';
import '../../data/ai_coach_chat_repository.dart';
import '../../domain/ai_coach_message.dart';
import '../../domain/ai_coach_ui_part.dart';

part 'ai_coach_chat_controller.g.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/// Immutable UI state for the Mealvana AI chat screen.
class AiCoachChatState {
  const AiCoachChatState({
    this.conversationId,
    this.messages = const [],
    this.isStreaming = false,
    this.errorMessage,
    this.hasHistory = false,
  });

  /// The current conversation UUID, or null when no conversation has been
  /// started yet (first-time users, or after [newChat]).
  final String? conversationId;

  /// All persisted messages plus any in-flight assistant message being
  /// streamed right now. The streaming message is always last and will have
  /// role `assistant`; its [AiCoachMessage.content] grows as chunks arrive and
  /// [AiCoachMessage.uiParts] accumulates UI parts.
  final List<AiCoachMessage> messages;

  /// True while the assistant reply is streaming.
  final bool isStreaming;

  /// Non-null when the last action failed; displayed as a snackbar by the
  /// screen (the controller sets this, the screen consumes and clears it).
  final String? errorMessage;

  /// True when `build()` found at least one prior conversation in the DB.
  /// The screen uses this to distinguish "still loading" from "genuinely new
  /// user with no conversations" so the proactive opener only fires for the
  /// latter.
  final bool hasHistory;

  AiCoachChatState copyWith({
    String? conversationId,
    List<AiCoachMessage>? messages,
    bool? isStreaming,
    String? errorMessage,
    bool? hasHistory,
    bool clearError = false,
    bool clearConversationId = false,
  }) {
    return AiCoachChatState(
      conversationId: clearConversationId
          ? null
          : (conversationId ?? this.conversationId),
      messages: messages ?? this.messages,
      isStreaming: isStreaming ?? this.isStreaming,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      hasHistory: hasHistory ?? this.hasHistory,
    );
  }
}

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

@riverpod
class AiCoachChatController extends _$AiCoachChatController {
  AiCoachChatRepository get _repository =>
      ref.read(aiCoachChatRepositoryProvider);
  ContentService get _contentService => ref.read(contentServiceProvider);
  AppLogger get _logger => ref.read(appLoggerProvider);

  @override
  FutureOr<AiCoachChatState> build() async {
    try {
      final conversations = await _repository.fetchConversations();
      if (conversations.isNotEmpty) {
        final latest = conversations.first;
        final messages = await _repository.fetchMessages(latest.id);
        return AiCoachChatState(
          conversationId: latest.id,
          messages: messages,
          hasHistory: true,
        );
      }
    } catch (e) {
      _logger.error(
        'AiCoachChatController.build: failed to resume conversation',
        error: e,
      );
    }
    return const AiCoachChatState();
  }

  // ── Send ──────────────────────────────────────────────────────────────────

  /// Sends [text] to Mealvana AI and streams the reply into state.
  ///
  /// Optimistically appends the user message, then streams the assistant
  /// response event-by-event:
  ///   - [AiCoachTextDelta] events accumulate into [AiCoachMessage.content].
  ///   - [AiCoachUiPartEvent] events append to [AiCoachMessage.uiParts].
  ///   - [AiCoachDoneEvent] / stream close marks streaming complete.
  ///
  /// On error the partial assistant message is removed and
  /// [AiCoachChatState.errorMessage] is set so the screen can show a snackbar.
  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final currentState = state.value ?? const AiCoachChatState();
    if (currentState.isStreaming) return;

    // ── Optimistic user message ──────────────────────────────────────────────
    final userMsg = AiCoachMessage(
      id: 'optimistic_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: currentState.conversationId ?? '',
      role: AiCoachMessageRole.user,
      content: trimmed,
      createdAt: DateTime.now(),
    );

    // Placeholder streaming assistant message
    final streamingMsg = AiCoachMessage(
      id: 'streaming_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: currentState.conversationId ?? '',
      role: AiCoachMessageRole.assistant,
      content: '',
      createdAt: DateTime.now(),
    );

    state = AsyncData(
      currentState.copyWith(
        messages: [...currentState.messages, userMsg, streamingMsg],
        isStreaming: true,
        clearError: true,
      ),
    );

    // ── Timezone ─────────────────────────────────────────────────────────────
    final timezone = _resolveTimezone();

    // ── Stream call ───────────────────────────────────────────────────────────
    try {
      final result = await _repository.sendMessage(
        message: trimmed,
        conversationId: currentState.conversationId,
        timezone: timezone,
        // Location is omitted for MVP — server degrades gracefully.
      );

      // Update conversation id if this was a new conversation.
      String resolvedConversationId = result.conversationId.isNotEmpty
          ? result.conversationId
          : (currentState.conversationId ?? '');

      String accumulated = '';
      final accumulatedUiParts = <AiCoachUiPart>[];

      await for (final event in result.eventStream) {
        // Screen may have been popped mid-stream (auto-dispose); bail before
        // touching state/ref to avoid UnmountedRefException.
        if (!ref.mounted) return;
        final current = state.value;
        if (current == null) break;

        if (event is AiCoachTextDelta) {
          accumulated += event.delta;

          final updatedMessages = List<AiCoachMessage>.from(current.messages);
          if (updatedMessages.isNotEmpty) {
            updatedMessages[updatedMessages.length - 1] = updatedMessages.last
                .copyWithContent(accumulated);
          }

          state = AsyncData(
            current.copyWith(
              conversationId: resolvedConversationId,
              messages: updatedMessages,
              isStreaming: true,
            ),
          );
        } else if (event is AiCoachUiPartEvent) {
          accumulatedUiParts.add(event.part);

          final updatedMessages = List<AiCoachMessage>.from(current.messages);
          if (updatedMessages.isNotEmpty) {
            updatedMessages[updatedMessages.length - 1] = updatedMessages.last
                .copyWithUiPart(event.part);
          }

          state = AsyncData(
            current.copyWith(
              conversationId: resolvedConversationId,
              messages: updatedMessages,
              isStreaming: true,
            ),
          );
        } else if (event is AiCoachStreamErrorEvent) {
          _logger.error(
            'AiCoachChatController: server stream error: ${event.message}',
          );
          // Surface as a snackbar but don't roll back the partial text.
          // The done event will still arrive (or stream will close) after this.
        } else if (event is AiCoachDoneEvent) {
          break;
        }
      }

      // Streaming complete — mark done.
      if (!ref.mounted) return;
      final finalState = state.value;
      if (finalState != null) {
        state = AsyncData(
          finalState.copyWith(
            conversationId: resolvedConversationId,
            isStreaming: false,
          ),
        );
      }

      _logger.info(
        'AiCoachChatController.send complete: conv=$resolvedConversationId '
        'uiParts=${accumulatedUiParts.length}',
      );
    } on AiCoachChatOfflineError catch (e) {
      if (!ref.mounted) return;
      _logger.error('AiCoachChatController.send offline', error: e);
      _handleSendError(
        currentState,
        _contentService.getValue(
          'ai_coach.error_offline',
          defaultValue: 'No connection. Check your network and try again.',
        ),
      );
    } on InsufficientCreditsException catch (e) {
      if (!ref.mounted) return;
      _logger.error('AiCoachChatController.send out of AI credits', error: e);
      maybeShowInsufficientCreditsPaywall(e);
      _handleSendError(
        currentState,
        e.message.trim().isNotEmpty ? e.message : 'You are out of AI credits.',
      );
    } on AiCoachChatServerError catch (e) {
      if (!ref.mounted) return;
      _logger.error('AiCoachChatController.send server error', error: e);
      final msg = e.statusCode == 401
          ? _contentService.getValue(
              'ai_coach.error_unauthorized',
              defaultValue: 'Session expired. Please sign in again.',
            )
          : _contentService.getValue(
              'ai_coach.error_server',
              defaultValue: "Mealvana couldn't respond right now. Try again.",
            );
      _handleSendError(currentState, msg);
    } catch (e, st) {
      if (!ref.mounted) return;
      _logger.error(
        'AiCoachChatController.send unexpected',
        error: e,
        stackTrace: st,
      );
      _handleSendError(
        currentState,
        _contentService.getValue(
          'ai_coach.error_unknown',
          defaultValue: 'Something went wrong. Please try again.',
        ),
      );
    }
  }

  /// Strips the in-flight streaming message and surfaces [errorMessage].
  void _handleSendError(AiCoachChatState preErrorState, String errorMessage) {
    // Remove the optimistic streaming message (the last one) and the
    // optimistic user message (second-to-last), rolling back to pre-send state.
    final msgs = List<AiCoachMessage>.from(preErrorState.messages);
    state = AsyncData(
      AiCoachChatState(
        conversationId: preErrorState.conversationId,
        messages: msgs,
        isStreaming: false,
        errorMessage: errorMessage,
      ),
    );
  }

  // ── Proactive opener ────────────────────────────────────────────────────────

  /// Streams Mealvana AI's proactive opening greeting into state when the conversation
  /// is empty and idle.
  ///
  /// The opener is *ephemeral* — the server persists nothing, so it regenerates
  /// each time the chat is opened fresh (always contextual to current training).
  /// On any failure it silently restores the empty state; the screen then shows
  /// its static greeting. An opener is a nicety, never an error to surface.
  Future<void> loadOpener() async {
    final currentState = state.value ?? const AiCoachChatState();
    if (currentState.messages.isNotEmpty || currentState.isStreaming) return;

    final streamingMsg = AiCoachMessage(
      id: 'opener_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: '',
      role: AiCoachMessageRole.assistant,
      content: '',
      createdAt: DateTime.now(),
    );

    state = AsyncData(
      currentState.copyWith(
        messages: [streamingMsg],
        isStreaming: true,
        clearError: true,
      ),
    );

    try {
      final result = await _repository.requestOpener(
        timezone: _resolveTimezone(),
      );

      String accumulated = '';
      await for (final event in result.eventStream) {
        // The screen may have been popped mid-stream (auto-dispose); bail before
        // touching state/ref to avoid UnmountedRefException.
        if (!ref.mounted) return;
        final current = state.value;
        if (current == null) break;

        if (event is AiCoachTextDelta) {
          accumulated += event.delta;
          final msgs = List<AiCoachMessage>.from(current.messages);
          if (msgs.isNotEmpty) {
            msgs[msgs.length - 1] = msgs.last.copyWithContent(accumulated);
          }
          state = AsyncData(
            current.copyWith(messages: msgs, isStreaming: true),
          );
        } else if (event is AiCoachUiPartEvent) {
          final msgs = List<AiCoachMessage>.from(current.messages);
          if (msgs.isNotEmpty) {
            msgs[msgs.length - 1] = msgs.last.copyWithUiPart(event.part);
          }
          state = AsyncData(
            current.copyWith(messages: msgs, isStreaming: true),
          );
        } else if (event is AiCoachDoneEvent) {
          break;
        }
        // AiCoachStreamErrorEvent is ignored — the empty-opener guard below cleans
        // up if nothing streamed.
      }

      if (!ref.mounted) return;
      final finalState = state.value;
      if (finalState != null) {
        // If the opener produced no content, drop the placeholder so the
        // static empty state shows instead of an empty bubble.
        final last = finalState.messages.isNotEmpty
            ? finalState.messages.last
            : null;
        final emptyOpener =
            last != null && last.content.isEmpty && last.uiParts.isEmpty;
        state = AsyncData(
          finalState.copyWith(
            messages: emptyOpener ? const [] : finalState.messages,
            isStreaming: false,
          ),
        );
      }
    } catch (e) {
      // Opener is optional; if the provider is gone there's nothing to restore
      // and nothing safe to log against a disposed ref.
      if (!ref.mounted) return;
      _logger.error(
        'AiCoachChatController.loadOpener failed (non-fatal)',
        error: e,
      );
      state = const AsyncData(AiCoachChatState());
    }
  }

  // ── New Chat ──────────────────────────────────────────────────────────────

  /// Clears the current conversation so the user can start fresh.
  void newChat() {
    state = const AsyncData(AiCoachChatState());
  }

  // ── Error dismiss ─────────────────────────────────────────────────────────

  /// Called by the screen after it has consumed and shown the error snackbar.
  void clearError() {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(clearError: true));
  }

  // ── Timezone helper ───────────────────────────────────────────────────────

  /// Returns the device's IANA timezone string when determinable, otherwise
  /// an offset-derived IANA Etc/GMT zone so the server's day-boundary math
  /// still tracks the user's local day instead of silently falling back to
  /// UTC.
  String _resolveTimezone() {
    final now = DateTime.now();
    // On web (and some desktop platforms) timeZoneName is already an IANA
    // name like "America/Chicago"; mobile platforms return abbreviations
    // ("CDT") the server can't parse.
    if (now.timeZoneName.contains('/')) return now.timeZoneName;

    // Etc/GMT zones use inverted sign by POSIX convention: UTC+5 → Etc/GMT-5.
    final offsetHours = now.timeZoneOffset.inHours;
    if (offsetHours == 0) return 'UTC';
    return offsetHours > 0 ? 'Etc/GMT-$offsetHours' : 'Etc/GMT+${-offsetHours}';
  }
}
