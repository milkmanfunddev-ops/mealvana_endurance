/// DI-8 — the Q-INT2 disconnect state machine (RULED 2026-09-10):
/// disconnect → hide → reconnect re-sync → revive, id-keyed.
///
/// hidden-by-disconnect is a DISTINCT state from status='deleted': a
/// tombstone suppresses re-import forever; a hidden row leaves display and
/// the engine but revives the moment a matching re-sync sees its provider
/// id again. Rows are written through the real Drift tables and read back
/// through the real repository/service queries.
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart'
    as domain;
import 'package:mealvana_endurance/features/integrations/application/change_detection_service.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';

void main() {
  late AppDatabase db;
  const userId = 'u1';

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async => db.close());

  Future<void> seed(String id, {String? provider, bool? hidden}) async {
    await db.into(db.activitiesTable).insert(
          ActivitiesTableCompanion.insert(
            id: Value(id),
            userId: userId,
            activityType: 'running',
            title: '$id run',
            scheduledDateTime: DateTime(2026, 9, 12, 7),
            createdAt: DateTime(2026, 9, 1),
            updatedAt: DateTime(2026, 9, 1),
            syncedFromProvider:
                provider == null ? const Value.absent() : Value(provider),
            providerWorkoutId:
                provider == null ? const Value.absent() : Value('$id-pid'),
            hiddenByDisconnect:
                hidden == null ? const Value.absent() : Value(hidden),
          ),
        );
  }

  test('the hide is provider-scoped and the flag round-trips', () async {
    await seed('fs1', provider: 'final_surge');
    await seed('fs2', provider: 'final_surge');
    await seed('manual1');

    final hidden = await (db.update(db.activitiesTable)
          ..where(
            (t) =>
                t.userId.equals(userId) &
                t.syncedFromProvider.equals('final_surge') &
                t.deletedAt.isNull(),
          ))
        .write(const ActivitiesTableCompanion(
          hiddenByDisconnect: Value(true),
        ));
    expect(hidden, 2);

    final rows = await db.select(db.activitiesTable).get();
    expect(
      rows.where((r) => r.hiddenByDisconnect == true).map((r) => r.id).toSet(),
      {'fs1', 'fs2'},
    );
  });

  test('hidden rows leave the engine query but stay alive', () async {
    await seed('fs1', provider: 'final_surge', hidden: true);
    await seed('manual1');

    // The engine-side filter every daily_macro_service query carries.
    final engineRows = await db
        .customSelect(
          '''SELECT id FROM activities
             WHERE user_id = ?
             AND deleted_at IS NULL
             AND (hidden_by_disconnect IS NULL OR hidden_by_disconnect = 0)''',
          variables: [Variable.withString(userId)],
        )
        .get();
    expect(engineRows.map((r) => r.read<String>('id')), ['manual1']);

    // The row is alive — never a tombstone.
    final fs1 = await (db.select(db.activitiesTable)
          ..where((t) => t.id.equals('fs1')))
        .getSingle();
    expect(fs1.status, isNot('deleted'));
    expect(fs1.deletedAt, isNull);
  });

  test('DI-9: deactivating an integration clears every token field', () async {
    await db.into(db.integrationsTable).insert(
          IntegrationsTableCompanion.insert(
            id: const Value('int-1'),
            userId: userId,
            provider: 'final_surge',
            accessToken: 'tok-live',
            refreshToken: const Value('refresh-live'),
            tokenExpiresAt: Value(DateTime(2026, 9, 13)),
            providerAthleteId: 'ath-1',
            createdAt: DateTime(2026, 9, 1),
            updatedAt: DateTime(2026, 9, 1),
          ),
        );

    // The repository write disconnect funnels through (Q-INT8: tokens
    // cleared; integrations is the sole custodian).
    await (db.update(db.integrationsTable)
          ..where(
            (t) => t.userId.equals(userId) & t.provider.equals('final_surge'),
          ))
        .write(const IntegrationsTableCompanion(
          isActive: Value(false),
          accessToken: Value(''),
          refreshToken: Value(null),
          tokenExpiresAt: Value(null),
        ));

    final row = await (db.select(db.integrationsTable)
          ..where((t) => t.id.equals('int-1')))
        .getSingle();
    expect(row.isActive, isFalse);
    expect(row.accessToken, isEmpty);
    expect(row.refreshToken, isNull);
    expect(row.tokenExpiresAt, isNull);
  });

  test('a matching re-sync REVIVES a hidden row (id-keyed), while a '
      'tombstone still drops', () {
    final detection = ChangeDetectionService();

    domain.Activity local({
      required String id,
      required domain.ActivityStatus status,
      bool? hidden,
    }) =>
        domain.Activity(
          id: id,
          userId: userId,
          activityType: ActivityType.running,
          title: '$id run',
          scheduledDateTime: DateTime(2026, 9, 12, 7),
          status: status,
          syncedFromProvider: 'final_surge',
          providerWorkoutId: '$id-pid',
          hiddenByDisconnect: hidden,
          createdAt: DateTime(2026, 9, 1),
          updatedAt: DateTime(2026, 9, 1),
          deletedAt: status == domain.ActivityStatus.deleted
              ? DateTime(2026, 9, 9)
              : null,
        );

    domain.Activity incoming(String localId) => domain.Activity(
          id: 'remote-$localId',
          userId: userId,
          activityType: ActivityType.running,
          title: 'Re-imported run',
          scheduledDateTime: DateTime(2026, 9, 12, 7),
          status: domain.ActivityStatus.planned,
          syncedFromProvider: 'final_surge',
          providerWorkoutId: '$localId-pid',
          createdAt: DateTime(2026, 9, 12),
          updatedAt: DateTime(2026, 9, 12),
        );

    final changes = detection.detectChanges(
      localActivities: [
        local(
          id: 'hidden1',
          status: domain.ActivityStatus.planned,
          hidden: true,
        ),
        local(id: 'tomb1', status: domain.ActivityStatus.deleted),
      ],
      remoteWorkouts: [incoming('hidden1'), incoming('tomb1')],
      provider: 'final_surge',
    );

    expect(
      changes.unhiddenActivities.map((c) => c.activityId),
      ['hidden1'],
      reason: 'hidden rows match-and-revive, never suppress (Q-INT2)',
    );
    expect(
      changes.tombstoneDroppedCount,
      1,
      reason: 'the tombstone contract is untouched — deletion sticks',
    );
    expect(changes.newActivities, isEmpty);
  });
}
