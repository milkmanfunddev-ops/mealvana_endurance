import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../shared/services/logging_service.dart';
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

  JadeChatState copyWith({
    String? conversationId,
    List<JadeMessage>? messages,
    bool? isStreaming,
    String? errorMessage,
    bool clearError = false,
    bool clearConversationId = false,
  }) {
    return JadeChatState(
      conversationId:
          clearConversationId ? null : (conversationId ?? this.conversationId),
      messages: messages ?? this.messages,
      isStreaming: isStreaming ?? this.isStreaming,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
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
    // On first build, load the most-recent conversation.
    return _loadMostRecentConversation();
  }

  // ── Init ──────────────────────────────────────────────────────────────────

  /// Loads the most-recent non-deleted conversation's messages into state.
  ///
  /// If the user has no conversations yet, returns an empty state so the
  /// first-time empty screen is displayed.
  Future<JadeChatState> _loadMostRecentConversation() async {
    try {
      final conversations = await _repository.fetchConversations();
      if (conversations.isEmpty) {
        return const JadeChatState();
      }
      final latest = conversations.first;
      final messages = await _repository.fetchMessages(latest.id);
      return JadeChatState(
        conversationId: latest.id,
        messages: messages,
      );
    } catch (e, st) {
      _logger.error(
        'JadeChatController._loadMostRecentConversation failed',
        error: e,
        stackTrace: st,
      );
      // Return empty state — user can still start a new chat.
      return const JadeChatState();
    }
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
      _logger.error(
        'JadeChatController.send offline',
        error: e,
      );
      _handleSendError(currentState, _contentService.getValue(
        'jade.error_offline',
        defaultValue: 'No connection. Check your network and try again.',
      ));
    } on JadeChatServerError catch (e) {
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
