import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../../shared/services/logging_service.dart';
import '../../application/coach_service.dart';
import '../../domain/coach_athlete_relationship.dart';
import '../../domain/coach_chat_state.dart';
import '../../domain/coach_message.dart';

part 'coach_chat_controller.g.dart';

/// Controller for the unified coach-athlete chat screen
/// Supports Supabase Realtime for instant message delivery
/// Works for both coach and athlete perspectives
@riverpod
class CoachChatController extends _$CoachChatController {
  CoachService get _coachService => ref.read(coachServiceProvider);
  AppLogger get _logger => ref.read(appLoggerProvider);

  RealtimeChannel? _channel;

  @override
  FutureOr<CoachChatState> build(String relationshipId) async {
    // Setup cleanup on dispose
    ref.onDispose(() {
      _unsubscribe();
    });

    return _loadChat(relationshipId);
  }

  Future<CoachChatState> _loadChat(String relationshipId) async {
    // Get relationship details
    final relationship = await _coachService.getRelationshipById(relationshipId);
    if (relationship == null) {
      throw Exception('Relationship not found');
    }

    // Get current user ID
    final currentUserId = await _coachService.getCurrentUserId();
    if (currentUserId == null) {
      throw Exception('User not found');
    }

    // Verify user is part of this relationship
    if (currentUserId != relationship.coachUserId &&
        currentUserId != relationship.athleteUserId) {
      throw Exception('Access denied: User is not part of this conversation');
    }

    // Get general chat messages only (no activity/plan comments)
    final messages = await _coachService.getGeneralChatMessages(
      coachUserId: relationship.coachUserId,
      athleteUserId: relationship.athleteUserId,
    );

    // Subscribe to realtime updates
    _subscribeToMessages(relationship);

    // Mark messages as read
    await _coachService.markConversationAsRead(
      coachUserId: relationship.coachUserId,
      athleteUserId: relationship.athleteUserId,
    );

    return CoachChatState(
      relationship: relationship,
      messages: messages,
      currentUserId: currentUserId,
    );
  }

  void _subscribeToMessages(CoachAthleteRelationship relationship) {
    // Unsubscribe from any existing channel first
    _unsubscribe();

    _channel = _coachService.subscribeToConversation(
      coachUserId: relationship.coachUserId,
      athleteUserId: relationship.athleteUserId,
      onNewMessage: _handleNewMessage,
    );
  }

  void _handleNewMessage(CoachMessage message) {
    _logger.info(
      'Handling new message from realtime subscription',
      context: 'COACH_CHAT_CONTROLLER',
      data: {
        'messageId': message.id,
        'senderUserId': message.senderUserId,
        'messageText': message.messageText.substring(0, message.messageText.length.clamp(0, 50)),
      },
    );

    final currentState = state.value;
    if (currentState == null) {
      _logger.warning(
        'Current state is null, cannot handle new message',
        context: 'COACH_CHAT_CONTROLLER',
      );
      return;
    }

    // Avoid duplicates (message might already be added optimistically)
    if (currentState.messages.any((m) => m.id == message.id)) {
      _logger.info(
        'Message already exists in messages list, skipping duplicate',
        context: 'COACH_CHAT_CONTROLLER',
        data: {'messageId': message.id},
      );
      return;
    }

    // Also check pending messages
    if (currentState.pendingMessages.any((m) => m.id == message.id)) {
      _logger.info(
        'Message exists in pending messages, removing from pending',
        context: 'COACH_CHAT_CONTROLLER',
        data: {'messageId': message.id},
      );

      // Remove from pending and add to messages
      final updatedPending = currentState.pendingMessages
          .where((m) => m.id != message.id)
          .toList();
      final updatedMessages = [...currentState.messages, message.copyWith(status: MessageStatus.sent)];
      updatedMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      state = AsyncData(currentState.copyWith(
        messages: updatedMessages,
        pendingMessages: updatedPending,
      ));

      return;
    }

    // Add message to list and sort by createdAt (oldest first for chat display)
    final updatedMessages = [...currentState.messages, message];
    updatedMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    _logger.info(
      'Adding new message to chat',
      context: 'COACH_CHAT_CONTROLLER',
      data: {
        'messageId': message.id,
        'totalMessages': updatedMessages.length,
      },
    );

    state = AsyncData(currentState.copyWith(messages: updatedMessages));

    // Mark as read if not sent by current user
    if (message.senderUserId != currentState.currentUserId) {
      _logger.info(
        'Marking conversation as read',
        context: 'COACH_CHAT_CONTROLLER',
      );
      _coachService.markConversationAsRead(
        coachUserId: currentState.relationship.coachUserId,
        athleteUserId: currentState.relationship.athleteUserId,
      );
    }
  }

