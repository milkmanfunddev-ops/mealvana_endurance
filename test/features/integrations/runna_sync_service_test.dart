// Tests for RunnaSyncService reconciliation logic.
//
// Coverage goals:
// 1. Not-connected guard (missing / inactive integration row)
// 2. New feed events → insertActivity (strength events filtered)
// 3. Changed events → updateActivityFromProvider
// 4. Rolling-window deletion rule:
//    - missing UID INSIDE the observed feed window → soft-delete
//    - missing UID OUTSIDE the window → untouched (window just moved)
//    - past activities → never touched
//    - providerDeletedAt != null → never re-deleted (ChangeDetectionService
//      guard, the provider re-delete churn regression)
//    - empty feed → no window → nothing deleted
// 5. UID-churn fingerprint fallback: unknown incoming UID + same-day
//    same-title local → update in place (adopt new UID), no duplicate insert
// 6. Network vs API error handling
//
// The client is mocked (returns fixture ICS text); the parser, transformer,
// and change-detection service are REAL so reconciliation is tested
// end-to-end from feed text to repository calls.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:mealvana_endurance/features/activities/data/activities_repository.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/integrations/application/change_detection_service.dart';
import 'package:mealvana_endurance/features/integrations/application/runna_ics_parser.dart';
import 'package:mealvana_endurance/features/integrations/application/runna_sync_service.dart';
import 'package:mealvana_endurance/features/integrations/application/runna_transformer.dart';
import 'package:mealvana_endurance/features/integrations/data/integrations_repository.dart';
import 'package:mealvana_endurance/features/integrations/data/runna_ics_client.dart';
import 'package:mealvana_endurance/features/integrations/domain/integration.dart';
import 'package:mealvana_endurance/features/integrations/domain/integration_exceptions.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

// ---------------------------------------------------------------------------
// Mocks and fakes
// ---------------------------------------------------------------------------

class MockRunnaIcsClient extends Mock implements RunnaIcsClient {}

class MockIntegrationsRepository extends Mock
    implements IntegrationsRepository {}

class MockActivitiesRepository extends Mock implements ActivitiesRepository {}

class _FakeActivity extends Fake implements Activity {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _userId = 'test-user-123';
const _provider = 'runna';
const _feedUrl = 'https://cal.runna.com/feed/abc123.ics';

IntegrationModel _activeIntegration({bool isActive = true}) => IntegrationModel(
  userId: _userId,
  provider: _provider,
  accessToken: _feedUrl,
  providerAthleteId: 'runna-abc123',
  isActive: isActive,
);

/// Date-only anchor N days from today (local).
DateTime _day(int offset) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day).add(Duration(days: offset));
}

String _icsDate(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}'
    '${day.month.toString().padLeft(2, '0')}'
    '${day.day.toString().padLeft(2, '0')}';

String _vevent({
  required String uid,
  required DateTime day,
  required String summary,
  int? estimatedDurationSeconds,
}) =>
    'BEGIN:VEVENT\r\n'
    'UID:$uid\r\n'
    'DTSTART;VALUE=DATE:${_icsDate(day)}\r\n'
    'SUMMARY:$summary\r\n'
    '${estimatedDurationSeconds != null ? 'X-WORKOUT-ESTIMATED-DURATION:$estimatedDurationSeconds\r\n' : ''}'
    'END:VEVENT\r\n';

String _calendar(List<String> vevents) =>
    'BEGIN:VCALENDAR\r\nVERSION:2.0\r\n${vevents.join()}END:VCALENDAR\r\n';

