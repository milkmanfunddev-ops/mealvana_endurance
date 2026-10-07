/// Seam tests through the real `SettingsController.signOut()` (docs/test/README.md,
/// Seam tests): the outgoing account leaves nothing on the device.
///
/// Findings 14-004 (another account's Drift rows survive sign-out), 03-002
/// (the RevenueCat SDK stays identified as the last account) and 02-003
/// (the controller's Ref was read after the auto-dispose that follows a
/// listener-less `ref.read`). Ported from mealplanning (t33); develop has no
/// meal-plan or entitlement tables and identifies RevenueCat for AI credits.
///
/// `build()` is seeded with a fixed state, as the settings suites do; the
/// sign-out path itself is the real one, against a real in-memory Drift
/// database and mocked remotes.
library;

import 'dart:async';

import 'package:drift/drift.dart' show Value, Variable;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mealvana_endurance/features/activities/data/activities_repository.dart';
import 'package:mealvana_endurance/features/ai_credits/data/revenuecat_service.dart';
import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:mealvana_endurance/features/carb_loading/data/carb_loading_repository.dart';
import 'package:mealvana_endurance/features/events/data/events_repository.dart';
import 'package:mealvana_endurance/features/feedback/data/feedback_repository.dart';
import 'package:mealvana_endurance/features/food_preferences/data/food_preferences_repository.dart';
import 'package:mealvana_endurance/features/meal_logging/data/meal_log_repository.dart';
import 'package:mealvana_endurance/features/meal_logging/data/saved_meals_repository.dart';
import 'package:mealvana_endurance/features/settings/domain/settings_state.dart';
import 'package:mealvana_endurance/features/settings/presentation/providers/settings_controller.dart';
import 'package:mealvana_endurance/shared/data/syncable_repository.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/database/database_provider.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';

import '../../helpers/fakes/fake_supabase_client.dart';
import '../../helpers/fakes/recording_report.dart';

// ─── Mocks ───────────────────────────────────────────────────────────────────

class _MockUser extends Mock implements User {}

class _MockAnalytics extends Mock implements AnalyticsTracker {}

class _MockPrefs extends Mock implements SharedPreferences {}

class _MockRevenueCat extends Mock implements RevenueCatService {}

class _MockActivitiesRepo extends Mock implements ActivitiesRepository {}

class _MockEventsRepo extends Mock implements EventsRepository {}

class _MockCarbLoadingRepo extends Mock implements CarbLoadingRepository {}

class _MockFeedbackRepo extends Mock implements FeedbackRepository {}

class _MockFoodPrefsRepo extends Mock implements FoodPreferencesRepository {}

class _MockUserRepo extends Mock implements UserRepository {}

class _MockMealLogRepo extends Mock implements MealLogRepository {}

class _MockSavedMealsRepo extends Mock implements SavedMealsRepository {}

/// Real sign-out on top of a seeded build (the settings suites' pattern).
class _SeededSettingsController extends SettingsController {
  @override
  FutureOr<SettingsState> build() => const SettingsState(
    title: 'Settings',
    profileSectionTitle: 'Profile',
    preferenceSectionTitle: 'Preferences',
    genderLabel: 'Gender',
    birthdayLabel: 'Birthday',
    heightLabel: 'Height',
    weightLabel: 'Weight',
    waterBottleLabel: 'Water Bottle',
    distanceUnitLabel: 'Distance',
    paceUnitLabel: 'Pace',
    gutTrainingLabel: 'Gut Training',
    saveButtonText: 'Save',
    isAnonymous: false,
    authProvider: 'email',
    email: 'outgoing@example.com',
  );
}

const _outgoing = 'aaaaaaaa-0000-4000-8000-000000000001';
const _other = 'bbbbbbbb-0000-4000-8000-000000000002';

