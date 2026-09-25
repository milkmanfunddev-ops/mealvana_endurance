/// Seam tests through the real `SettingsController.signOut()` (docs/test/README.md,
/// Seam tests): the outgoing account leaves nothing on the device.
///
/// Findings 14-004 (another account's Drift rows survive sign-out), 03-002
/// (the RevenueCat SDK stays identified as the last account) and 02-003
/// (`Pro entitlement clear failed`: the controller's Ref was read after the
/// auto-dispose that follows a listener-less `ref.read` from the paywall).
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
import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:mealvana_endurance/features/carb_loading/data/carb_loading_repository.dart';
import 'package:mealvana_endurance/features/events/data/events_repository.dart';
import 'package:mealvana_endurance/features/feedback/data/feedback_repository.dart';
import 'package:mealvana_endurance/features/food_preferences/data/food_preferences_repository.dart';
import 'package:mealvana_endurance/features/meal_logging/data/meal_log_repository.dart';
import 'package:mealvana_endurance/features/meal_logging/data/saved_meals_repository.dart';
import 'package:mealvana_endurance/features/meal_planning/data/meal_plan_repository.dart';
import 'package:mealvana_endurance/features/meal_planning/data/user_memory_repository.dart';
import 'package:mealvana_endurance/features/settings/domain/settings_state.dart';
import 'package:mealvana_endurance/features/settings/presentation/providers/settings_controller.dart';
import 'package:mealvana_endurance/features/subscription/application/subscription_status_provider.dart';
import 'package:mealvana_endurance/features/subscription/data/subscription_service.dart';
import 'package:mealvana_endurance/features/subscription/data/user_entitlements_repository.dart';
import 'package:mealvana_endurance/features/subscription/domain/entitlement.dart';
import 'package:mealvana_endurance/shared/data/syncable_repository.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/database/database_provider.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/notification_service.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';

import '../../helpers/fakes/fake_supabase_client.dart';

// ─── Mocks ───────────────────────────────────────────────────────────────────

class _MockUser extends Mock implements User {}

class _MockAnalytics extends Mock implements AnalyticsTracker {}

class _MockLogger extends Mock implements AppLogger {}

class _MockPrefs extends Mock implements SharedPreferences {}

class _MockSubscriptionService extends Mock implements SubscriptionService {}

class _MockEntitlementsRepo extends Mock
    implements UserEntitlementsRepository {}

class _MockActivitiesRepo extends Mock implements ActivitiesRepository {}

class _MockEventsRepo extends Mock implements EventsRepository {}

class _MockCarbLoadingRepo extends Mock implements CarbLoadingRepository {}

class _MockFeedbackRepo extends Mock implements FeedbackRepository {}

class _MockFoodPrefsRepo extends Mock implements FoodPreferencesRepository {}

class _MockUserRepo extends Mock implements UserRepository {}

class _MockMealLogRepo extends Mock implements MealLogRepository {}

class _MockSavedMealsRepo extends Mock implements SavedMealsRepository {}

class _MockMealPlanRepo extends Mock implements MealPlanRepository {}

class _MockUserMemoryRepo extends Mock implements UserMemoryRepository {}

class _FakeScheduler implements LocalNotificationScheduler {
  @override
  Future<bool> scheduleOnce({
    required int id,
    required DateTime when,
    required String title,
    required String body,
    String? payload,
  }) async => true;