  Future<void> _unsubscribe() async {
    if (_channel != null) {
      await _coachService.unsubscribeFromConversation(_channel!);
      _channel = null;
    }
  }

  /// Send a new message with offline queueing support
  Future<void> sendMessage(String messageText) async {
    final currentState = state.value;
    if (currentState == null || messageText.trim().isEmpty) return;

    // Create optimistic message with "sending" status
    final now = DateTime.now();
    final optimisticMessage = CoachMessage(
      id: const Uuid().v4(),
      coachUserId: currentState.relationship.coachUserId,
      athleteUserId: currentState.relationship.athleteUserId,
      senderUserId: currentState.currentUserId,
      messageText: messageText.trim(),
      createdAt: now,
      updatedAt: now,
      status: MessageStatus.sending,
    );

    // Add to pending messages immediately (optimistic UI)
    final updatedPendingMessages = [...currentState.pendingMessages, optimisticMessage];
    state = AsyncData(currentState.copyWith(
      pendingMessages: updatedPendingMessages,
      isSending: false,
      error: null,
    ));

    // Try to send to Supabase
    try {
      final sentMessage = await _coachService.sendChatMessage(
        coachUserId: currentState.relationship.coachUserId,
        athleteUserId: currentState.relationship.athleteUserId,
        messageText: messageText.trim(),
      );

      if (sentMessage != null) {
        // Success: Remove from pending, add to messages
        final newState = state.value;
        if (newState == null) return;

        final updatedPending = newState.pendingMessages
            .where((m) => m.id != optimisticMessage.id)
            .toList();
        final updatedMessages = [...newState.messages, sentMessage.copyWith(status: MessageStatus.sent)];
        updatedMessages.sort((a, b) => a.createdAt.compareTo(b.createdAt));

        state = AsyncData(newState.copyWith(
          messages: updatedMessages,
          pendingMessages: updatedPending,
        ));
      } else {
        // Failed: Update status to failed, keep in pending
        _markMessageAsFailed(optimisticMessage.id);
      }
    } catch (e) {
      // Failed: Update status to failed, keep in pending for retry
      _markMessageAsFailed(optimisticMessage.id);
    }
  }

  /// Mark a pending message as failed
  void _markMessageAsFailed(String messageId) {
    final currentState = state.value;
    if (currentState == null) return;

    final updatedPending = currentState.pendingMessages.map((m) {
      if (m.id == messageId) {
        return m.copyWith(status: MessageStatus.failed);
      }
      return m;
    }).toList();

    state = AsyncData(currentState.copyWith(
      pendingMessages: updatedPending,
      error: 'Some messages failed to send. Tap to retry.',
    ));
  }

  /// Refresh messages
  Future<void> refresh() async {
    final currentState = state.value;
    if (currentState == null) return;

    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => _loadChat(currentState.relationship.id),
    );
  }

  /// Clear error
  void clearError() {
    final currentState = state.value;
    if (currentState != null) {
      state = AsyncData(currentState.copyWith(error: null));
    }
  }

  /// Retry sending all failed messages
  Future<void> retryFailedMessages() async {
    final currentState = state.value;
    if (currentState == null) return;

    final failedMessages = currentState.pendingMessages
        .where((m) => m.status == MessageStatus.failed)
        .toList();

    if (failedMessages.isEmpty) return;

    // Mark all failed messages as sending
    final updatedPending = currentState.pendingMessages.map((m) {
      if (m.status == MessageStatus.failed) {
        return m.copyWith(status: MessageStatus.sending);
      }
      return m;
    }).toList();

    state = AsyncData(currentState.copyWith(
      pendingMessages: updatedPending,
      error: null,
    ));

    // Retry each failed message
    for (final message in failedMessages) {
      try {
        final sentMessage = await _coachService.sendChatMessage(
          coachUserId: message.coachUserId,
          athleteUserId: message.athleteUserId,
          messageText: message.messageText,
        );

        if (sentMessage != null) {
          // Success: Remove from pending, add to messages
          final newState = state.value;
          if (newState == null) return;

          final updatedPendingInner = newState.pendingMessages
              .where((m) => m.id != message.id)
              .toList();
          final updatedMessagesInner = [...newState.messages, sentMessage.copyWith(status: MessageStatus.sent)];
          updatedMessagesInner.sort((a, b) => a.createdAt.compareTo(b.createdAt));

          state = AsyncData(newState.copyWith(
            messages: updatedMessagesInner,
            pendingMessages: updatedPendingInner,
          ));
        } else {
          _markMessageAsFailed(message.id);
        }
      } catch (e) {
        _markMessageAsFailed(message.id);
      }
    }
  }
}
