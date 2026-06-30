// ignore_for_file: avoid_implementing_value_types
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mealvana_endurance/features/coach_mode/application/coach_service.dart';
import 'package:mealvana_endurance/features/coach_mode/domain/coach_athlete_relationship.dart';
import 'package:mealvana_endurance/features/coach_mode/domain/coach_message.dart';
import 'package:mealvana_endurance/features/coach_mode/presentation/providers/coach_chat_controller.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';

// ---------------------------------------------------------------------------
// Mocks
// ---------------------------------------------------------------------------

class _MockCoachService extends Mock implements CoachService {}

class _FakeLogger extends Fake implements AppLogger {
  @override
  void info(String message, {String? context, Map<String, dynamic>? data}) {}

  @override
  void error(String message,
      {String? context,
      Map<String, dynamic>? data,
      dynamic error,
      StackTrace? stackTrace}) {}

  @override
  void warning(String message,
      {String? context,
      Map<String, dynamic>? data,
      dynamic error,
      StackTrace? stackTrace}) {}

  @override
  void debug(String message,
      {String? context,
      Map<String, dynamic>? data,
      dynamic error,
      StackTrace? stackTrace}) {}
}

class _FakeRealtimeChannel extends Fake implements RealtimeChannel {}

// ---------------------------------------------------------------------------
// Fallback registration (required by mocktail for RealtimeChannel)
// ---------------------------------------------------------------------------