  @override
  Future<void> cancel(int id) async {}
}

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
  late _MockLogger logger;
  late _MockPrefs prefs;
  late _MockSubscriptionService subscription;
  late _MockEntitlementsRepo entitlementsRepo;

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

    logger = _MockLogger();
    prefs = _MockPrefs();
    when(() => prefs.remove(any())).thenAnswer((_) async => true);
    when(() => prefs.getString(any())).thenReturn(null);

    subscription = _MockSubscriptionService();
    when(() => subscription.setStatusListener(any())).thenReturn(null);
    when(
      () => subscription.currentAppUserId(),
    ).thenAnswer((_) async => _outgoing);
    when(() => subscription.logIn(any())).thenAnswer((_) async {});
    when(() => subscription.logOut()).thenAnswer((_) async {});
    when(
      () => subscription.fetchStatus(),
    ).thenAnswer((_) async => SubscriptionStatus.none);

    entitlementsRepo = _MockEntitlementsRepo();
    when(() => entitlementsRepo.currentUserId).thenReturn(_outgoing);
    when(
      () => entitlementsRepo.authUserIdChanges,
    ).thenAnswer((_) => const Stream<String?>.empty());

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
            sentry: const NoopSentryReporter(),
            logger: logger,
            sharedPreferences: prefs,
          ),
        ),
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
        subscriptionServiceProvider.overrideWithValue(subscription),
        userEntitlementsRepositoryProvider.overrideWithValue(entitlementsRepo),
        localNotificationSchedulerProvider.overrideWithValue(_FakeScheduler()),
        entitlementAnswerTimeoutProvider.overrideWithValue(
          const Duration(milliseconds: 20),
        ),
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
        mealPlanRepositoryProvider.overrideWithValue(
          uploadsNothing(_MockMealPlanRepo()),
        ),
        userMemoryRepositoryProvider.overrideWithValue(
          uploadsNothing(_MockUserMemoryRepo()),
        ),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  /// The paywall's call shape: a listener-less `ref.read` of the auto-dispose
  /// controller, whose Ref is gone by the time the awaits return.
  Future<void> signOutFromPaywall(ProviderContainer c) =>
      c.read(settingsControllerProvider.notifier).signOut();

  test(
    'the signed-out account leaves no local row; another account keeps its rows (14-004)',
    () async {
      final c = makeContainer();
      expect(await _rowsFor(db, _outgoing), isNot(_allZero));

      await signOutFromPaywall(c);

      expect(await _rowsFor(db, _outgoing), _allZero);
      expect(await _rowsFor(db, _other), isNot(_allZero));
      verify(() => auth.signOut()).called(1);
    },
  );

  test('sign-out logs the RevenueCat SDK out before Supabase (03-002)', () async {
    final c = makeContainer();

    await signOutFromPaywall(c);

    verifyInOrder([
      () => subscription.logOut(),
      () => auth.signOut(),
    ]);
  });

  test('sign-out from the paywall logs no error (02-003)', () async {
    final c = makeContainer();

    await signOutFromPaywall(c);

    verifyNever(
      () => logger.error(
        any(),
        context: any(named: 'context'),
        error: any(named: 'error'),
        data: any(named: 'data'),
        stackTrace: any(named: 'stackTrace'),
      ),
    );
  });
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
    final planId = 'plan-$userId';
    await db
        .into(db.mealPlansTable)
        .insert(
          MealPlansTableCompanion.insert(
            id: Value(planId),
            userId: userId,
            weekStart: '2026-09-21',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.planMealsTable)
        .insert(
          PlanMealsTableCompanion.insert(
            planId: planId,
            userId: userId,
            source: 'library',
            name: 'Brown rice, zucchini & chickpea bowl',
            mealType: 'dinner',
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
    await db
        .into(db.userEntitlementsTable)
        .insert(
          UserEntitlementsTableCompanion.insert(
            userId: userId,
            entitlement: 'pro',
            active: const Value(true),
            updatedAt: now,
            fetchedAt: now,
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
    await count('SELECT COUNT(*) AS n FROM meal_plans WHERE user_id = ?'),
    await count('SELECT COUNT(*) AS n FROM plan_meals WHERE user_id = ?'),
    await count('SELECT COUNT(*) AS n FROM meal_logs WHERE user_id = ?'),
    await count(
      'SELECT COUNT(*) AS n FROM food_preferences_table WHERE user_id = ?',
    ),
    await count(
      'SELECT COUNT(*) AS n FROM carb_loading_plans WHERE user_id = ?',
    ),
    await count(
      'SELECT COUNT(*) AS n FROM user_entitlements WHERE user_id = ?',
    ),
  ];
}