Activity _localActivity({
  required String id,
  required String providerWorkoutId,
  required DateTime scheduledDateTime,
  String title = 'Easy Run',
  int? durationMinutes,
  DateTime? providerDeletedAt,
  ActivityStatus status = ActivityStatus.planned,
}) => Activity(
  id: id,
  userId: _userId,
  activityType: ActivityType.running,
  title: title,
  scheduledDateTime: scheduledDateTime,
  status: status,
  durationMinutes: durationMinutes,
  providerWorkoutId: providerWorkoutId,
  syncedFromProvider: _provider,
  providerDeletedAt: providerDeletedAt,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeActivity());
  });

  late MockRunnaIcsClient mockClient;
  late MockIntegrationsRepository mockIntegrationsRepo;
  late MockActivitiesRepository mockActivitiesRepo;
  late RunnaSyncService service;

  setUp(() {
    mockClient = MockRunnaIcsClient();
    mockIntegrationsRepo = MockIntegrationsRepository();
    mockActivitiesRepo = MockActivitiesRepository();

    // Real parser/transformer/change-detection: reconciliation is exercised
    // end-to-end from ICS text to repository calls.
    service = RunnaSyncService(
      icsClient: mockClient,
      parser: const RunnaIcsParser(),
      integrationsRepository: mockIntegrationsRepo,
      activitiesRepository: mockActivitiesRepo,
      transformer: const RunnaTransformer(),
      changeDetectionService: ChangeDetectionService(),
    );

    final stubActivity = _localActivity(
      id: 'stub',
      providerWorkoutId: 'stub-pid',
      scheduledDateTime: _day(1),
    );

    when(
      () => mockIntegrationsRepo.getIntegration(_userId, _provider),
    ).thenAnswer((_) async => _activeIntegration());
    when(
      () => mockIntegrationsRepo.updateSyncStatus(
        any(),
        any(),
        status: any(named: 'status'),
        error: any(named: 'error'),
      ),
    ).thenAnswer((_) async {});

    when(
      () => mockActivitiesRepo.insertActivity(any()),
    ).thenAnswer((_) async => stubActivity);
    when(
      () => mockActivitiesRepo.updateActivityFromProvider(any()),
    ).thenAnswer((_) async => stubActivity);
    when(
      () => mockActivitiesRepo.softDeleteFromProvider(any()),
    ).thenAnswer((_) async {});
    when(
      () => mockActivitiesRepo.getActivitiesByUserAndProvider(any(), any()),
    ).thenAnswer((_) async => []);
    when(
      () => mockActivitiesRepo.cleanupDuplicateProviderActivities(
        userId: any(named: 'userId'),
        provider: any(named: 'provider'),
      ),
    ).thenAnswer((_) async => 0);
  });

  group('not connected', () {
    test('returns notConnected when no integration row exists', () async {
      when(
        () => mockIntegrationsRepo.getIntegration(_userId, _provider),
      ).thenAnswer((_) async => null);

      final result = await service.syncWorkouts(_userId);

      expect(result.success, isFalse);
      expect(result.errorType, RunnaSyncErrorType.notConnected);
      verifyNever(() => mockClient.fetchIcs(any()));
    });

    test('returns notConnected when the integration is inactive', () async {
      when(
        () => mockIntegrationsRepo.getIntegration(_userId, _provider),
      ).thenAnswer((_) async => _activeIntegration(isActive: false));

      final result = await service.syncWorkouts(_userId);

      expect(result.success, isFalse);
      expect(result.errorType, RunnaSyncErrorType.notConnected);
    });
  });

  group('new events', () {
    test('inserts new run events and filters strength sessions', () async {
      final ics = _calendar([
        _vevent(
          uid: 'evt-a',
          day: _day(2),
          summary: '🏃 Easy Run • 6mi • 50m - 55m',
          estimatedDurationSeconds: 3120,
        ),
        _vevent(uid: 'evt-b', day: _day(4), summary: '🏃 Tempo Run • 45m'),
        _vevent(
          uid: 'evt-c',
          day: _day(5),
          summary: '💪 Strength & Conditioning • 30m',
        ),
      ]);
      when(() => mockClient.fetchIcs(_feedUrl)).thenAnswer((_) async => ics);

      final result = await service.syncWorkouts(_userId);

      expect(result.success, isTrue);
      expect(result.newWorkouts, 2);
      expect(result.filtered, 1); // strength skipped
      expect(result.deleted, 0);
      verify(() => mockActivitiesRepo.insertActivity(any())).called(2);
      verify(
        () => mockIntegrationsRepo.updateSyncStatus(
          _userId,
          _provider,
          status: 'success',
        ),
      ).called(1);
    });

    test('dedupes repeated UIDs within one feed payload', () async {
      final ics = _calendar([
        _vevent(uid: 'evt-a', day: _day(2), summary: 'Easy Run • 6mi'),
        _vevent(uid: 'evt-a', day: _day(2), summary: 'Easy Run • 6mi'),
      ]);
      when(() => mockClient.fetchIcs(_feedUrl)).thenAnswer((_) async => ics);

      final result = await service.syncWorkouts(_userId);

      expect(result.newWorkouts, 1);
      expect(result.filtered, 1);
      verify(() => mockActivitiesRepo.insertActivity(any())).called(1);
    });
  });

  group('changed events', () {
    test(
      'updates the existing activity when the feed content changes',
      () async {
        final local = _localActivity(
          id: 'local-a-id',
          providerWorkoutId: 'evt-a',
          scheduledDateTime: _day(2).add(const Duration(hours: 6)),
          title: 'Easy Run',
          durationMinutes: 40,
        );
        when(
          () => mockActivitiesRepo.getActivitiesByUserAndProvider(
            _userId,
            _provider,
          ),
        ).thenAnswer((_) async => [local]);

        final ics = _calendar([
          _vevent(
            uid: 'evt-a',
            day: _day(2),
            summary: '🏃 Easy Run • 6mi • 50m',
            estimatedDurationSeconds: 3000, // 50 min ≠ local 40 min
          ),
        ]);
        when(() => mockClient.fetchIcs(_feedUrl)).thenAnswer((_) async => ics);

        final result = await service.syncWorkouts(_userId);

        expect(result.success, isTrue);
        expect(result.newWorkouts, 0);
        expect(result.updated, 1);
        final captured = verify(
          () => mockActivitiesRepo.updateActivityFromProvider(captureAny()),
        ).captured;
        expect(captured, hasLength(1));
        final updated = captured.single as Activity;
        expect(updated.id, 'local-a-id');
        expect(updated.providerWorkoutId, 'evt-a');
        verifyNever(() => mockActivitiesRepo.insertActivity(any()));
      },
    );
  });

  group('rolling-window deletion', () {
    test(
      'soft-deletes future planned activities missing INSIDE the window, '
      'leaves outside-window / past / provider-deleted rows untouched',
      () async {
        // Feed window: day+2 .. day+10.
        final ics = _calendar([
          _vevent(uid: 'evt-a', day: _day(2), summary: 'Easy Run • 6mi'),
          _vevent(uid: 'evt-b', day: _day(10), summary: 'Long Run • 10mi'),
        ]);
        when(() => mockClient.fetchIcs(_feedUrl)).thenAnswer((_) async => ics);

        final locals = [
          // Missing inside the window → soft-delete.
          _localActivity(
            id: 'ghost-in-id',
            providerWorkoutId: 'ghost-in',
            scheduledDateTime: _day(5).add(const Duration(hours: 6)),
            title: 'Ghost Run In Window',
          ),
          // Missing OUTSIDE the window (beyond max event date) → the window
          // just doesn't reach that far; must be untouched.
          _localActivity(
            id: 'ghost-out-id',
            providerWorkoutId: 'ghost-out',
            scheduledDateTime: _day(20).add(const Duration(hours: 6)),
            title: 'Ghost Run Beyond Window',
          ),
          // Past activity absent from a rolling feed → NOT a deletion.
          _localActivity(
            id: 'ghost-past-id',
            providerWorkoutId: 'ghost-past',
            scheduledDateTime: _day(-3).add(const Duration(hours: 6)),
            title: 'Old Completed-Window Run',
          ),
          // Already soft-deleted from the provider → never re-deleted
          // (ChangeDetectionService guard, re-delete churn regression).
          _localActivity(
            id: 'ghost-deleted-id',
            providerWorkoutId: 'ghost-deleted',
            scheduledDateTime: _day(6).add(const Duration(hours: 6)),
            title: 'Previously Deleted Run',
            providerDeletedAt: DateTime(2026, 1, 2),
          ),
        ];
        when(
          () => mockActivitiesRepo.getActivitiesByUserAndProvider(
            _userId,
            _provider,
          ),
        ).thenAnswer((_) async => locals);

        final result = await service.syncWorkouts(_userId);

        expect(result.success, isTrue);
        expect(result.deleted, 1);
        verify(
          () => mockActivitiesRepo.softDeleteFromProvider('ghost-in-id'),
        ).called(1);
        verifyNever(
          () => mockActivitiesRepo.softDeleteFromProvider('ghost-out-id'),
        );
        verifyNever(
          () => mockActivitiesRepo.softDeleteFromProvider('ghost-past-id'),
        );
        verifyNever(
          () => mockActivitiesRepo.softDeleteFromProvider('ghost-deleted-id'),
        );
      },
    );

    test('never touches completed activities even inside the window', () async {
      final ics = _calendar([
        _vevent(uid: 'evt-a', day: _day(2), summary: 'Easy Run • 6mi'),
        _vevent(uid: 'evt-b', day: _day(10), summary: 'Long Run • 10mi'),
      ]);
      when(() => mockClient.fetchIcs(_feedUrl)).thenAnswer((_) async => ics);

      when(
        () => mockActivitiesRepo.getActivitiesByUserAndProvider(
          _userId,
          _provider,
        ),
      ).thenAnswer(
        (_) async => [
          _localActivity(
            id: 'done-id',
            providerWorkoutId: 'gone-uid',
            scheduledDateTime: _day(5).add(const Duration(hours: 6)),
            title: 'Completed Run',
            status: ActivityStatus.completed,
          ),
        ],
      );

      final result = await service.syncWorkouts(_userId);

      expect(result.deleted, 0);
      verifyNever(() => mockActivitiesRepo.softDeleteFromProvider(any()));
    });

    test('an empty feed defines no window and deletes nothing', () async {
      when(() => mockClient.fetchIcs(_feedUrl)).thenAnswer(
        (_) async => 'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nEND:VCALENDAR\r\n',
      );

      when(
        () => mockActivitiesRepo.getActivitiesByUserAndProvider(
          _userId,
          _provider,
        ),
      ).thenAnswer(
        (_) async => [
          _localActivity(
            id: 'future-id',
            providerWorkoutId: 'future-uid',
            scheduledDateTime: _day(5).add(const Duration(hours: 6)),
          ),
        ],
      );

      final result = await service.syncWorkouts(_userId);

      expect(result.success, isTrue);
      expect(result.deleted, 0);
      verifyNever(() => mockActivitiesRepo.softDeleteFromProvider(any()));
    });
  });

  group('UID churn fingerprint fallback', () {
    test('adopts the new UID onto a same-day same-title local instead of '
        'duplicating', () async {
      // Local was imported under the OLD uid; plan regeneration reissued it.
      final local = _localActivity(
        id: 'local-easy-id',
        providerWorkoutId: 'old-uid-1',
        scheduledDateTime: _day(3).add(const Duration(hours: 6)),
        title: 'Easy Run',
        durationMinutes: 40,
      );
      when(
        () => mockActivitiesRepo.getActivitiesByUserAndProvider(
          _userId,
          _provider,
        ),
      ).thenAnswer((_) async => [local]);

      final ics = _calendar([
        _vevent(
          uid: 'new-uid-1',
          day: _day(3),
          summary: '🏃 Easy Run • 6mi • 50m',
          estimatedDurationSeconds: 3000,
        ),
      ]);
      when(() => mockClient.fetchIcs(_feedUrl)).thenAnswer((_) async => ics);

      final result = await service.syncWorkouts(_userId);

      expect(result.success, isTrue);
      expect(result.newWorkouts, 0, reason: 'must not insert a duplicate');
      expect(result.updated, 1);
      expect(result.deleted, 0);
      verifyNever(() => mockActivitiesRepo.insertActivity(any()));
      verifyNever(() => mockActivitiesRepo.softDeleteFromProvider(any()));

      final captured = verify(
        () => mockActivitiesRepo.updateActivityFromProvider(captureAny()),
      ).captured;
      final updated = captured.single as Activity;
      expect(updated.id, 'local-easy-id');
      expect(
        updated.providerWorkoutId,
        'new-uid-1',
        reason: 'the new UID must be adopted',
      );
    });

    test('a different-title unknown UID is a genuine new workout', () async {
      final local = _localActivity(
        id: 'local-easy-id',
        providerWorkoutId: 'old-uid-1',
        scheduledDateTime: _day(20).add(const Duration(hours: 6)),
        title: 'Easy Run',
      );
      when(
        () => mockActivitiesRepo.getActivitiesByUserAndProvider(
          _userId,
          _provider,
        ),
      ).thenAnswer((_) async => [local]);

      final ics = _calendar([
        _vevent(uid: 'new-uid-2', day: _day(3), summary: '🏃 Tempo Run • 45m'),
      ]);
      when(() => mockClient.fetchIcs(_feedUrl)).thenAnswer((_) async => ics);

      final result = await service.syncWorkouts(_userId);

      expect(result.newWorkouts, 1);
      verify(() => mockActivitiesRepo.insertActivity(any())).called(1);
      // The stale local sits outside the (single-day) window → untouched.
      verifyNever(() => mockActivitiesRepo.softDeleteFromProvider(any()));
    });
  });

  group('errors', () {
    test('network errors return a retryable result without stamping an error '
        'status', () async {
      when(
        () => mockClient.fetchIcs(_feedUrl),
      ).thenThrow(const NetworkException('offline', provider: _provider));

      final result = await service.syncWorkouts(_userId);

      expect(result.success, isFalse);
      expect(result.isNetworkError, isTrue);
      verifyNever(
        () => mockIntegrationsRepo.updateSyncStatus(
          any(),
          any(),
          status: any(named: 'status'),
          error: any(named: 'error'),
        ),
      );
    });

    test('feed/API errors stamp an error sync status', () async {
      when(() => mockClient.fetchIcs(_feedUrl)).thenThrow(
        const IntegrationApiException(
          'not a calendar',
          statusCode: 404,
          provider: _provider,
        ),
      );

      final result = await service.syncWorkouts(_userId);

      expect(result.success, isFalse);
      expect(result.errorType, RunnaSyncErrorType.apiError);
      verify(
        () => mockIntegrationsRepo.updateSyncStatus(
          _userId,
          _provider,
          status: 'error',
          error: 'not a calendar',
        ),
      ).called(1);
    });
  });
}
