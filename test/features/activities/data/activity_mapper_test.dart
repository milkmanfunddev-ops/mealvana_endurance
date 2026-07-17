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

  domain.Activity buildDomainActivity() {
    return domain.Activity(
      id: 'activity-1',
      userId: 'user-1',
      activityType: ActivityType.running,
      title: 'Morning Run',
      scheduledDateTime: scheduledAt,
      status: domain.ActivityStatus.completed,
      completedAt: completedAt,
      completionRating: 4,
      nutritionRating: 3,
      completionNotes: 'Solid effort',
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  db.Activity buildDriftRow() {
    return db.Activity(
      id: 'activity-1',
      userId: 'user-1',
      activityType: 'running',
      title: 'Morning Run',
      scheduledDateTime: scheduledAt,
      status: 'completed',
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
}
