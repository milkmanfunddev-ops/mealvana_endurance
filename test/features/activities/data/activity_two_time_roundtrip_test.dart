import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/data/activity_mapper.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart'
    as domain;
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';

/// Serialization round-trip for the daily-macros bundle columns:
/// planned_time / actual_time / calories_burned + the 'deleted' tombstone
/// status must survive every ActivityMapper seam — domain → companion →
/// Drift row → upload payload → JSON wire → domain. A drop at any seam
/// either resurrects deleted workouts or loses the two-time model.
void main() {
  final mapper = ActivityMapper(logger: NoopAppLogger());

  final createdAt = DateTime(2026, 8, 1, 6);
  final updatedAt = DateTime(2026, 8, 10, 9);
  final scheduledAt = DateTime(2026, 8, 10, 7);
  final plannedAt = DateTime(2026, 8, 10, 7, 15);
  final actualAt = DateTime(2026, 8, 10, 6, 42);
  final deletedAt = DateTime(2026, 8, 10, 12);

  domain.Activity buildActivity({
    domain.ActivityStatus status = domain.ActivityStatus.completed,
    DateTime? deletedAtValue,
  }) {
    return domain.Activity(
      id: 'activity-rt-1',
      userId: 'user-1',
      activityType: ActivityType.running,
      title: 'Morning Run',
      scheduledDateTime: scheduledAt,
      status: status,
      plannedTime: plannedAt,
      actualTime: actualAt,
      caloriesBurned: 512.5,
      createdAt: createdAt,
      updatedAt: updatedAt,
      deletedAt: deletedAtValue,
    );
  }

  group('full chain: domain -> companion -> Drift row -> upload payload -> '
      'JSON wire -> domain', () {
    late AppDatabase database;

    setUp(() {
      database = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await database.close();
    });

    Future<domain.Activity> roundTrip(domain.Activity original) async {
      final companion = mapper.toCompanion(original);
      await database.into(database.activitiesTable).insert(companion);
      final row = await (database.select(
        database.activitiesTable,
      )..where((t) => t.id.equals(original.id))).getSingle();

      final payload = mapper.buildUploadPayloadFromRow(row);
      // Real wire trip: the payload must be JSON-encodable as-is.
      final wireJson = jsonDecode(jsonEncode(payload)) as Map<String, dynamic>;
      return mapper.fromJson(wireJson);
    }

    test('two-time fields and calories survive the whole chain', () async {
      final restored = await roundTrip(buildActivity());

      expect(restored.plannedTime, plannedAt);
      expect(restored.actualTime, actualAt);
      expect(restored.caloriesBurned, 512.5);
      expect(restored.status, domain.ActivityStatus.completed);
    });

    test('tombstone (status=deleted + deleted_at) survives the whole chain',
        () async {
      final restored = await roundTrip(
        buildActivity(
          status: domain.ActivityStatus.deleted,
          deletedAtValue: deletedAt,
        ),
      );

      expect(restored.status, domain.ActivityStatus.deleted);
      expect(restored.deletedAt, deletedAt);
      // The tombstone keeps its identity for sync matching.
      expect(restored.plannedTime, plannedAt);
      expect(restored.actualTime, actualAt);
    });
  });

  group('individual seams', () {
    test('domain -> companion carries the new columns and tombstone status',
        () {
      final companion = mapper.toCompanion(
        buildActivity(
          status: domain.ActivityStatus.deleted,
          deletedAtValue: deletedAt,
        ),
      );

      expect(companion.plannedTime.value, plannedAt);
      expect(companion.actualTime.value, actualAt);
      expect(companion.caloriesBurned.value, 512.5);
      expect(companion.status.value, 'deleted');
      expect(companion.deletedAt.value, deletedAt);
    });

    test('toCompanion forInsert stamps planned_time from the scheduled time '
        'when unset (two-time model)', () {
      final noPlanned = domain.Activity(
        id: 'activity-rt-2',
        userId: 'user-1',
        activityType: ActivityType.running,
        title: 'Morning Run',
        scheduledDateTime: scheduledAt,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      expect(
        mapper.toCompanion(noPlanned, forInsert: true).plannedTime.value,
        scheduledAt,
      );
      // Updates must NOT invent a planned time for legacy rows.
      expect(mapper.toCompanion(noPlanned).plannedTime.value, isNull);
    });

    test('domain -> Supabase payload emits the new columns and tombstone',
        () {
      final payload = mapper.buildSupabasePayload(
        buildActivity(
          status: domain.ActivityStatus.deleted,
          deletedAtValue: deletedAt,
        ),
      );

      expect(payload['planned_time'], plannedAt.toIso8601String());
      expect(payload['actual_time'], actualAt.toIso8601String());
      expect(payload['calories_burned'], 512.5);
      expect(payload['status'], 'deleted');
      expect(payload['deleted_at'], deletedAt.toIso8601String());
    });

    test('buildSupabasePayload insert stamps planned_time from the scheduled '
        'time when unset', () {
      final noPlanned = domain.Activity(
        id: 'activity-rt-3',
        userId: 'user-1',
        activityType: ActivityType.running,
        title: 'Morning Run',
        scheduledDateTime: scheduledAt,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      expect(
        mapper.buildSupabasePayload(noPlanned, includeCreatedAt: true)
            ['planned_time'],
        scheduledAt.toIso8601String(),
      );
      expect(
        mapper.buildSupabasePayload(noPlanned)['planned_time'],
        isNull,
      );
    });

    test('Drift row -> domain preserves the new columns and tombstone', () {
      final row = Activity(
        id: 'activity-rt-4',
        userId: 'user-1',
        activityType: 'running',
        title: 'Morning Run',
        scheduledDateTime: scheduledAt,
        status: 'deleted',
        isFasted: false,
        reminderEnabled: false,
        reminderRecurring: false,
        needsNutritionRefresh: false,
        plannedTime: plannedAt,
        actualTime: actualAt,
        caloriesBurned: 512.5,
        deletedAt: deletedAt,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

      final activity = mapper.fromDriftRow(row);

      expect(activity.plannedTime, plannedAt);
      expect(activity.actualTime, actualAt);
      expect(activity.caloriesBurned, 512.5);
      expect(activity.status, domain.ActivityStatus.deleted);
      expect(activity.deletedAt, deletedAt);
    });

    test('Supabase json -> domain tolerates rows predating the columns', () {
      final activity = mapper.fromJson({
        'id': 'activity-rt-5',
        'user_id': 'user-1',
        'activity_type': 'running',
        'title': 'Morning Run',
        'scheduled_date_time': scheduledAt.toIso8601String(),
        'status': 'planned',
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      });

      expect(activity.plannedTime, isNull);
      expect(activity.actualTime, isNull);
      expect(activity.caloriesBurned, isNull);
      expect(activity.status, domain.ActivityStatus.planned);
    });

    test("parseActivityStatus('deleted') never falls back to planned "
        '(would resurrect tombstones)', () {
      expect(
        mapper.parseActivityStatus('deleted'),
        domain.ActivityStatus.deleted,
      );
      expect(mapper.activityStatusToDbValue('deleted'), 'deleted');
    });
  });
}
