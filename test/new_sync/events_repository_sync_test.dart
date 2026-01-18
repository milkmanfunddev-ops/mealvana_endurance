import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/events/data/events_repository.dart';
import 'package:mealvana_endurance/features/events/domain/event.dart' as domain;
import 'package:mealvana_endurance/shared/data/syncable_repository.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/features/carb_loading/data/carb_loading_repository.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:matcher/matcher.dart' as matcher;

// Mocks
class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockSupabaseQueryBuilder extends Mock implements SupabaseQueryBuilder {}

class MockPostgrestFilterBuilder extends Mock
    implements PostgrestFilterBuilder<List<Map<String, dynamic>>> {}

class MockAppLogger extends Mock implements AppLogger {}

class MockCarbLoadingRepository extends Mock implements CarbLoadingRepository {}

void main() {
  late AppDatabase database;
  late MockAppLogger mockLogger;
  late MockCarbLoadingRepository mockCarbLoadingRepository;

  const testUserId = 'test-user-123';

  setUp(() async {
    // Initialize SharedPreferences for testing
    SharedPreferences.setMockInitialValues({});

    // Create in-memory database
    database = AppDatabase.forTesting(NativeDatabase.memory());

    // Create mocks
    mockLogger = MockAppLogger();
    mockCarbLoadingRepository = MockCarbLoadingRepository();

    // Set up logger to not throw on method calls
    when(() => mockLogger.info(any(), context: any(named: 'context'), data: any(named: 'data')))
        .thenReturn(null);
    when(() => mockLogger.debug(any(), context: any(named: 'context'), data: any(named: 'data')))
        .thenReturn(null);
    when(() => mockLogger.error(
          any(),
          context: any(named: 'context'),
          error: any(named: 'error'),
          stackTrace: any(named: 'stackTrace'),
          data: any(named: 'data'),
        )).thenReturn(null);
    when(() => mockLogger.warning(
          any(),
          context: any(named: 'context'),
          error: any(named: 'error'),
          data: any(named: 'data'),
        )).thenReturn(null);
  });

  tearDown(() async {
    await database.close();
  });

  group('SyncableRepository Interface', () {
    test('repositoryKey should return "events"', () {
      final mockSupabase = MockSupabaseClient();
      final repository = EventsRepository(
        supabase: mockSupabase,
        database: database,
        logger: mockLogger,
        carbLoadingRepository: mockCarbLoadingRepository,
      );

      expect(repository.repositoryKey, 'events');
    });

    test('dependencies should return ["users"]', () {
      final mockSupabase = MockSupabaseClient();
      final repository = EventsRepository(
        supabase: mockSupabase,
        database: database,
        logger: mockLogger,
        carbLoadingRepository: mockCarbLoadingRepository,
      );

      expect(repository.dependencies, ['users']);
    });

    test('isStale should return true when never synced', () async {
      final mockSupabase = MockSupabaseClient();
      final repository = EventsRepository(
        supabase: mockSupabase,
        database: database,
        logger: mockLogger,
        carbLoadingRepository: mockCarbLoadingRepository,
      );

      final isStale = await repository.isStale();
      expect(isStale, true);
    });

    test('isStale should return false when synced recently', () async {
      final mockSupabase = MockSupabaseClient();
      final repository = EventsRepository(
        supabase: mockSupabase,
        database: database,
        logger: mockLogger,
        carbLoadingRepository: mockCarbLoadingRepository,
      );

      await repository.setLastSyncTime(DateTime.now());
      final isStale = await repository.isStale();
      expect(isStale, false);
    });

    test('isStale should return true when synced more than 24 hours ago',
        () async {
      final mockSupabase = MockSupabaseClient();
      final repository = EventsRepository(
        supabase: mockSupabase,
        database: database,
        logger: mockLogger,
        carbLoadingRepository: mockCarbLoadingRepository,
      );

      final oldSync = DateTime.now().subtract(const Duration(hours: 25));
      await repository.setLastSyncTime(oldSync);
      final isStale = await repository.isStale();
      expect(isStale, true);
    });
  });

  group('syncFromRemote', () {
    test('should sync events from Supabase and save to Drift', () async {
      // Arrange
      final mockSupabase = MockSupabaseClient();
      final mockQueryBuilder = MockSupabaseQueryBuilder();
      final mockFilterBuilder = MockPostgrestFilterBuilder();

      final repository = EventsRepository(
        supabase: mockSupabase,
        database: database,
        logger: mockLogger,
        carbLoadingRepository: mockCarbLoadingRepository,
      );

      final testEvents = [
        {
          'id': 'event-1',
          'user_id': testUserId,
          'activity_id': null,
          'event_type': 'running',
          'event_subtype': 'road',
          'event_name': 'Test Marathon',
          'location': 'Test City',
          'registration_url': null,
          'event_date': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
          'start_time': '08:00:00',
          'goal_time_minutes': 240,
          'goal_pace_minutes_per_mile': 9.0,
          'predicted_finish_time_minutes': null,
          'has_carb_loading': false,
          'carb_loading_days': null,
          'carb_loading_start_date': null,
          'has_nutrition_plan': false,
          'bib_number': null,
          'wave_start_time': null,
          'packet_pickup_info': null,
          'actual_finish_time_minutes': null,
          'final_placement': null,
          'age_group_placement': null,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
      ];

      // Mock Supabase chain
      when(() => mockSupabase.from('events')).thenReturn(mockQueryBuilder);
      when(() => mockQueryBuilder.select('*')).thenReturn(mockFilterBuilder);
      when(() => mockFilterBuilder.eq('user_id', testUserId))
          .thenReturn(mockFilterBuilder);
      when(() => mockFilterBuilder.order('created_at', ascending: false))
          .thenAnswer((_) async => testEvents);

      // Act
      final result = await repository.syncFromRemote(testUserId);

      // Assert
      expect(result.success, true);
      expect(result.count, 1);

      // Verify data was saved to Drift
      final savedEvents = await database.select(database.eventsTable).get();
      expect(savedEvents.length, 1);
      expect(savedEvents.first.id, 'event-1');
      expect(savedEvents.first.eventName, 'Test Marathon');
      expect(savedEvents.first.needsUpload, false);
    });

    test('should handle empty response from Supabase', () async {
      // Arrange
      final mockSupabase = MockSupabaseClient();
      final mockQueryBuilder = MockSupabaseQueryBuilder();
      final mockFilterBuilder = MockPostgrestFilterBuilder();

      final repository = EventsRepository(
        supabase: mockSupabase,
        database: database,
        logger: mockLogger,
        carbLoadingRepository: mockCarbLoadingRepository,
      );

      when(() => mockSupabase.from('events')).thenReturn(mockQueryBuilder);
      when(() => mockQueryBuilder.select('*')).thenReturn(mockFilterBuilder);
      when(() => mockFilterBuilder.eq('user_id', testUserId))
          .thenReturn(mockFilterBuilder);
      when(() => mockFilterBuilder.order('created_at', ascending: false))
          .thenAnswer((_) async => []);

      // Act
      final result = await repository.syncFromRemote(testUserId);

      // Assert
      expect(result.success, true);
      expect(result.count, 0);
    });

    test('should return failure on Supabase error', () async {
      // Arrange
      final mockSupabase = MockSupabaseClient();
      final mockQueryBuilder = MockSupabaseQueryBuilder();
      final mockFilterBuilder = MockPostgrestFilterBuilder();

      final repository = EventsRepository(
        supabase: mockSupabase,
        database: database,
        logger: mockLogger,
        carbLoadingRepository: mockCarbLoadingRepository,
      );

      when(() => mockSupabase.from('events')).thenReturn(mockQueryBuilder);
      when(() => mockQueryBuilder.select('*')).thenReturn(mockFilterBuilder);
      when(() => mockFilterBuilder.eq('user_id', testUserId))
          .thenReturn(mockFilterBuilder);
      when(() => mockFilterBuilder.order('created_at', ascending: false))
          .thenThrow(Exception('Network error'));

      // Act
      final result = await repository.syncFromRemote(testUserId);

      // Assert
      expect(result.success, false);
      expect(result.error, contains('Network error'));
    });
  });

  group('uploadDirtyRecords', () {
    test('should upload dirty events to Supabase and clear flags', () async {
      // Arrange
      final mockSupabase = MockSupabaseClient();
      final mockQueryBuilder = MockSupabaseQueryBuilder();

      final repository = EventsRepository(
        supabase: mockSupabase,
        database: database,
        logger: mockLogger,
        carbLoadingRepository: mockCarbLoadingRepository,
      );

      // Create a dirty event in Drift
      final testEvent = domain.Event(
        id: '',
        userId: testUserId,
        activityId: null,
        eventType: ActivityType.running,
        eventSubtype: 'road',
        eventName: 'Dirty Event',
        location: 'Test City',
        registrationUrl: null,
        eventDate: DateTime.now().add(const Duration(days: 30)),
        startTime: '08:00:00',
        goalTimeMinutes: 240,
        goalPaceMinutesPerMile: 9.0,
        predictedFinishTimeMinutes: null,
        hasCarbLoading: false,
        carbLoadingDays: null,
        carbLoadingStartDate: null,
        hasNutritionPlan: false,
        bibNumber: null,
        waveStartTime: null,
        packetPickupInfo: null,
        actualFinishTimeMinutes: null,
        finalPlacement: null,
        ageGroupPlacement: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        needsUpload: true,
        localUpdatedAt: DateTime.now(),
      );

      // Mock Supabase for createEvent call
      when(() => mockSupabase.from('events')).thenReturn(mockQueryBuilder);
      when(() => mockQueryBuilder.insert(any())).thenAnswer((_) async => []);
      when(() => mockQueryBuilder.upsert(any())).thenAnswer((_) async => []);

      // Save dirty event to Drift
      await repository.createEvent(deviceId: testUserId, event: testEvent);

      // Act
      final result = await repository.uploadDirtyRecords(testUserId);

      // Assert
      expect(result.success, true);
      expect(result.count, greaterThan(0));

      // Verify dirty flag was cleared
      final savedEvents = await database.select(database.eventsTable).get();
      expect(savedEvents.where((e) => e.needsUpload == true).isEmpty, true);
    });

    test('should return nothingToUpload when no dirty records exist',
        () async {
      final mockSupabase = MockSupabaseClient();
      final repository = EventsRepository(
        supabase: mockSupabase,
        database: database,
        logger: mockLogger,
        carbLoadingRepository: mockCarbLoadingRepository,
      );

      // Act
      final result = await repository.uploadDirtyRecords(testUserId);

      // Assert
      expect(result.success, true);
      expect(result.count, 0);
    });

    test('should return failure on Supabase upload error', () async {
      // Arrange
      final mockSupabase = MockSupabaseClient();
      final mockQueryBuilder = MockSupabaseQueryBuilder();

      final repository = EventsRepository(
        supabase: mockSupabase,
        database: database,
        logger: mockLogger,
        carbLoadingRepository: mockCarbLoadingRepository,
      );

      // Create a dirty event
      final companion = EventsTableCompanion.insert(
        id: const Value('dirty-event-2'),
        userId: testUserId,
        eventType: 'running',
        needsUpload: const Value(true),
        localUpdatedAt: Value(DateTime.now()),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await database.into(database.eventsTable).insert(companion);

      // Mock Supabase upsert to fail
      when(() => mockSupabase.from('events')).thenReturn(mockQueryBuilder);
      when(() => mockQueryBuilder.upsert(any()))
          .thenThrow(Exception('Upload failed'));

      // Act
      final result = await repository.uploadDirtyRecords(testUserId);

      // Assert
      expect(result.success, false);
      expect(result.error, contains('Upload failed'));

      // Verify dirty flag is still set
      final savedEvents = await database.select(database.eventsTable).get();
      expect(savedEvents.first.needsUpload, true);
    });
  });

  group('Timestamp Management', () {
    test('getLastSyncTime should return null when never synced', () async {
      final mockSupabase = MockSupabaseClient();
      final repository = EventsRepository(
        supabase: mockSupabase,
        database: database,
        logger: mockLogger,
        carbLoadingRepository: mockCarbLoadingRepository,
      );

      final timestamp = await repository.getLastSyncTime();
      expect(timestamp, null);
    });

    test('setLastSyncTime and getLastSyncTime should work correctly',
        () async {
      final mockSupabase = MockSupabaseClient();
      final repository = EventsRepository(
        supabase: mockSupabase,
        database: database,
        logger: mockLogger,
        carbLoadingRepository: mockCarbLoadingRepository,
      );

      final now = DateTime.now();
      await repository.setLastSyncTime(now);

      final retrieved = await repository.getLastSyncTime();
      expect(retrieved, matcher.isNotNull);
      expect(retrieved!.difference(now).inSeconds, lessThan(1));
    });
  });
}
