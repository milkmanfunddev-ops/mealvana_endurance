// Finding 30-002: the edge-function upload path (`activityToJson`) wrote
// `last_synced_at` and the other timestamptz sync columns as the local wall
// clock with no offset, so Postgres read them as UTC. Those four columns are
// `timestamp with time zone` on the server; the wall-clock columns
// (`scheduled_date_time`, `updated_at`, `created_at`) are `timestamp without
// time zone` and are left local-naive on purpose.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/sync/entity_sync/activity_sync_handler.dart';

void main() {
  late AppDatabase database;
  late ActivitySyncHandler handler;

  setUp(() {
    database = AppDatabase.forTesting(NativeDatabase.memory());
    handler = ActivitySyncHandler(database: database, logger: NoopAppLogger());
  });

  tearDown(() async {
    await database.close();
  });

  final localInstant = DateTime(2026, 9, 24, 11, 17, 42, 802);
  final scheduledAt = DateTime(2026, 9, 24, 7, 28);

  Activity row() => Activity(
    id: 'activity-1',
    userId: 'user-1',
    activityType: 'running',
    title: 'Run',
    scheduledDateTime: scheduledAt,
    status: 'planned',
    isFasted: false,
    reminderEnabled: false,
    reminderRecurring: false,
    needsNutritionRefresh: false,
    createdAt: DateTime(2026, 9, 1, 6),
    updatedAt: localInstant,
  );

  test('activityToJson writes timestamptz sync columns as UTC with a Z', () {
    final json = handler.activityToJson(
      row().copyWith(
        lastSyncedAt: Value(localInstant),
        providerDeletedAt: Value(localInstant),
        providerScheduledAt: Value(localInstant),
        scheduleChangedAt: Value(localInstant),
      ),
    );

    final expectedUtc = localInstant.toUtc().toIso8601String();
    for (final key in [
      'last_synced_at',
      'provider_deleted_at',
      'provider_scheduled_at',
      'schedule_changed_at',
    ]) {
      expect(json[key], expectedUtc, reason: key);
      expect(json[key], endsWith('Z'), reason: '$key carries an offset');
    }
  });

  test('activityToJson leaves the wall-clock columns local-naive', () {
    final json = handler.activityToJson(row());

    expect(json['scheduled_date_time'], scheduledAt.toIso8601String());
    expect(json['scheduled_date_time'], isNot(endsWith('Z')));
    expect(json['updated_at'], localInstant.toIso8601String());
    expect(json['last_synced_at'], isNull);
    expect(json['provider_deleted_at'], isNull);
  });
}
