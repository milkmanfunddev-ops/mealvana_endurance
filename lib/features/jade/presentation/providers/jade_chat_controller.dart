import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../shared/services/logging_service.dart';
import '../../../ai_credits/domain/insufficient_credits_exception.dart';
import '../../../ai_credits/presentation/insufficient_credits_paywall.dart';
import '../../data/jade_chat_repository.dart';
import '../../domain/jade_message.dart';
import '../../domain/jade_ui_part.dart';

part 'jade_chat_controller.g.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

/// Immutable UI state for the Jade chat screen.
class JadeChatState {
  const JadeChatState({
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
  /// role `assistant`; its [JadeMessage.content] grows as chunks arrive and
  /// [JadeMessage.uiParts] accumulates UI parts.
  final List<JadeMessage> messages;

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

  JadeChatState copyWith({
    String? conversationId,
    List<JadeMessage>? messages,
    bool? isStreaming,
    String? errorMessage,
    bool? hasHistory,
    bool clearError = false,
    bool clearConversationId = false,
  }) {
    return JadeChatState(
      conversationId:
          clearConversationId ? null : (conversationId ?? this.conversationId),
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
class JadeChatController extends _$JadeChatController {
  JadeChatRepository get _repository => ref.read(jadeChatRepositoryProvider);
  ContentService get _contentService => ref.read(contentServiceProvider);
  AppLogger get _logger => ref.read(appLoggerProvider);

  @override
  FutureOr<JadeChatState> build() async {
    try {
      final conversations = await _repository.fetchConversations();
      if (conversations.isNotEmpty) {
        final latest = conversations.first;
        final messages = await _repository.fetchMessages(latest.id);
        return JadeChatState(
          conversationId: latest.id,
          messages: messages,
          hasHistory: true,
        );
      }
    } catch (e) {
      _logger.error(
        'JadeChatController.build: failed to resume conversation',
        error: e,
      );
    }
    return const JadeChatState();
  }

  // ── Send ──────────────────────────────────────────────────────────────────

  /// Sends [text] to Jade and streams the reply into state.
  ///
  /// Optimistically appends the user message, then streams the assistant
  /// response event-by-event:
  ///   - [JadeTextDelta] events accumulate into [JadeMessage.content].
  ///   - [JadeUiPartEvent] events append to [JadeMessage.uiParts].
  ///   - [JadeDoneEvent] / stream close marks streaming complete.
  ///
  /// On error the partial assistant message is removed and
  /// [JadeChatState.errorMessage] is set so the screen can show a snackbar.
  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final currentState = state.value ?? const JadeChatState();
    if (currentState.isStreaming) return;

    // ── Optimistic user message ──────────────────────────────────────────────
    final userMsg = JadeMessage(
      id: 'optimistic_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: currentState.conversationId ?? '',
      role: JadeMessageRole.user,
      content: trimmed,
      createdAt: DateTime.now(),
    );

    // Placeholder streaming assistant message
    final streamingMsg = JadeMessage(
      id: 'streaming_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: currentState.conversationId ?? '',
      role: JadeMessageRole.assistant,
      content: '',
      createdAt: DateTime.now(),
    );

    state = AsyncData(currentState.copyWith(
      messages: [...currentState.messages, userMsg, streamingMsg],
      isStreaming: true,
      clearError: true,
    ));

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
      String resolvedConversationId =
          result.conversationId.isNotEmpty
              ? result.conversationId
              : (currentState.conversationId ?? '');

      String accumulated = '';
      final accumulatedUiParts = <JadeUiPart>[];

      await for (final event in result.eventStream) {
        // Screen may have been popped mid-stream (auto-dispose); bail before
        // touching state/ref to avoid UnmountedRefException.
        if (!ref.mounted) return;
        final current = state.value;
        if (current == null) break;

        if (event is JadeTextDelta) {
          accumulated += event.delta;

          final updatedMessages = List<JadeMessage>.from(current.messages);
          if (updatedMessages.isNotEmpty) {
            updatedMessages[updatedMessages.length - 1] =
                updatedMessages.last.copyWithContent(accumulated);
          }

          state = AsyncData(current.copyWith(
            conversationId: resolvedConversationId,
            messages: updatedMessages,
            isStreaming: true,
          ));
        } else if (event is JadeUiPartEvent) {
          accumulatedUiParts.add(event.part);

          final updatedMessages = List<JadeMessage>.from(current.messages);
          if (updatedMessages.isNotEmpty) {
            updatedMessages[updatedMessages.length - 1] =
                updatedMessages.last.copyWithUiPart(event.part);
          }

          state = AsyncData(current.copyWith(
            conversationId: resolvedConversationId,
            messages: updatedMessages,
            isStreaming: true,
          ));
        } else if (event is JadeStreamErrorEvent) {
          _logger.error(
            'JadeChatController: server stream error: ${event.message}',
          );
          // Surface as a snackbar but don't roll back the partial text.
          // The done event will still arrive (or stream will close) after this.
        } else if (event is JadeDoneEvent) {
          break;
        }
      }

      // Streaming complete — mark done.
      if (!ref.mounted) return;
      final finalState = state.value;
      if (finalState != null) {
        state = AsyncData(finalState.copyWith(
          conversationId: resolvedConversationId,
          isStreaming: false,
        ));
      }

      _logger.info(
        'JadeChatController.send complete: conv=$resolvedConversationId '
        'uiParts=${accumulatedUiParts.length}',
      );
    } on JadeChatOfflineError catch (e) {
      if (!ref.mounted) return;
      _logger.error(
        'JadeChatController.send offline',
        error: e,
      );
      _handleSendError(currentState, _contentService.getValue(
        'jade.error_offline',
        defaultValue: 'No connection. Check your network and try again.',
      ));
    } on InsufficientCreditsException catch (e) {
      if (!ref.mounted) return;
      _logger.error('JadeChatController.send out of AI credits', error: e);
      maybeShowInsufficientCreditsPaywall(e);
      _handleSendError(
        currentState,
        e.message.trim().isNotEmpty ? e.message : 'You are out of AI credits.',
      );
    } on JadeChatServerError catch (e) {
      if (!ref.mounted) return;
      _logger.error(
        'JadeChatController.send server error',
        error: e,
      );
      final msg = e.statusCode == 401
          ? _contentService.getValue(
              'jade.error_unauthorized',
              defaultValue: 'Session expired. Please sign in again.',
            )
          : _contentService.getValue(
              'jade.error_server',
              defaultValue: "Jade couldn't respond right now. Try again.",
            );
      _handleSendError(currentState, msg);
    } catch (e, st) {
      if (!ref.mounted) return;
      _logger.error('JadeChatController.send unexpected', error: e, stackTrace: st);
      _handleSendError(
        currentState,
        _contentService.getValue(
          'jade.error_unknown',
          defaultValue: 'Something went wrong. Please try again.',
        ),
      );
    }
  }

  /// Strips the in-flight streaming message and surfaces [errorMessage].
  void _handleSendError(JadeChatState preErrorState, String errorMessage) {
    // Remove the optimistic streaming message (the last one) and the
    // optimistic user message (second-to-last), rolling back to pre-send state.
    final msgs = List<JadeMessage>.from(preErrorState.messages);
    state = AsyncData(JadeChatState(
      conversationId: preErrorState.conversationId,
      messages: msgs,
      isStreaming: false,
      errorMessage: errorMessage,
    ));
  }

  // ── Proactive opener ────────────────────────────────────────────────────────

  /// Streams Jade's proactive opening greeting into state when the conversation
  /// is empty and idle.
  ///
  /// The opener is *ephemeral* — the server persists nothing, so it regenerates
  /// each time the chat is opened fresh (always contextual to current training).
  /// On any failure it silently restores the empty state; the screen then shows
  /// its static greeting. An opener is a nicety, never an error to surface.
  Future<void> loadOpener() async {
    final currentState = state.value ?? const JadeChatState();
    if (currentState.messages.isNotEmpty || currentState.isStreaming) return;

    final streamingMsg = JadeMessage(
      id: 'opener_${DateTime.now().millisecondsSinceEpoch}',
      conversationId: '',
      role: JadeMessageRole.assistant,
      content: '',
      createdAt: DateTime.now(),
    );

    state = AsyncData(currentState.copyWith(
      messages: [streamingMsg],
      isStreaming: true,
      clearError: true,
    ));

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

        if (event is JadeTextDelta) {
          accumulated += event.delta;
          final msgs = List<JadeMessage>.from(current.messages);
          if (msgs.isNotEmpty) {
            msgs[msgs.length - 1] = msgs.last.copyWithContent(accumulated);
          }
          state = AsyncData(current.copyWith(messages: msgs, isStreaming: true));
        } else if (event is JadeUiPartEvent) {
          final msgs = List<JadeMessage>.from(current.messages);
          if (msgs.isNotEmpty) {
            msgs[msgs.length - 1] = msgs.last.copyWithUiPart(event.part);
          }
          state = AsyncData(current.copyWith(messages: msgs, isStreaming: true));
        } else if (event is JadeDoneEvent) {
          break;
        }
        // JadeStreamErrorEvent is ignored — the empty-opener guard below cleans
        // up if nothing streamed.
      }

      if (!ref.mounted) return;
      final finalState = state.value;
      if (finalState != null) {
        // If the opener produced no content, drop the placeholder so the
        // static empty state shows instead of an empty bubble.
        final last =
            finalState.messages.isNotEmpty ? finalState.messages.last : null;
        final emptyOpener =
            last != null && last.content.isEmpty && last.uiParts.isEmpty;
        state = AsyncData(finalState.copyWith(
          messages: emptyOpener ? const [] : finalState.messages,
          isStreaming: false,
        ));
      }
    } catch (e) {
      // Opener is optional; if the provider is gone there's nothing to restore
      // and nothing safe to log against a disposed ref.
      if (!ref.mounted) return;
      _logger.error('JadeChatController.loadOpener failed (non-fatal)', error: e);
      state = const AsyncData(JadeChatState());
    }
  }

  // ── New Chat ──────────────────────────────────────────────────────────────

  /// Clears the current conversation so the user can start fresh.
  void newChat() {
    state = const AsyncData(JadeChatState());
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