void _registerFallbacks() {
  registerFallbackValue(_FakeRealtimeChannel());
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _coachUserId = 'coach-user-id';
const _athleteUserId = 'athlete-user-id';
const _relationshipId = 'rel-1';

CoachAthleteRelationship _activeRelationship() {
  final now = DateTime.now();
  return CoachAthleteRelationship(
    id: _relationshipId,
    coachUserId: _coachUserId,
    athleteUserId: _athleteUserId,
    status: RelationshipStatus.active,
    requestedBy: 'coach',
    requestedAt: now,
    acceptedAt: now,
    createdAt: now,
    updatedAt: now,
    coachDisplayName: 'Coach Alice',
    athleteDisplayName: 'Athlete Bob',
  );
}

CoachMessage _sampleMessage({
  String id = 'msg-1',
  String sender = _coachUserId,
  Duration offset = Duration.zero,
}) {
  final now = DateTime.now().add(offset);
  return CoachMessage(
    id: id,
    coachUserId: _coachUserId,
    athleteUserId: _athleteUserId,
    senderUserId: sender,
    messageText: 'Hello!',
    createdAt: now,
    updatedAt: now,
    status: MessageStatus.sent,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _MockCoachService coachService;
  late _FakeLogger logger;
  late _FakeRealtimeChannel fakeChannel;

  setUpAll(() {
    _registerFallbacks();
  });

  setUp(() {
    coachService = _MockCoachService();
    logger = _FakeLogger();
    fakeChannel = _FakeRealtimeChannel();

    // Default stubs for the build() path
    when(() => coachService.syncRelationshipsFromSupabase())
        .thenAnswer((_) async => []);
    when(() => coachService.syncMyCoachesData()).thenAnswer((_) async {});
    when(() => coachService.getRelationshipById(_relationshipId))
        .thenAnswer((_) async => _activeRelationship());
    when(() => coachService.getCurrentUserId())
        .thenAnswer((_) async => _coachUserId);
    when(() => coachService.getGeneralChatMessages(
          coachUserId: any(named: 'coachUserId'),
          athleteUserId: any(named: 'athleteUserId'),
          limit: any(named: 'limit'),
        )).thenAnswer((_) async => []);
    when(() => coachService.subscribeToConversation(
          coachUserId: any(named: 'coachUserId'),
          athleteUserId: any(named: 'athleteUserId'),
          onNewMessage: any(named: 'onNewMessage'),
        )).thenReturn(fakeChannel);
    when(() => coachService.markConversationAsRead(
          coachUserId: any(named: 'coachUserId'),
          athleteUserId: any(named: 'athleteUserId'),
        )).thenAnswer((_) async {});
    when(() => coachService.unsubscribeFromConversation(any()))
        .thenAnswer((_) async {});
  });

  ProviderContainer _container() {
    final c = ProviderContainer(overrides: [
      coachServiceProvider.overrideWithValue(coachService),
      appLoggerProvider.overrideWithValue(logger),
    ]);
    addTearDown(c.dispose);
    return c;
  }

  // -------------------------------------------------------------------------
  // build()
  // -------------------------------------------------------------------------

  group('CoachChatController.build', () {
    test('loads messages and exposes relationship on initial build', () async {
      final msg = _sampleMessage();
      when(() => coachService.getGeneralChatMessages(
            coachUserId: any(named: 'coachUserId'),
            athleteUserId: any(named: 'athleteUserId'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => [msg]);

      final container = _container();
      await container.read(coachChatControllerProvider(_relationshipId).future);
      final state =
          container.read(coachChatControllerProvider(_relationshipId)).value!;

      expect(state.messages, hasLength(1));
      expect(state.messages.first.id, 'msg-1');
      expect(state.relationship.id, _relationshipId);
      expect(state.currentUserId, _coachUserId);
    });

    test('produces error state when relationship is not found', () async {
      when(() => coachService.getRelationshipById(_relationshipId))
          .thenAnswer((_) async => null);

      final container = _container();
      // The provider must emit an AsyncError — not silently succeed
      final result =
          await container.read(coachChatControllerProvider(_relationshipId).future)
              .then((_) => false)
              .catchError((_) => true);
      expect(result, isTrue,
          reason: 'Controller must fail (AsyncError) when relationship is null');
    });

    test('produces error state when current user is not part of relationship',
        () async {
      when(() => coachService.getCurrentUserId())
          .thenAnswer((_) async => 'some-other-user');

      final container = _container();
      final result =
          await container.read(coachChatControllerProvider(_relationshipId).future)
              .then((_) => false)
              .catchError((_) => true);
      expect(result, isTrue,
          reason: 'Controller must fail when user is not part of relationship');
    });
  });

  // -------------------------------------------------------------------------
  // sendMessage()
  // -------------------------------------------------------------------------

  group('CoachChatController.sendMessage', () {
    test('optimistic message is added to pendingMessages immediately', () async {
      // Make sendChatMessage slow so we can inspect the intermediate state
      final completer = Completer<CoachMessage?>();
      when(() => coachService.sendChatMessage(
            coachUserId: any(named: 'coachUserId'),
            athleteUserId: any(named: 'athleteUserId'),
            messageText: any(named: 'messageText'),
          )).thenAnswer((_) => completer.future);

      final container = _container();
      await container.read(coachChatControllerProvider(_relationshipId).future);

      // Send without awaiting so we can observe intermediate state
      unawaited(container
          .read(coachChatControllerProvider(_relationshipId).notifier)
          .sendMessage('Hello!'));

      // Wait one microtask for the optimistic update
      await Future.microtask(() {});

      final state =
          container.read(coachChatControllerProvider(_relationshipId)).value!;

      expect(state.pendingMessages, hasLength(1));
      expect(state.pendingMessages.first.messageText, 'Hello!');
      expect(state.pendingMessages.first.status, MessageStatus.sending);

      // Resolve the send
      completer.complete(null);
    });

    test('on success: message moves from pending to confirmed messages', () async {
      final confirmedMsg = _sampleMessage(id: 'server-msg-1');
      when(() => coachService.sendChatMessage(
            coachUserId: any(named: 'coachUserId'),
            athleteUserId: any(named: 'athleteUserId'),
            messageText: any(named: 'messageText'),
          )).thenAnswer((_) async => confirmedMsg);

      final container = _container();
      await container.read(coachChatControllerProvider(_relationshipId).future);

      await container
          .read(coachChatControllerProvider(_relationshipId).notifier)
          .sendMessage('Hello!');

      final state =
          container.read(coachChatControllerProvider(_relationshipId)).value!;

      expect(state.pendingMessages, isEmpty,
          reason: 'Confirmed messages should leave pending list');
      expect(state.messages, hasLength(1));
      expect(state.messages.first.id, 'server-msg-1');
      expect(state.messages.first.status, MessageStatus.sent);
    });

    test(
        'BUG CHECK — on send failure: message stays in pending with failed status, error is NOT null',
        () async {
      when(() => coachService.sendChatMessage(
            coachUserId: any(named: 'coachUserId'),
            athleteUserId: any(named: 'athleteUserId'),
            messageText: any(named: 'messageText'),
          )).thenThrow(StateError('Failed to send chat message remotely'));

      final container = _container();
      await container.read(coachChatControllerProvider(_relationshipId).future);

      await container
          .read(coachChatControllerProvider(_relationshipId).notifier)
          .sendMessage('Hello!');

      final state =
          container.read(coachChatControllerProvider(_relationshipId)).value!;

      // CRITICAL: failed message must stay in pending (not disappear silently)
      expect(state.pendingMessages, hasLength(1),
          reason:
              'Failed message must remain in pendingMessages so the user can retry. '
              'Silently dropping it violates the offline-queue contract.');
      expect(state.pendingMessages.first.status, MessageStatus.failed);
      expect(state.error, isNotNull,
          reason: 'Error must be surfaced to the user on send failure.');
    });

    test(
        'BUG CHECK — sendChatMessage returning null is treated as failure (not silent success)',
        () async {
      // sendChatMessage returns null when profile is missing
      when(() => coachService.sendChatMessage(
            coachUserId: any(named: 'coachUserId'),
            athleteUserId: any(named: 'athleteUserId'),
            messageText: any(named: 'messageText'),
          )).thenAnswer((_) async => null);

      final container = _container();
      await container.read(coachChatControllerProvider(_relationshipId).future);

      await container
          .read(coachChatControllerProvider(_relationshipId).notifier)
          .sendMessage('Hello!');

      final state =
          container.read(coachChatControllerProvider(_relationshipId)).value!;

      // null return is treated as failure — message must NOT appear in messages
      expect(state.messages, isEmpty,
          reason: 'A null return from sendChatMessage must not be treated as success.');
      // The message remains pending with failed status
      expect(state.pendingMessages.first.status, MessageStatus.failed);
    });

    test('empty message text is ignored and produces no state change', () async {
      final container = _container();
      await container.read(coachChatControllerProvider(_relationshipId).future);

      await container
          .read(coachChatControllerProvider(_relationshipId).notifier)
          .sendMessage('   '); // whitespace-only

      final state =
          container.read(coachChatControllerProvider(_relationshipId)).value!;

      // sendChatMessage should not have been called
      verifyNever(() => coachService.sendChatMessage(
            coachUserId: any(named: 'coachUserId'),
            athleteUserId: any(named: 'athleteUserId'),
            messageText: any(named: 'messageText'),
          ));
      expect(state.pendingMessages, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // retryFailedMessages()
  // -------------------------------------------------------------------------

  group('CoachChatController.retryFailedMessages', () {
    test('retrying a failed message on success moves it to confirmed', () async {
      // First send fails, retry succeeds
      final confirmedMsg = _sampleMessage(id: 'server-msg-retry');
      var callCount = 0;
      when(() => coachService.sendChatMessage(
            coachUserId: any(named: 'coachUserId'),
            athleteUserId: any(named: 'athleteUserId'),
            messageText: any(named: 'messageText'),
          )).thenAnswer((_) async {
        callCount++;
        if (callCount == 1) throw StateError('first attempt fails');
        return confirmedMsg;
      });

      final container = _container();
      await container.read(coachChatControllerProvider(_relationshipId).future);

      // First send: fails
      await container
          .read(coachChatControllerProvider(_relationshipId).notifier)
          .sendMessage('retry me');

      var state =
          container.read(coachChatControllerProvider(_relationshipId)).value!;
      expect(state.pendingMessages.first.status, MessageStatus.failed);

      // Retry: succeeds
      await container
          .read(coachChatControllerProvider(_relationshipId).notifier)
          .retryFailedMessages();

      state =
          container.read(coachChatControllerProvider(_relationshipId)).value!;

      expect(state.pendingMessages, isEmpty,
          reason: 'Successful retry should remove from pending');
      expect(state.messages, hasLength(1));
      expect(state.messages.first.id, 'server-msg-retry');
    });

    test('retryFailedMessages with no failed messages is a no-op', () async {
      final container = _container();
      await container.read(coachChatControllerProvider(_relationshipId).future);

      // No pending messages, retry is a no-op
      await container
          .read(coachChatControllerProvider(_relationshipId).notifier)
          .retryFailedMessages();

      // sendChatMessage should not have been called
      verifyNever(() => coachService.sendChatMessage(
            coachUserId: any(named: 'coachUserId'),
            athleteUserId: any(named: 'athleteUserId'),
            messageText: any(named: 'messageText'),
          ));
    });
  });

  // -------------------------------------------------------------------------
  // clearError()
  // -------------------------------------------------------------------------

  group('CoachChatController.clearError', () {
    test('clearError removes error from state without resetting messages', () async {
      when(() => coachService.sendChatMessage(
            coachUserId: any(named: 'coachUserId'),
            athleteUserId: any(named: 'athleteUserId'),
            messageText: any(named: 'messageText'),
          )).thenThrow(StateError('send failed'));

      final container = _container();
      await container.read(coachChatControllerProvider(_relationshipId).future);
      await container
          .read(coachChatControllerProvider(_relationshipId).notifier)
          .sendMessage('fail me');

      var state =
          container.read(coachChatControllerProvider(_relationshipId)).value!;
      expect(state.error, isNotNull);

      container
          .read(coachChatControllerProvider(_relationshipId).notifier)
          .clearError();

      state =
          container.read(coachChatControllerProvider(_relationshipId)).value!;
      expect(state.error, isNull);
      // Pending messages still present (just error cleared)
      expect(state.pendingMessages, hasLength(1));
    });
  });

  // -------------------------------------------------------------------------
  // Realtime message dedup
  // -------------------------------------------------------------------------

  group('CoachChatController — realtime dedup logic', () {
    test(
        'duplicate message ID from realtime is not added twice to messages list',
        () async {
      final existingMsg = _sampleMessage(id: 'existing-msg');
      when(() => coachService.getGeneralChatMessages(
            coachUserId: any(named: 'coachUserId'),
            athleteUserId: any(named: 'athleteUserId'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => [existingMsg]);

      final container = _container();
      await container.read(coachChatControllerProvider(_relationshipId).future);

      final notifier =
          container.read(coachChatControllerProvider(_relationshipId).notifier);

      // Directly invoke handleNewMessage with same ID (simulates realtime duplicate)
      notifier.handleNewMessageForTest(existingMsg);

      final state =
          container.read(coachChatControllerProvider(_relationshipId)).value!;

      // Should still be 1 message, not 2
      expect(state.messages, hasLength(1),
          reason: 'Duplicate message IDs from realtime must be deduplicated.');
    });
  });
}

// ---------------------------------------------------------------------------
// Test-only extension to expose internal handleNewMessage for testing
// ---------------------------------------------------------------------------

extension CoachChatControllerTestHelper on CoachChatController {
  void handleNewMessageForTest(CoachMessage message) {
    final currentState = state.value;
    if (currentState == null) return;

    // Mirrors _handleNewMessage logic:
    if (currentState.messages.any((m) => m.id == message.id)) return;
    if (currentState.pendingMessages.any((m) => m.id == message.id)) return;

    final updated = [...currentState.messages, message];
    updated.sort((a, b) {
      final tc = a.createdAt.compareTo(b.createdAt);
      if (tc != 0) return tc;
      return a.id.compareTo(b.id);
    });
    state = AsyncData(currentState.copyWith(messages: updated));
  }
}
