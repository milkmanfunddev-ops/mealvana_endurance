/// The moment controller (vana-moment spec, Cadence and VM-2/VM-3) through
/// the real notifier, the real SharedPreferences-backed store and a fake
/// clock: it rings once per workout window, across restarts; a log retires
/// the moment; a dismissed moment stays live; an answer retires it.
library;

import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/data/activity_mapper.dart';
import 'package:mealvana_endurance/features/activities/domain/activity.dart';
import 'package:mealvana_endurance/features/activities/presentation/providers/activities_controller.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/providers/meal_log_providers.dart';
import 'package:mealvana_endurance/features/meal_planning/application/vana_ambient_conversation_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/application/vana_moment_controller.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/vana_moment.dart';
import 'package:mealvana_endurance/shared/providers/user_id_provider.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _mapper = ActivityMapper(logger: NoopAppLogger());

/// Tonight's run as the Supabase row carries it: 17:30 wall clock, a 60 min
/// window.
final _run = _mapper.fromJson({
  'id': 'act-run',
  'user_id': 'user-1',
  'activity_type': 'running',
  'title': 'Tempo run',
  'scheduled_date_time': '2026-09-11T17:30:00',
  'status': 'planned',
  'duration_minutes': 60,
  'time_before_minutes': 60,
  'created_at': '2026-09-01T12:00:00+00:00',
  'updated_at': '2026-09-01T12:00:00+00:00',
});

MealLog _snack(DateTime eatenAt) => MealLog.fromSupabaseJson({
  'id': 'log-snack',
  'user_id': 'user-1',
  'log_date': '2026-09-11',
  'slot': 'snack',
  'name': 'Bagel and honey',
  'source': 'manual',
  'items': <Object?>[],
  'eaten_at': eatenAt.toUtc().toIso8601String(),
  'created_at': eatenAt.toUtc().toIso8601String(),
  'updated_at': eatenAt.toUtc().toIso8601String(),
  'is_deleted': false,
})!;

List<Activity> _seeded = [];

class _Activities extends ActivitiesController {
  @override
  Future<List<Activity>> build() async => _seeded;
}

void main() {
  // The controller listens for the app coming back to the foreground.
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late DateTime now;
  late StreamController<List<MealLog>> logs;
  late List<MealLog> currentLogs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    now = DateTime(2026, 9, 11, 16, 45);
    _seeded = [_run];
    currentLogs = [];
    logs = StreamController<List<MealLog>>.broadcast();
  });

  ProviderContainer start({bool reducedMotion = false}) {
    final c = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        userIdProvider.overrideWith((ref) async => 'user-1'),
        vanaClockProvider.overrideWithValue(() => now),
        vanaReducedMotionProvider.overrideWithValue(reducedMotion),
        activitiesControllerProvider.overrideWith(_Activities.new),
        mealLogsForDateProvider.overrideWith((ref, date) async* {
          yield currentLogs;
          yield* logs.stream;
        }),
      ],
    );
    // Held open the way the launcher's host holds it.
    c.listen(vanaMomentControllerProvider, (_, _) {});
    return c;
  }

  VanaMomentState? read(ProviderContainer c) =>
      c.read(vanaMomentControllerProvider).value;

  VanaMomentController notifier(ProviderContainer c) =>
      c.read(vanaMomentControllerProvider.notifier);

  test('it waits for a launcher, rings once, shows the pill, then tints', () {
    fakeAsync((async) {
      final c = start();
      async.flushMicrotasks();
      expect(read(c)!.moment!.activityId, 'act-run');
      expect(read(c)!.phase, VanaMomentPhase.waiting);

      notifier(c).ring();
      async.flushMicrotasks();
      expect(read(c)!.phase, VanaMomentPhase.ring);

      async.elapse(vanaMomentRingDuration);
      expect(read(c)!.phase, VanaMomentPhase.pill);

      async.elapse(vanaMomentPillDuration);
      expect(read(c)!.phase, VanaMomentPhase.tinted);

      notifier(c).ring();
      async.flushMicrotasks();
      expect(read(c)!.phase, VanaMomentPhase.tinted);
      c.dispose();
    });
  });

  test('a restart does not ring again', () {
    fakeAsync((async) {
      final first = start();
      async.flushMicrotasks();
      notifier(first).ring();
      async.flushMicrotasks();
      first.dispose();

      now = DateTime(2026, 9, 11, 16, 55);
      final restarted = start();
      async.flushMicrotasks();
      expect(read(restarted)!.moment, isNotNull);
      expect(read(restarted)!.phase, VanaMomentPhase.tinted);
      restarted.dispose();
    });
  });

  test('reduced motion skips the ring, and the pill still shows', () {
    fakeAsync((async) {
      final c = start(reducedMotion: true);
      async.flushMicrotasks();
      notifier(c).ring();
      async.flushMicrotasks();
      expect(read(c)!.phase, VanaMomentPhase.pill);
      async.elapse(vanaMomentPillDuration);
      expect(read(c)!.phase, VanaMomentPhase.tinted);
      c.dispose();
    });
  });

  test('something logged in the window retires it', () {
    fakeAsync((async) {
      final c = start();
      async.flushMicrotasks();
      notifier(c).ring();
      async.elapse(const Duration(seconds: 1));

      logs.add([_snack(DateTime(2026, 9, 11, 16, 50))]);
      async.flushMicrotasks();
      expect(read(c)!.moment, isNull);
      // The ring it was in the middle of does not bring it back.
      async.elapse(vanaMomentRingDuration + vanaMomentPillDuration);
      expect(read(c)!.moment, isNull);
      c.dispose();
    });
  });

  test('the workout starting retires it on the next resolve', () {
    fakeAsync((async) {
      final c = start();
      async.flushMicrotasks();
      expect(read(c)!.moment, isNotNull);

      now = DateTime(2026, 9, 11, 17, 30);
      async.elapse(vanaMomentResolveInterval);
      expect(read(c)!.moment, isNull);
      c.dispose();
    });
  });

  test('a moment the athlete saw and dismissed stays live and tinted, and '
      'remembers where its opening is', () {
    fakeAsync((async) {
      final c = start();
      async.flushMicrotasks();
      notifier(c).ring();
      async.elapse(vanaMomentRingDuration + vanaMomentPillDuration);
      notifier(c).opened(3);
      async.flushMicrotasks();

      async.elapse(vanaMomentResolveInterval);
      expect(read(c)!.phase, VanaMomentPhase.tinted);
      expect(read(c)!.exchangeStart, 3);
      c.dispose();

      final restarted = start();
      async.flushMicrotasks();
      expect(read(restarted)!.exchangeStart, 3);
      restarted.dispose();
    });
  });

  test('an answer retires it, across restarts', () {
    fakeAsync((async) {
      final c = start();
      async.flushMicrotasks();
      notifier(c).ring();
      notifier(c).answer(read(c)!.moment!.key);
      async.flushMicrotasks();
      expect(read(c)!.moment, isNull);
      c.dispose();

      final restarted = start();
      async.flushMicrotasks();
      expect(read(restarted)!.moment, isNull);
      restarted.dispose();
    });
  });
}
