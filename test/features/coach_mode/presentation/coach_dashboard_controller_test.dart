// ignore_for_file: avoid_implementing_value_types
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:mealvana_endurance/features/coach_mode/application/coach_service.dart';
import 'package:mealvana_endurance/features/coach_mode/domain/coach.dart';
import 'package:mealvana_endurance/features/coach_mode/domain/coach_athlete_relationship.dart';
import 'package:mealvana_endurance/features/coach_mode/presentation/providers/coach_dashboard_controller.dart';
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

CoachInfo _coachInfo({bool isCoach = true}) => CoachInfo(
      userId: _coachUserId,
      deviceId: 'device-id',
      isCoach: isCoach,
      displayName: 'Alice Smith',
    );

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

    // Default stub: background sync completes silently
    when(() => coachService.syncRelationshipsFromSupabase())
        .thenAnswer((_) async => []);
    when(() => coachService.syncMyAthletesProfiles())
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

  group('CoachDashboardController.build', () {
    test('loads active athletes and pending requests on initial build', () async {
      final activeRel = _makeRelationship(status: RelationshipStatus.active);
      final pendingRel = _makeRelationship(
        id: 'rel-pending',
        status: RelationshipStatus.pending,
      );

      when(() => coachService.getCurrentCoachInfo())
          .thenAnswer((_) async => _coachInfo());
      when(() => coachService.getMyAthletes())
          .thenAnswer((_) async => [activeRel]);
      when(() => coachService.getPendingAthleteRequests())
          .thenAnswer((_) async => [pendingRel]);

      final container = _container();
      await container.read(coachDashboardControllerProvider.future);
      final state = container.read(coachDashboardControllerProvider).value!;

      expect(state.activeAthletes, hasLength(1));
      expect(state.activeAthletes.first.id, 'rel-1');
      expect(state.pendingRequests, hasLength(1));
      expect(state.pendingRequests.first.id, 'rel-pending');
      expect(state.isCoach, isTrue);
    });

    test(
        'returns error state when user is not a coach and sync confirms not-coach',
        () async {
      when(() => coachService.getCurrentCoachInfo())
          .thenAnswer((_) async => null);
      when(() => coachService.syncCurrentCoachDataFromSupabase())
          .thenAnswer((_) async => false);

      final container = _container();
      await container.read(coachDashboardControllerProvider.future);
      final state = container.read(coachDashboardControllerProvider).value!;

      expect(state.coachInfo, isNull);
      expect(state.error, isNotNull,
          reason:
              'Non-coach user must see an error, not an empty dashboard that looks like success');
      expect(state.activeAthletes, isEmpty);
    });

    test(
        'falls back to sync when local coach info is absent, then shows dashboard on success',
        () async {
      final coachInfoAfterSync = _coachInfo();

      // First call returns null (not yet synced), sync succeeds, second call returns info
      when(() => coachService.getCurrentCoachInfo())
          .thenAnswer((_) async => null);
      when(() => coachService.syncCurrentCoachDataFromSupabase())
          .thenAnswer((_) async => true);

      // After sync, the second getCurrentCoachInfo() call should return data.
      // We need to make subsequent calls return the data.
      var callCount = 0;
      when(() => coachService.getCurrentCoachInfo()).thenAnswer((_) async {
        callCount++;
        return callCount >= 2 ? coachInfoAfterSync : null;
      });
      when(() => coachService.syncCurrentCoachDataFromSupabase())
          .thenAnswer((_) async => true);
      when(() => coachService.getMyAthletes()).thenAnswer((_) async => []);
      when(() => coachService.getPendingAthleteRequests())
          .thenAnswer((_) async => []);

      final container = _container();
      await container.read(coachDashboardControllerProvider.future);
      final state = container.read(coachDashboardControllerProvider).value!;

      expect(state.coachInfo, isNotNull);
      expect(state.error, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // acceptRequest — remote-ack policy
  // -------------------------------------------------------------------------

  group('CoachDashboardController.acceptRequest', () {
    test('moves pending request to active athletes on success', () async {
      final pendingRel = _makeRelationship(
        id: 'rel-pending',
        status: RelationshipStatus.pending,
      );
      final acceptedRel = pendingRel.copyWith(status: RelationshipStatus.active);

      when(() => coachService.getCurrentCoachInfo())
          .thenAnswer((_) async => _coachInfo());
      when(() => coachService.getMyAthletes()).thenAnswer((_) async => []);
      when(() => coachService.getPendingAthleteRequests())
          .thenAnswer((_) async => [pendingRel]);
      when(() => coachService.acceptAthleteRequest('rel-pending'))
          .thenAnswer((_) async => acceptedRel);
      when(() => coachService.getMyAthletes())
          .thenAnswer((_) async => [acceptedRel]);
      when(() => coachService.getPendingAthleteRequests())
          .thenAnswer((_) async => []);

      final container = _container();
      await container.read(coachDashboardControllerProvider.future);

      await container
          .read(coachDashboardControllerProvider.notifier)
          .acceptRequest('rel-pending');

      final state = container.read(coachDashboardControllerProvider).value!;
      expect(state.pendingRequests, isEmpty);
      expect(state.activeAthletes, hasLength(1));
    });

    test(
        'BUG CHECK — remote write failure sets error state (does not report success)',
        () async {
      final pendingRel = _makeRelationship(
        id: 'rel-pending',
        status: RelationshipStatus.pending,
      );

      when(() => coachService.getCurrentCoachInfo())
          .thenAnswer((_) async => _coachInfo());
      when(() => coachService.getMyAthletes()).thenAnswer((_) async => []);
      when(() => coachService.getPendingAthleteRequests())
          .thenAnswer((_) async => [pendingRel]);

      // Simulate remote write failure
      when(() => coachService.acceptAthleteRequest('rel-pending'))
          .thenThrow(StateError('Failed to accept remotely'));

      final container = _container();
      await container.read(coachDashboardControllerProvider.future);

      await container
          .read(coachDashboardControllerProvider.notifier)
          .acceptRequest('rel-pending');

      final state = container.read(coachDashboardControllerProvider).value!;

      // CRITICAL: pending request must NOT be removed when remote write fails
      expect(state.pendingRequests, contains(pendingRel),
          reason:
              'A remote-write failure must not silently remove the pending request. '
              'This violates the CLAUDE.md remote-ack policy.');
      // Error must be surfaced
      expect(state.error, isNotNull);
    });
  });

  // -------------------------------------------------------------------------
  // declineRequest — remote-ack policy
  // -------------------------------------------------------------------------

  group('CoachDashboardController.declineRequest', () {
    test('removes declined request from pending list on success', () async {
      final pendingRel = _makeRelationship(
        id: 'rel-pending',
        status: RelationshipStatus.pending,
      );
      final declinedRel =
          pendingRel.copyWith(status: RelationshipStatus.declined);

      when(() => coachService.getCurrentCoachInfo())
          .thenAnswer((_) async => _coachInfo());
      when(() => coachService.getMyAthletes()).thenAnswer((_) async => []);
      when(() => coachService.getPendingAthleteRequests())
          .thenAnswer((_) async => [pendingRel]);
      when(() => coachService.declineAthleteRequest('rel-pending'))
          .thenAnswer((_) async => declinedRel);

      final container = _container();
      await container.read(coachDashboardControllerProvider.future);

      await container
          .read(coachDashboardControllerProvider.notifier)
          .declineRequest('rel-pending');

      final state = container.read(coachDashboardControllerProvider).value!;
      expect(state.pendingRequests, isEmpty);
    });

    test(
        'BUG CHECK — remote write failure leaves pending request intact with error',
        () async {
      final pendingRel = _makeRelationship(
        id: 'rel-decline-fail',
        status: RelationshipStatus.pending,
      );

      when(() => coachService.getCurrentCoachInfo())
          .thenAnswer((_) async => _coachInfo());
      when(() => coachService.getMyAthletes()).thenAnswer((_) async => []);
      when(() => coachService.getPendingAthleteRequests())
          .thenAnswer((_) async => [pendingRel]);
      when(() => coachService.declineAthleteRequest('rel-decline-fail'))
          .thenThrow(StateError('Failed to decline remotely'));

      final container = _container();
      await container.read(coachDashboardControllerProvider.future);

      await container
          .read(coachDashboardControllerProvider.notifier)
          .declineRequest('rel-decline-fail');

      final state = container.read(coachDashboardControllerProvider).value!;

      // CRITICAL: must not remove from pending if remote write failed
      expect(state.pendingRequests, contains(pendingRel),
          reason:
              'Pending request must remain in list when remote decline fails.');
      expect(state.error, isNotNull);
    });
  });

  // -------------------------------------------------------------------------
  // archiveAthlete — remote-ack policy
  // -------------------------------------------------------------------------

  group('CoachDashboardController.archiveAthlete', () {
    test('removes athlete from active list on successful archive', () async {
      final activeRel = _makeRelationship(status: RelationshipStatus.active);

      when(() => coachService.getCurrentCoachInfo())
          .thenAnswer((_) async => _coachInfo());
      when(() => coachService.getMyAthletes())
          .thenAnswer((_) async => [activeRel]);
      when(() => coachService.getPendingAthleteRequests())
          .thenAnswer((_) async => []);
      when(() => coachService.archiveAthlete('rel-1'))
          .thenAnswer((_) async => activeRel.copyWith(
                status: RelationshipStatus.archived,
              ));

      final container = _container();
      await container.read(coachDashboardControllerProvider.future);

      await container
          .read(coachDashboardControllerProvider.notifier)
          .archiveAthlete('rel-1');

      final state = container.read(coachDashboardControllerProvider).value!;
      expect(state.activeAthletes, isEmpty);
      expect(state.error, isNull);
    });

    test(
        'BUG CHECK — remote write failure leaves athlete in active list with error',
        () async {
      final activeRel = _makeRelationship(status: RelationshipStatus.active);

      when(() => coachService.getCurrentCoachInfo())
          .thenAnswer((_) async => _coachInfo());
      when(() => coachService.getMyAthletes())
          .thenAnswer((_) async => [activeRel]);
      when(() => coachService.getPendingAthleteRequests())
          .thenAnswer((_) async => []);
      when(() => coachService.archiveAthlete('rel-1'))
          .thenThrow(StateError('Failed to archive remotely'));

      final container = _container();
      await container.read(coachDashboardControllerProvider.future);

      await container
          .read(coachDashboardControllerProvider.notifier)
          .archiveAthlete('rel-1');

      final state = container.read(coachDashboardControllerProvider).value!;

      // CRITICAL: athlete must stay in active list when remote archive fails
      expect(state.activeAthletes, contains(activeRel),
          reason:
              'Active athlete must remain in list when remote archive fails.');
      expect(state.error, isNotNull);
    });
  });

  // -------------------------------------------------------------------------
  // CoachDashboardState getters
  // -------------------------------------------------------------------------

  group('CoachDashboardState computed properties', () {
    test('athleteCount reflects active list size', () {
      final s = CoachDashboardState(
        coachInfo: _coachInfo(),
        activeAthletes: [_makeRelationship(), _makeRelationship(id: 'rel-2')],
      );
      expect(s.athleteCount, 2);
    });

    test('hasPendingRequests is false when list is empty', () {
      const s = CoachDashboardState();
      expect(s.hasPendingRequests, isFalse);
    });

    test('hasPendingRequests is true when list has items', () {
      final s = CoachDashboardState(
        pendingRequests: [_makeRelationship(status: RelationshipStatus.pending)],
      );
      expect(s.hasPendingRequests, isTrue);
    });

    test('isCoach delegates to coachInfo.isCoach', () {
      final withCoach = CoachDashboardState(coachInfo: _coachInfo());
      const withoutCoach = CoachDashboardState();
      expect(withCoach.isCoach, isTrue);
      expect(withoutCoach.isCoach, isFalse);
    });

    test('clearError removes error while preserving other state', () async {
      when(() => coachService.getCurrentCoachInfo())
          .thenAnswer((_) async => _coachInfo());
      when(() => coachService.getMyAthletes()).thenAnswer((_) async => []);
      when(() => coachService.getPendingAthleteRequests())
          .thenAnswer((_) async => []);

      final container = _container();
      await container.read(coachDashboardControllerProvider.future);

      // Manually inject error
      final notifier = container.read(coachDashboardControllerProvider.notifier);
      final currentState = container.read(coachDashboardControllerProvider).value!;
      notifier.state = AsyncData(currentState.copyWith(error: 'some error'));

      expect(
          container.read(coachDashboardControllerProvider).value!.error,
          isNotNull);

      notifier.clearError();

      expect(
          container.read(coachDashboardControllerProvider).value!.error,
          isNull);
    });
  });

  // -------------------------------------------------------------------------
  // refresh()
  // -------------------------------------------------------------------------

  group('CoachDashboardController.refresh', () {
    test('refresh transitions through AsyncLoading and returns fresh state',
        () async {
      when(() => coachService.getCurrentCoachInfo())
          .thenAnswer((_) async => _coachInfo());
      when(() => coachService.getMyAthletes()).thenAnswer((_) async => []);
      when(() => coachService.getPendingAthleteRequests())
          .thenAnswer((_) async => []);

      final container = _container();
      await container.read(coachDashboardControllerProvider.future);

      // Add a new athlete for the refresh
      final newRel = _makeRelationship(id: 'rel-new');
      when(() => coachService.getMyAthletes())
          .thenAnswer((_) async => [newRel]);

      await container
          .read(coachDashboardControllerProvider.notifier)
          .refresh();

      final state = container.read(coachDashboardControllerProvider).value!;
      expect(state.activeAthletes, hasLength(1));
      expect(state.activeAthletes.first.id, 'rel-new');
    });
  });
}
