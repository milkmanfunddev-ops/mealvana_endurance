// Regression: the carb-trend fueling baseline was stuck at "N/4 baseline
// efforts" for a frequent athlete. `getRecentCompletedActivitiesBySport`
// fetched the `limit` most-recent completed runs of ANY duration, so a stream
// of short runs filled the window and pushed the older qualifying long efforts
// (>= 90 min) out of it. The `minDurationMinutes` gate fixes this: the window
// counts long efforts, not short ones. (Real data: 8 qualifying long runs, but
// only 2 landed in a 12-of-any-length window → card showed 3/4 forever.)
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/application/activity_deduplication_service.dart';
import 'package:mealvana_endurance/features/activities/data/activities_repository.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart'
    as db
    show AppDatabase;
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockSentryReporter extends Mock implements SentryReporter {}

class MockDedup extends Mock implements ActivityDeduplicationService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late db.AppDatabase database;
  late ActivitiesRepository repository;
  const userId = 'user-window';
  final base = DateTime(2026, 9, 1, 7);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    database = db.AppDatabase.forTesting(NativeDatabase.memory());
    repository = ActivitiesRepository(
      supabase: MockSupabaseClient(),
      database: database,
      logger: NoopAppLogger(),
      sentry: MockSentryReporter(),
      deduplicationService: MockDedup(),
    );
  });
  tearDown(() => database.close());

  Future<void> seedRun(int dayOffset, int minutes) async {
    final when = base.add(Duration(days: dayOffset));
    await repository.insertActivity(
      Activity(
        id: '',
        userId: userId,
        activityType: ActivityType.running,
        title: 'Run ${minutes}m',
        scheduledDateTime: when,
        status: ActivityStatus.completed,
        completedAt: when,
        actualDurationMinutes: minutes,
        durationMinutes: minutes,
        createdAt: when,
        updatedAt: when,
      ),
    );
  }

  test(
    'short runs do not starve the window: long efforts survive minDuration gate',
    () async {
      // 3 older long runs (>=90), then 12 more-recent short runs (60) on top.
      for (final d in [1, 3, 5]) {
        await seedRun(d, 120);
      }
      for (var i = 0; i < 12; i++) {
        await seedRun(20 + i, 60);
      }

      // With the duration gate, the window counts long efforts only — the 12
      // recent short runs can't crowd them out.
      final gated = await repository.getRecentCompletedActivitiesBySport(
        userId,
        ActivityType.running,
        minDurationMinutes: 90,
      );
      expect(gated.length, 3, reason: 'all three long runs must survive');
      expect(
        gated.every((a) => (a.actualDurationMinutes ?? 0) >= 90),
        isTrue,
        reason: 'no short run should be returned when gated',
      );

      // Back-compat: with no gate, the limit fills with the recent short runs
      // (the pre-fix behavior, kept for any other/future caller).
      final ungated = await repository.getRecentCompletedActivitiesBySport(
        userId,
        ActivityType.running,
      );
      expect(ungated.length, 12);
      expect(
        ungated.every((a) => (a.actualDurationMinutes ?? 0) == 60),
        isTrue,
        reason: 'ungated window is the 12 most-recent completed runs (short)',
      );
    },
  );
}