void main() {
  late AppDatabase db;
  late MockGoTrueClient auth;
  late _MockAnalytics analytics;
  late RecordingReport report;
  late _MockPrefs prefs;
  late _MockRevenueCat revenueCat;

  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
  });

  setUp(() async {
    db = AppDatabase.memory();
    addTearDown(db.close);

    final user = _MockUser();
    when(() => user.id).thenReturn(_outgoing);
    when(() => user.isAnonymous).thenReturn(false);
    auth = MockGoTrueClient();
    when(() => auth.currentUser).thenReturn(user);
    when(() => auth.currentSession).thenReturn(null);
    when(() => auth.onAuthStateChange).thenAnswer((_) => const Stream.empty());
    when(() => auth.signOut()).thenAnswer((_) async {});

    analytics = _MockAnalytics();
    // A real network round-trip yields the event loop, which is exactly the
    // gap in which the auto-dispose controller went away (02-003).
    when(
      () => analytics.track(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) => Future.delayed(Duration.zero));

    report = RecordingReport();
    prefs = _MockPrefs();
    when(() => prefs.remove(any())).thenAnswer((_) async => true);
    when(() => prefs.getString(any())).thenReturn(null);

    revenueCat = _MockRevenueCat();
    when(() => revenueCat.logOut()).thenAnswer((_) async {});

    await _seedTwoAccounts(db);
  });

  T uploadsNothing<T extends SyncableRepository>(T repo) {
    when(
      () => repo.uploadDirtyRecords(any()),
    ).thenAnswer((_) async => UploadResult.nothingToUpload());
    return repo;
  }

  ProviderContainer makeContainer() {
    final c = ProviderContainer(
      overrides: [
        appExternalDepsProvider.overrideWithValue(
          AppExternalDeps(
            analytics: analytics,
            supabaseClient: fakeSupabaseClient(auth: auth),
            sharedPreferences: prefs,
            report: report,
          ),
        ),
        reportProvider.overrideWithValue(report),
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
        revenueCatServiceProvider.overrideWithValue(revenueCat),
        settingsControllerProvider.overrideWith(_SeededSettingsController.new),
        activitiesRepositoryProvider.overrideWithValue(
          uploadsNothing(_MockActivitiesRepo()),
        ),
        eventsRepositoryProvider.overrideWithValue(
          uploadsNothing(_MockEventsRepo()),
        ),
        carbLoadingRepositoryProvider.overrideWithValue(
          uploadsNothing(_MockCarbLoadingRepo()),
        ),
        feedbackRepositoryProvider.overrideWithValue(
          uploadsNothing(_MockFeedbackRepo()),
        ),
        foodPreferencesRepositoryProvider.overrideWith(
          (ref) async => uploadsNothing(_MockFoodPrefsRepo()),
        ),
        userRepositoryProvider.overrideWith(
          (ref) async => uploadsNothing(_MockUserRepo()),
        ),
        mealLogRepositoryProvider.overrideWithValue(
          uploadsNothing(_MockMealLogRepo()),
        ),
        savedMealsRepositoryProvider.overrideWithValue(
          uploadsNothing(_MockSavedMealsRepo()),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  /// A listener-less `ref.read` of the auto-dispose controller, whose Ref is
  /// gone by the time the awaits return.
  Future<void> signOutUnheld(ProviderContainer c) =>
      c.read(settingsControllerProvider.notifier).signOut();

  test(
    'the signed-out account leaves no local row; another account keeps its rows (14-004)',
    () async {
      final c = makeContainer();
      expect(await _rowsFor(db, _outgoing), isNot(_allZero));

      await signOutUnheld(c);

      expect(await _rowsFor(db, _outgoing), _allZero);
      expect(await _rowsFor(db, _other), isNot(_allZero));
      verify(() => auth.signOut()).called(1);
    },
  );

  test(
    'sign-out logs the RevenueCat SDK out before Supabase (03-002)',
    () async {
      final c = makeContainer();

      await signOutUnheld(c);

      verifyInOrder([() => revenueCat.logOut(), () => auth.signOut()]);
    },
  );

  test(
    'sign-out through a listener-less read reports no fault (02-003)',
    () async {
      final c = makeContainer();

      await signOutUnheld(c);

      expect(report.faults, isEmpty);
      expect(report.degradeds, isEmpty);
    },
  );
}

// ─── Seeds and counts ────────────────────────────────────────────────────────

final _allZero = everyElement(0);

Future<void> _seedTwoAccounts(AppDatabase db) async {
  final now = DateTime.utc(2026, 9, 24, 12);
  for (final userId in [_outgoing, _other]) {
    await db
        .into(db.userProfilesTable)
        .insert(
          UserProfilesTableCompanion.insert(
            id: userId,
            deviceId: 'device-$userId',
            authUserId: Value(userId),
            email: Value('$userId@example.com'),
          ),
        );
    await db
        .into(db.integrationsTable)
        .insert(
          IntegrationsTableCompanion.insert(
            userId: userId,
            provider: 'training_peaks',
            accessToken: 'token',
            providerAthleteId: 'tp-$userId',
            providerAthleteName: const Value('Someone Else'),
            providerAthleteEmail: Value('$userId@tp.example.com'),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.activitiesTable)
        .insert(
          ActivitiesTableCompanion.insert(
            userId: userId,
            activityType: 'running',
            title: 'Easy run',
            scheduledDateTime: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.eventsTable)
        .insert(
          EventsTableCompanion.insert(
            userId: userId,
            eventType: 'running',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.mealLogsTable)
        .insert(
          MealLogsTableCompanion.insert(
            userId: userId,
            logDate: '2026-09-24',
            name: 'Oats',
            source: 'manual',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.foodPreferencesTable)
        .insert(
          FoodPreferencesTableCompanion.insert(
            id: '$userId-pref-000000000000000000000'.substring(0, 36),
            userId: userId,
            foodName: 'cilantro',
            preference: 'dislike',
          ),
        );
    await db
        .into(db.carbLoadingPlansTable)
        .insert(
          CarbLoadingPlansTableCompanion.insert(
            userId: userId,
            totalDays: 3,
            startDate: now,
            endDate: now,
            dailyCarbTargetGrams: 500,
            generatedAt: now,
          ),
        );
  }
}

/// Row counts for [userId], one per table the Findings listed, in a fixed
/// order so a failure names the table by position.
Future<List<int>> _rowsFor(AppDatabase db, String userId) async {
  Future<int> count(String sql) async {
    final rows = await db
        .customSelect(sql, variables: [Variable<String>(userId)])
        .get();
    return rows.single.read<int>('n');
  }

  return [
    await count('SELECT COUNT(*) AS n FROM users WHERE id = ?'),
    await count('SELECT COUNT(*) AS n FROM integrations WHERE user_id = ?'),
    await count('SELECT COUNT(*) AS n FROM activities WHERE user_id = ?'),
    await count('SELECT COUNT(*) AS n FROM events WHERE user_id = ?'),
    await count('SELECT COUNT(*) AS n FROM meal_logs WHERE user_id = ?'),
    await count(
      'SELECT COUNT(*) AS n FROM food_preferences_table WHERE user_id = ?',
    ),
    await count(
      'SELECT COUNT(*) AS n FROM carb_loading_plans WHERE user_id = ?',
    ),
  ];
}
