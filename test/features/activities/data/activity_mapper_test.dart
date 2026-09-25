import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/data/activity_mapper.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart'
    as domain;
import 'package:mealvana_endurance/shared/database/app_database.dart' as db;
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';

void main() {
  final mapper = ActivityMapper(logger: NoopAppLogger());

  final createdAt = DateTime(2026, 7, 1, 6);
  final updatedAt = DateTime(2026, 7, 16, 9);
  final scheduledAt = DateTime(2026, 7, 16, 7);
  final completedAt = DateTime(2026, 7, 16, 8, 30);

  domain.Activity buildDomainActivity({bool isFasted = false}) {
    return domain.Activity(
      id: 'activity-1',
      userId: 'user-1',
      activityType: ActivityType.running,
      title: 'Morning Run',
      scheduledDateTime: scheduledAt,
      status: domain.ActivityStatus.completed,
      isFasted: isFasted,
      completedAt: completedAt,
      completionRating: 4,
      nutritionRating: 3,
      completionNotes: 'Solid effort',
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  db.Activity buildDriftRow({bool isFasted = false}) {
    return db.Activity(
      id: 'activity-1',
      userId: 'user-1',
      activityType: 'running',
      title: 'Morning Run',
      scheduledDateTime: scheduledAt,
      status: 'completed',
      isFasted: isFasted,
      reminderEnabled: false,
      reminderRecurring: false,
      needsNutritionRefresh: false,
      completedAt: completedAt,
      completionRating: 4,
      completionNotes: 'Solid effort',
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  group('completion_rating round-trip (surviving rating field)', () {
    test('domain -> Drift companion preserves completionRating', () {
      final companion = mapper.toCompanion(buildDomainActivity());

      expect(companion.completionRating.value, 4);
      expect(companion.completionNotes.value, 'Solid effort');
    });

    test('Drift row -> domain preserves completionRating', () {
      final activity = mapper.fromDriftRow(buildDriftRow());

      expect(activity.completionRating, 4);
      expect(activity.completionNotes, 'Solid effort');
      expect(activity.status, domain.ActivityStatus.completed);
    });

    test('domain -> Supabase payload emits completion_rating and no dead '
        'rating columns', () {
      final payload = mapper.buildSupabasePayload(buildDomainActivity());

      expect(payload['completion_rating'], 4);
      expect(payload['nutrition_rating'], 3);
      expect(payload['completion_notes'], 'Solid effort');
      // Dead remote duplicates must never be written by the app.
      expect(payload.containsKey('effort_rating'), isFalse);
      expect(payload.containsKey('overall_satisfaction'), isFalse);
    });

    test('Drift row -> upload payload emits completion_rating and no dead '
        'rating columns', () {
      final payload = mapper.buildUploadPayloadFromRow(buildDriftRow());

      expect(payload['completion_rating'], 4);
      expect(payload.containsKey('effort_rating'), isFalse);
      expect(payload.containsKey('overall_satisfaction'), isFalse);
    });

    test('Supabase json -> domain restores completionRating', () {
      final activity = mapper.fromJson({
        'id': 'activity-1',
        'user_id': 'user-1',
        'activity_type': 'running',
        'title': 'Morning Run',
        'scheduled_date_time': scheduledAt.toIso8601String(),
        'status': 'completed',
        'completed_at': completedAt.toIso8601String(),
        'completion_rating': 4,
        'nutrition_rating': 3,
        'completion_notes': 'Solid effort',
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      });

      expect(activity.completionRating, 4);
      expect(activity.nutritionRating, 3);
      expect(activity.completionNotes, 'Solid effort');
    });

    test('full round-trip domain -> Supabase payload -> domain preserves '
        'completionRating', () {
      final original = buildDomainActivity();
      final payload = mapper.buildSupabasePayload(
        original,
        includeCreatedAt: true,
      );
      final restored = mapper.fromJson(payload);

      expect(restored.completionRating, original.completionRating);
      expect(restored.nutritionRating, original.nutritionRating);
      expect(restored.completionNotes, original.completionNotes);
    });
  });

  group('is_fasted round-trip (persisted fasted flag)', () {
    test('domain -> Drift companion carries isFasted', () {
      final companion = mapper.toCompanion(buildDomainActivity(isFasted: true));

      expect(companion.isFasted.value, isTrue);
    });

    test('Drift row -> domain preserves isFasted', () {
      expect(
        mapper.fromDriftRow(buildDriftRow(isFasted: true)).isFasted,
        isTrue,
      );
      expect(mapper.fromDriftRow(buildDriftRow()).isFasted, isFalse);
    });

    test('domain -> Supabase payload emits is_fasted', () {
      final payload = mapper.buildSupabasePayload(
        buildDomainActivity(isFasted: true),
      );

      expect(payload['is_fasted'], isTrue);
    });

    test('Drift row -> upload payload emits is_fasted', () {
      final payload = mapper.buildUploadPayloadFromRow(
        buildDriftRow(isFasted: true),
      );

      expect(payload['is_fasted'], isTrue);
      expect(
        mapper.buildUploadPayloadFromRow(buildDriftRow())['is_fasted'],
        isFalse,
      );
    });

    test('Supabase json -> domain reads is_fasted; missing key -> false '
        '(old remote rows)', () {
      final baseJson = <String, dynamic>{
        'id': 'activity-1',
        'user_id': 'user-1',
        'activity_type': 'running',
        'title': 'Morning Run',
        'scheduled_date_time': scheduledAt.toIso8601String(),
        'status': 'planned',
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

      expect(
        mapper.fromJson({...baseJson, 'is_fasted': true}).isFasted,
        isTrue,
      );
      expect(
        mapper.fromJson({...baseJson, 'is_fasted': false}).isFasted,
        isFalse,
      );
      // Rows written before the column existed have no key at all.
      expect(mapper.fromJson(baseJson).isFasted, isFalse);
      // Explicit null (SELECT * against a row predating a backfill).
      expect(
        mapper.fromJson({...baseJson, 'is_fasted': null}).isFasted,
        isFalse,
      );
    });

    test('full round-trip domain -> Supabase payload -> domain preserves '
        'isFasted', () {
      final original = buildDomainActivity(isFasted: true);
      final restored = mapper.fromJson(
        mapper.buildSupabasePayload(original, includeCreatedAt: true),
      );

      expect(restored.isFasted, isTrue);
    });
  });

  // Finding 30-002: `last_synced_at`, `provider_deleted_at`,
  // `provider_scheduled_at` and `schedule_changed_at` are `timestamptz` on
  // the server. A local `DateTime.now()` serialised with a bare
  // `toIso8601String()` carries no offset, so Postgres reads the local wall
  // clock as UTC (five hours off in CDT). The wall-clock columns
  // (`scheduled_date_time`, `updated_at`, ...) are `timestamp without time
  // zone` and stay local-naive on purpose.
  group('timestamptz columns serialise as UTC with an offset', () {
    // A local (non-UTC) instant; the offset is whatever the test host uses.
    final localInstant = DateTime(2026, 9, 24, 11, 17, 42, 802);
    final expectedUtc = localInstant.toUtc().toIso8601String();

    domain.Activity syncedDomainActivity() => buildDomainActivity().copyWith(
      lastSyncedAt: localInstant,
      providerDeletedAt: localInstant,
      providerScheduledAt: localInstant,
      scheduleChangedAt: localInstant,
    );

    db.Activity syncedDriftRow() => buildDriftRow().copyWith(
      lastSyncedAt: Value(localInstant),
      providerDeletedAt: Value(localInstant),
      providerScheduledAt: Value(localInstant),
      scheduleChangedAt: Value(localInstant),
    );

    test('domain -> Supabase payload writes UTC with a Z suffix', () {
      final payload = mapper.buildSupabasePayload(syncedDomainActivity());

      for (final key in [
        'last_synced_at',
        'provider_deleted_at',
        'provider_scheduled_at',
        'schedule_changed_at',
      ]) {
        expect(payload[key], expectedUtc, reason: key);
        expect(payload[key], endsWith('Z'), reason: '$key carries an offset');
      }
      // The wall-clock column is untouched.
      expect(payload['scheduled_date_time'], scheduledAt.toIso8601String());
      expect(payload['scheduled_date_time'], isNot(endsWith('Z')));
    });

    test('Drift row -> upload payload writes UTC with a Z suffix', () {
      final payload = mapper.buildUploadPayloadFromRow(syncedDriftRow());

      for (final key in [
        'last_synced_at',
        'provider_deleted_at',
        'provider_scheduled_at',
        'schedule_changed_at',
      ]) {
        expect(payload[key], expectedUtc, reason: key);
      }
      expect(payload['scheduled_date_time'], scheduledAt.toIso8601String());
      expect(payload['scheduled_date_time'], isNot(endsWith('Z')));
    });

    test('null timestamptz values stay null', () {
      final payload = mapper.buildSupabasePayload(buildDomainActivity());

      expect(payload['last_synced_at'], isNull);
      expect(payload['provider_deleted_at'], isNull);
    });

    test('a UTC value read back from the server round-trips to the same '
        'instant', () {
      final payload = mapper.buildSupabasePayload(syncedDomainActivity());
      final parsed = mapper.parseDateTime(payload['last_synced_at']);

      expect(parsed, isNotNull);
      expect(parsed!.isAtSameMomentAs(localInstant), isTrue);
    });
  });
}
