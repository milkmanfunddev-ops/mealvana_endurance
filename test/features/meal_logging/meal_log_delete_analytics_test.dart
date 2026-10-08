// develop-2026-10 ticket 41 (idea 31-012): removing a meal is counted.
//
// The Timeline (`macro_dashboard_screen.dart`) and the diary
// (`today_log_section.dart`) call
// `ref.read(mealLogControllerProvider.notifier).deleteLog(...)` with no
// listener, and the Undo snackbar calls `restoreLog` the same way. The
// controller is auto-dispose, so it is gone by the time the write lands, and
// `meal_log_deleted` / `meal_log_restored` used to be skipped behind
// `ref.mounted`. The real MealLogController, the real repository on an
// in-memory Drift with the wire cut, and a recording tracker.

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/meal_logging/data/meal_log_repository.dart';
import 'package:mealvana_endurance/features/meal_logging/data/saved_meals_repository.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log.dart';
import 'package:mealvana_endurance/features/meal_logging/domain/meal_log_source.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/providers/meal_log_providers.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';

import '../../helpers/fakes/fake_supabase_client.dart';
import '../../helpers/fakes/recording_analytics_tracker.dart';

const _user = 'user-41';

class _MockUserRepository extends Mock implements UserRepository {}

class _MockUserProfile extends Mock implements UserProfile {}

class _MockPrefs extends Mock implements SharedPreferences {}

/// The real repository with the wire cut: the server takes every write.
/// The local write takes one event-loop turn, as the app's Drift on its
/// background isolate does; that turn is when an unlistened auto-dispose
/// controller is torn down.
class _MealLogsNoWire extends MealLogRepository {
  _MealLogsNoWire({required super.database})
    : super(supabase: fakeSupabaseClient(), report: const NoopReport());

  @override
  Future<void> softDeleteLog({
    required String id,
    required String userId,
  }) async {
    await Future<void>.delayed(Duration.zero);
    return super.softDeleteLog(id: id, userId: userId);
  }

  @override
  Future<void> restoreLog({required String id, required String userId}) async {
    await Future<void>.delayed(Duration.zero);
    return super.restoreLog(id: id, userId: userId);
  }

  @override
  Future<void> sendUpsert(
    List<Map<String, dynamic>> rows, {
    bool ignoreDuplicates = false,
  }) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late _MealLogsNoWire logs;
  late RecordingAnalyticsTracker analytics;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    logs = _MealLogsNoWire(database: db);
    analytics = RecordingAnalyticsTracker();

    final profile = _MockUserProfile();
    when(() => profile.id).thenReturn(_user);
    final users = _MockUserRepository();
    when(() => users.getCurrentUser()).thenAnswer((_) async => profile);

    container = ProviderContainer(
      overrides: [
        mealLogRepositoryProvider.overrideWithValue(logs),
        savedMealsRepositoryProvider.overrideWithValue(
          SavedMealsRepository(
            database: db,
            supabase: fakeSupabaseClient(),
            report: const NoopReport(),
          ),
        ),
        userRepositoryProvider.overrideWith((_) async => users),
        appConfigProvider.overrideWithValue(AppConfig.forTesting()),
        appExternalDepsProvider.overrideWithValue(
          AppExternalDeps(
            analytics: analytics,
            supabaseClient: fakeSupabaseClient(),
            sharedPreferences: _MockPrefs(),
          ),
        ),
      ],
    );

    final now = DateTime(2026, 10, 8, 12);
    await logs.insertLog(
      MealLog(
        id: 'log-41',
        userId: _user,
        logDate: '2026-10-08',
        name: 'Lunch soup',
        source: MealLogSource.manual,
        components: const [],
        calories: 320,
        createdAt: now,
        updatedAt: now,
      ),
    );
  });

  tearDown(() async {
    container.dispose();
    // Let the unawaited immediate uploads settle before the table closes.
    await Future<void>.delayed(Duration.zero);
    await db.close();
  });

  Future<bool> isDeleted() async =>
      (await db.select(db.mealLogsTable).get()).single.isDeleted;

  test('deleteLog with no listener, as the Timeline calls it, sends '
      'meal_log_deleted once', () async {
    // No `container.listen`: read the notifier and call, like the screens.
    await container.read(mealLogControllerProvider.notifier).deleteLog(
      'log-41',
    );

    expect(await isDeleted(), isTrue, reason: 'the write itself landed');
    final deleted = analytics.findEvents('meal_log_deleted');
    expect(deleted, hasLength(1));
    expect(deleted.single.properties, {'log_id': 'log-41'});
  });

  test('restoreLog with no listener, as Undo calls it, sends '
      'meal_log_restored once', () async {
    await container.read(mealLogControllerProvider.notifier).deleteLog(
      'log-41',
    );
    await container.read(mealLogControllerProvider.notifier).restoreLog(
      'log-41',
    );

    expect(await isDeleted(), isFalse);
    final restored = analytics.findEvents('meal_log_restored');
    expect(restored, hasLength(1));
    expect(restored.single.properties, {'log_id': 'log-41'});
  });
}
