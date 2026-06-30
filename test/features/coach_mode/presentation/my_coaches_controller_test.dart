// ignore_for_file: avoid_implementing_value_types
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mealvana_endurance/features/coach_mode/application/coach_service.dart';
import 'package:mealvana_endurance/features/coach_mode/domain/coach_athlete_relationship.dart';
import 'package:mealvana_endurance/features/coach_mode/presentation/providers/my_coaches_controller.dart';
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

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _coachUserId = 'coach-user-id';
const _athleteUserId = 'athlete-user-id';

CoachAthleteRelationship _makeRelationship({
  String id = 'rel-1',
  RelationshipStatus status = RelationshipStatus.active,
  String requestedBy = 'coach',
}) {
  final now = DateTime.now();
  return CoachAthleteRelationship(
    id: id,
    coachUserId: _coachUserId,
    athleteUserId: _athleteUserId,
    status: status,
    requestedBy: requestedBy,
    requestedAt: now,
    acceptedAt: status == RelationshipStatus.active ? now : null,
    createdAt: now,
    updatedAt: now,
    coachDisplayName: 'Alice Smith',
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _MockCoachService coachService;
  late _FakeLogger logger;

  setUp(() {
    coachService = _MockCoachService();
    logger = _FakeLogger();

    // Background sync stubs
    when(() => coachService.syncRelationshipsFromSupabase())
        .thenAnswer((_) async => []);
    when(() => coachService.syncMyCoachesData()).thenAnswer((_) async {});
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

  group('MyCoachesController.build', () {
    test('loads active coaches and pending requests on initial build', () async {
      final activeRel = _makeRelationship(status: RelationshipStatus.active);
      final pendingRel = _makeRelationship(
        id: 'rel-pending',
        status: RelationshipStatus.pending,
        requestedBy: 'coach',
      );

      when(() => coachService.getMyCoaches())
          .thenAnswer((_) async => [activeRel]);
      when(() => coachService.getPendingCoachRequests())
          .thenAnswer((_) async => [pendingRel]);

      final container = _container();
      await container.read(myCoachesControllerProvider.future);
      final state = container.read(myCoachesControllerProvider).value!;

      expect(state.activeCoaches, hasLength(1));
      expect(state.activeCoaches.first.id, 'rel-1');
      expect(state.pendingRequests, hasLength(1));
      expect(state.pendingRequests.first.id, 'rel-pending');
      expect(state.hasCoaches, isTrue);
      expect(state.hasPendingRequests, isTrue);
    });

    test('empty state when no coaches and no pending requests', () async {
      when(() => coachService.getMyCoaches()).thenAnswer((_) async => []);
      when(() => coachService.getPendingCoachRequests())
          .thenAnswer((_) async => []);

      final container = _container();
      await container.read(myCoachesControllerProvider.future);
      final state = container.read(myCoachesControllerProvider).value!;

      expect(state.activeCoaches, isEmpty);
      expect(state.pendingRequests, isEmpty);
      expect(state.hasCoaches, isFalse);
      expect(state.hasPendingRequests, isFalse);
      expect(state.error, isNull);
    });

    test('error state when loading throws', () async {
      when(() => coachService.getMyCoaches())
          .thenThrow(Exception('network error'));
      when(() => coachService.getPendingCoachRequests())
          .thenAnswer((_) async => []);

      final container = _container();
      await container.read(myCoachesControllerProvider.future);
      final state = container.read(myCoachesControllerProvider).value!;

      expect(state.error, isNotNull);
      expect(state.activeCoaches, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // acceptRequest — remote-ack policy
  // -------------------------------------------------------------------------

  group('MyCoachesController.acceptRequest', () {
    test(
        'on success: moves pending request to active coaches and updates both lists',
        () async {
      final pendingRel = _makeRelationship(
        id: 'rel-pending',
        status: RelationshipStatus.pending,
        requestedBy: 'coach',
      );
      final acceptedRel = pendingRel.copyWith(status: RelationshipStatus.active);

      when(() => coachService.getMyCoaches()).thenAnswer((_) async => []);
      when(() => coachService.getPendingCoachRequests())
          .thenAnswer((_) async => [pendingRel]);
      when(() => coachService.acceptCoachRequest('rel-pending'))
          .thenAnswer((_) async => acceptedRel);

      final container = _container();
      await container.read(myCoachesControllerProvider.future);

      await container
          .read(myCoachesControllerProvider.notifier)
          .acceptRequest('rel-pending');

      final state = container.read(myCoachesControllerProvider).value!;

      expect(state.pendingRequests, isEmpty,
          reason: 'Accepted request must leave pending list');
      expect(state.activeCoaches, hasLength(1),
          reason: 'Accepted request must appear in active coaches');
      expect(state.activeCoaches.first.id, 'rel-pending');
      expect(state.error, isNull);
    });

    test(
        'BUG CHECK — remote write failure preserves pending request in list and surfaces error',
        () async {
      final pendingRel = _makeRelationship(
        id: 'rel-accept-fail',
        status: RelationshipStatus.pending,
        requestedBy: 'coach',
      );

      when(() => coachService.getMyCoaches()).thenAnswer((_) async => []);
      when(() => coachService.getPendingCoachRequests())
          .thenAnswer((_) async => [pendingRel]);
      when(() => coachService.acceptCoachRequest('rel-accept-fail'))
          .thenThrow(StateError('Failed to accept remotely'));

      final container = _container();
      await container.read(myCoachesControllerProvider.future);

      await container
          .read(myCoachesControllerProvider.notifier)
          .acceptRequest('rel-accept-fail');

      final state = container.read(myCoachesControllerProvider).value!;

      // CRITICAL: pending request must NOT disappear silently on failure
      expect(state.pendingRequests, contains(pendingRel),
          reason:
              'Remote write failure must leave pending request intact. '
              'Silently removing it hides the failure from the user.');
      expect(state.activeCoaches, isEmpty,
          reason: 'Failed accept must not add to active coaches');
      expect(state.error, isNotNull);
    });

    test(
        'BUG CHECK — acceptCoachRequest returning null does not add to active coaches',
        () async {
      // In MyCoachesController.acceptRequest, if `accepted != null` guard:
      // the code only adds to activeCoaches when accepted != null.
      // If null is returned (e.g. remote returned no data), no move should happen.
      final pendingRel = _makeRelationship(
        id: 'rel-null-return',
        status: RelationshipStatus.pending,
      );

      when(() => coachService.getMyCoaches()).thenAnswer((_) async => []);
      when(() => coachService.getPendingCoachRequests())
          .thenAnswer((_) async => [pendingRel]);
      when(() => coachService.acceptCoachRequest('rel-null-return'))
          .thenAnswer((_) async => null);

      final container = _container();
      await container.read(myCoachesControllerProvider.future);

      await container
          .read(myCoachesControllerProvider.notifier)
          .acceptRequest('rel-null-return');

      final state = container.read(myCoachesControllerProvider).value!;

      // The pending request was not moved to active (null guard)
      expect(state.activeCoaches, isEmpty);
      // No error is set either — this is ambiguous behavior worth noting
      // but the request also wasn't removed from pending (stays as-is)
    });
  });

  // -------------------------------------------------------------------------
  // declineRequest — remote-ack policy
  // -------------------------------------------------------------------------

  group('MyCoachesController.declineRequest', () {
    test('on success: removes request from pending list', () async {
      final pendingRel = _makeRelationship(
        id: 'rel-decline',
        status: RelationshipStatus.pending,
      );
      final declinedRel =
          pendingRel.copyWith(status: RelationshipStatus.declined);

      when(() => coachService.getMyCoaches()).thenAnswer((_) async => []);
      when(() => coachService.getPendingCoachRequests())
          .thenAnswer((_) async => [pendingRel]);
      when(() => coachService.declineCoachRequest('rel-decline'))
          .thenAnswer((_) async => declinedRel);

      final container = _container();
      await container.read(myCoachesControllerProvider.future);

      await container
          .read(myCoachesControllerProvider.notifier)
          .declineRequest('rel-decline');

      final state = container.read(myCoachesControllerProvider).value!;
      expect(state.pendingRequests, isEmpty);
      expect(state.error, isNull);
    });

    test(
        'BUG CHECK — remote decline failure preserves pending request and surfaces error',
        () async {
      final pendingRel = _makeRelationship(
        id: 'rel-decline-fail',
        status: RelationshipStatus.pending,
      );

      when(() => coachService.getMyCoaches()).thenAnswer((_) async => []);
      when(() => coachService.getPendingCoachRequests())
          .thenAnswer((_) async => [pendingRel]);
      when(() => coachService.declineCoachRequest('rel-decline-fail'))
          .thenThrow(StateError('Failed to decline remotely'));

      final container = _container();
      await container.read(myCoachesControllerProvider.future);

      await container
          .read(myCoachesControllerProvider.notifier)
          .declineRequest('rel-decline-fail');

      final state = container.read(myCoachesControllerProvider).value!;

      expect(state.pendingRequests, contains(pendingRel),
          reason:
              'Remote decline failure must leave pending request in list.');
      expect(state.error, isNotNull);
    });
  });

  // -------------------------------------------------------------------------
  // MyCoachesState getters
  // -------------------------------------------------------------------------

  group('MyCoachesState computed properties', () {
    test('hasCoaches is false when activeCoaches is empty', () {
      const s = MyCoachesState();
      expect(s.hasCoaches, isFalse);
    });

    test('hasCoaches is true when activeCoaches has items', () {
      final s = MyCoachesState(activeCoaches: [_makeRelationship()]);
      expect(s.hasCoaches, isTrue);
    });

    test('hasPendingRequests is false when list is empty', () {
      const s = MyCoachesState();
      expect(s.hasPendingRequests, isFalse);
    });

    test('hasPendingRequests is true when list has items', () {
      final s = MyCoachesState(
        pendingRequests: [
          _makeRelationship(status: RelationshipStatus.pending),
        ],
      );
      expect(s.hasPendingRequests, isTrue);
    });
  });

  // -------------------------------------------------------------------------
  // clearError
  // -------------------------------------------------------------------------

  group('MyCoachesController.clearError', () {
    test('clearError nulls out error without changing coach lists', () async {
      when(() => coachService.getMyCoaches())
          .thenThrow(Exception('initial error'));
      when(() => coachService.getPendingCoachRequests())
          .thenAnswer((_) async => []);

      final container = _container();
      await container.read(myCoachesControllerProvider.future);

      var state = container.read(myCoachesControllerProvider).value!;
      expect(state.error, isNotNull);

      container.read(myCoachesControllerProvider.notifier).clearError();

      state = container.read(myCoachesControllerProvider).value!;
      expect(state.error, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // refresh
  // -------------------------------------------------------------------------

  group('MyCoachesController.refresh', () {
    test('refresh reloads coaches and transitions through states', () async {
      when(() => coachService.getMyCoaches()).thenAnswer((_) async => []);
      when(() => coachService.getPendingCoachRequests())
          .thenAnswer((_) async => []);

      final container = _container();
      await container.read(myCoachesControllerProvider.future);

      // Add a coach for refresh
      final newCoach = _makeRelationship(id: 'new-coach');
      when(() => coachService.getMyCoaches())
          .thenAnswer((_) async => [newCoach]);

      await container
          .read(myCoachesControllerProvider.notifier)
          .refresh();

      final state = container.read(myCoachesControllerProvider).value!;
      expect(state.activeCoaches, hasLength(1));
      expect(state.activeCoaches.first.id, 'new-coach');
    });
  });
}
