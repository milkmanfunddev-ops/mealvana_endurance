// Ticket 24 (Sentry MEALVANA-ENDURANCE-DEV-88, "N+1 Query" on `root /`).
//
// The event: one `ui.load root /` transaction ran
//   SELECT * FROM activities WHERE lower(user_id)=? AND brick_id=? ...
//   SELECT * FROM activities WHERE lower(user_id)=? AND id IN (?, ?) ...
// once per brick, seven bricks, twice over (two readers of the week). The
// bricks were legacy ones (leg ids in the title) whose legs were gone, so
// nothing was recovered and every load paid the queries again.
//
// Seam: the real ActivitiesService over a real in-memory Drift database whose
// executor counts statements. Rows are written through Drift inserts, the
// shape the sync writes.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/application/activities_service.dart';
import 'package:mealvana_endurance/features/activities/application/activity_deduplication_service.dart';
import 'package:mealvana_endurance/features/activities/data/activities_repository.dart';
import 'package:mealvana_endurance/features/coach_mode/data/coach_repository.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../helpers/fakes/recording_report.dart';
import '../../../helpers/query_counter.dart';

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockDeduplication extends Mock implements ActivityDeduplicationService {}

class _MockCoachRepository extends Mock implements CoachRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const userId = 'user-n1';
  final weekStart = DateTime(2026, 9, 21);
  final weekEnd = DateTime(2026, 9, 27, 23, 59, 59);

  late QueryCounter counter;
  late AppDatabase database;
  late ActivitiesService service;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    counter = QueryCounter();
    database = AppDatabase.forTesting(
      NativeDatabase.memory().interceptWith(counter),
    );
    final report = RecordingReport();
    service = ActivitiesService(
      database,
      report,
      ActivitiesRepository(
        supabase: _MockSupabaseClient(),
        database: database,
        deduplicationService: _MockDeduplication(),
        report: report,
      ),
      _MockCoachRepository(),
    );
  });

  tearDown(() => database.close());

  var seq = 0;
  String uuid() {
    seq++;
    final n = seq.toRadixString(16).padLeft(12, '0');
    return '00000000-0000-4000-8000-$n';
  }

  Future<void> insert({
    required String id,
    required String type,
    required String title,
    required DateTime at,
    String status = 'planned',
    String? brickId,
  }) {
    return database
        .into(database.activitiesTable)
        .insert(
          ActivitiesTableCompanion.insert(
            id: Value(id),
            userId: userId,
            activityType: type,
            title: title,
            scheduledDateTime: at,
            status: Value(status),
            brickId: Value(brickId),
            durationMinutes: const Value(45),
            createdAt: at,
            updatedAt: at,
          ),
        );
  }

  test('hydrating N bricks costs one archived-legs query and one legacy-legs '
      'query, not two per brick', () async {
    // Seven orphan legacy bricks, as in the DEV-88 event: titles hold two leg
    // ids, the legs are gone.
    for (var day = 0; day < 7; day++) {
      await insert(
        id: uuid(),
        type: 'brick',
        title: '${uuid()} / ${uuid()} BRICK',
        at: weekStart.add(Duration(days: day, hours: 6)),
      );
    }
    // One brick whose legs are archived and linked by brick_id.
    final linkedBrick = uuid();
    final at = weekStart.add(const Duration(days: 2, hours: 17));
    await insert(id: linkedBrick, type: 'brick', title: 'BIKE / RUN', at: at);
    await insert(
      id: uuid(),
      type: 'cycling',
      title: 'Bike',
      at: at,
      status: 'archivedForBrick',
      brickId: linkedBrick,
    );
    await insert(
      id: uuid(),
      type: 'running',
      title: 'Run',
      at: at.add(const Duration(minutes: 1)),
      status: 'archived_for_brick',
      brickId: linkedBrick,
    );
    // One legacy brick whose legs still exist (no brick_id yet).
    final swimLeg = uuid();
    final runLeg = uuid();
    final legacyAt = weekStart.add(const Duration(days: 4, hours: 7));
    await insert(
      id: swimLeg,
      type: 'swimming',
      title: 'Swim',
      at: legacyAt,
      status: 'archivedForBrick',
    );
    await insert(
      id: runLeg,
      type: 'running',
      title: 'Run',
      at: legacyAt.add(const Duration(minutes: 1)),
      status: 'archivedForBrick',
    );
    final legacyBrick = uuid();
    await insert(
      id: legacyBrick,
      type: 'brick',
      title: '$swimLeg / $runLeg BRICK',
      at: legacyAt,
    );

    counter.reset();
    final activities = await service.getActivitiesForDateRange(
      userId,
      weekStart,
      weekEnd,
    );

    // 1 week query + 1 archived-legs query + 1 legacy-legs query. Before the
    // fix: 1 + 9 + 8 = 18.
    expect(
      counter.selectsOn('activities'),
      3,
      reason: counter.selects.join('\n---\n'),
    );

    final bricks = {
      for (final a in activities.where((a) => a.isBrick)) a.id: a,
    };
    expect(bricks, hasLength(9));
    expect(bricks[linkedBrick]!.brickMetadata!.segments.map((s) => s.sport), [
      'cycling',
      'running',
    ]);
    expect(
      bricks[legacyBrick]!.brickMetadata!.segments.map((s) => s.sport),
      ['swimming', 'running'],
      reason: 'legacy legs are recovered in title order',
    );
    expect(
      bricks.values.where((b) => b.brickMetadata?.segments.isEmpty ?? true),
      hasLength(7),
      reason: 'orphans stay visible with no segments',
    );

    // The recovered legacy legs were linked, so the next load finds them by
    // brick_id.
    final relinked = await (database.select(
      database.activitiesTable,
    )..where((t) => t.id.isIn([swimLeg, runLeg]))).get();
    expect(relinked.map((r) => r.brickId), everyElement(legacyBrick));
  });

  test('a list with no bricks to hydrate runs only the list query', () async {
    await insert(
      id: uuid(),
      type: 'running',
      title: 'Easy run',
      at: weekStart.add(const Duration(hours: 6)),
    );
    counter.reset();
    await service.getActivitiesForDateRange(userId, weekStart, weekEnd);
    expect(counter.selectsOn('activities'), 1);
  });
}
