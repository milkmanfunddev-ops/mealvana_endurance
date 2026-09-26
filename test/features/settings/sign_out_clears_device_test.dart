/// Seam tests through the real `SettingsController.signOut()` (docs/test/README.md,
/// Seam tests): the outgoing account leaves nothing on the device.
///
/// Findings 14-004 (another account's Drift rows survive sign-out), 03-002
/// (the RevenueCat SDK stays identified as the last account) and 02-003
/// (`Pro entitlement clear failed`: the controller's Ref was read after the
/// auto-dispose that follows a listener-less `ref.read` from the paywall).
/// Ticket 102 (Finding 86-007): an offline sign-out keeps the unsynced rows,
/// their parents and the local-only tables, and says so; an online sign-out
/// uploads every syncable repository before the wipe.
/// Ticket 139 (125-001, 120-007, 121-007): Supabase signs out before the Pro
/// status clears, so the Gate never closes on a live session; the event
/// names its source; a delete the server did not confirm changes nothing.
///
/// `build()` is seeded with a fixed state, as the settings suites do; the
/// sign-out path itself is the real one, against a real in-memory Drift
/// database and mocked remotes.
library;

import 'dart:async';
import 'dart:io';

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
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/content/domain/content_keys.dart';
import 'package:mealvana_endurance/features/feedback/data/feedback_repository.dart';
import 'package:mealvana_endurance/features/food_preferences/data/food_preferences_repository.dart';
import 'package:mealvana_endurance/features/formula_kit/data/formula_pins_repository.dart';
import 'package:mealvana_endurance/features/formula_kit/data/personal_formulas_repository.dart';
import 'package:mealvana_endurance/features/integrations/data/integrations_repository.dart';
import 'package:mealvana_endurance/features/integrations/presentation/providers/integrations_providers.dart';
import 'package:mealvana_endurance/features/meal_logging/data/meal_log_repository.dart';
import 'package:mealvana_endurance/features/meal_logging/data/saved_meals_repository.dart';
import 'package:mealvana_endurance/features/meal_planning/data/meal_plan_repository.dart';
import 'package:mealvana_endurance/features/meal_planning/data/user_memory_repository.dart';
import 'package:mealvana_endurance/features/onboarding/data/onboarding_survey_repository.dart';
import 'package:mealvana_endurance/features/personal_templates/data/personal_templates_repository.dart';
import 'package:mealvana_endurance/features/settings/application/sign_out_notice.dart';
import 'package:mealvana_endurance/features/settings/domain/account_deletion_entry.dart';
import 'package:mealvana_endurance/features/settings/domain/account_deletion_exceptions.dart';
import 'package:mealvana_endurance/features/settings/domain/sign_out_source.dart';
import 'package:mealvana_endurance/features/settings/domain/settings_state.dart';
import 'package:mealvana_endurance/features/settings/presentation/providers/settings_controller.dart';
import 'package:mealvana_endurance/features/subscription/application/subscription_status_provider.dart';
import 'package:mealvana_endurance/features/subscription/data/subscription_service.dart';
import 'package:mealvana_endurance/features/subscription/data/user_entitlements_repository.dart';
import 'package:mealvana_endurance/features/subscription/domain/entitlement.dart';
import 'package:mealvana_endurance/features/user_foods/data/user_foods_repository.dart';
import 'package:mealvana_endurance/shared/data/syncable_repository.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/database/database_provider.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/notification_service.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_reporter.dart';

import '../../helpers/fakes/fake_supabase_client.dart';
import '../meal_planning/presentation/helpers/test_content.dart';

// ─── Mocks ───────────────────────────────────────────────────────────────────

class _MockUser extends Mock implements User {}

class _MockAnalytics extends Mock implements AnalyticsTracker {}

class _MockLogger extends Mock implements AppLogger {}

class _MockPrefs extends Mock implements SharedPreferences {}

class _MockSubscriptionService extends Mock implements SubscriptionService {}

class _MockEntitlementsRepo extends Mock
    implements UserEntitlementsRepository {}

class _MockFunctionsClient extends Mock implements FunctionsClient {}

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

class _MockUserFoodsRepo extends Mock implements UserFoodsRepository {}

class _MockIntegrationsRepo extends Mock implements IntegrationsRepository {}

class _MockFormulaPinsRepo extends Mock implements FormulaPinsRepository {}

class _MockOnboardingSurveyRepo extends Mock
    implements OnboardingSurveyRepository {}

class _MockPersonalFormulasRepo extends Mock
    implements PersonalFormulasRepository {}

class _MockPersonalTemplatesRepo extends Mock
    implements PersonalTemplatesRepository {}

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
  late _MockFunctionsClient functions;

  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
    registerFallbackValue(HttpMethod.post);
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

    // delete-user answers 200 unless a test says otherwise (121-007).
    functions = _MockFunctionsClient();
    when(
      () => functions.invoke(
        any(),
        method: any(named: 'method'),
        body: any(named: 'body'),
      ),
    ).thenAnswer(
      (_) async => FunctionResponse(status: 200, data: {'success': true}),
    );

    entitlementsRepo = _MockEntitlementsRepo();
    when(() => entitlementsRepo.currentUserId).thenReturn(_outgoing);
    when(
      () => entitlementsRepo.authUserIdChanges,
    ).thenAnswer((_) => const Stream<String?>.empty());

    await _seedTwoAccounts(db);
  });

  /// Every syncable repository the sign-out uploads, by key, so a test can
  /// verify each one and decide how it answers.
  late Map<String, SyncableRepository> repos;

  T uploadsNothing<T extends SyncableRepository>(T repo) {
    when(
      () => repo.uploadDirtyRecords(any()),
    ).thenAnswer((_) async => UploadResult.nothingToUpload());
    return repo;
  }

  ProviderContainer makeContainer() {
    final userFoods = uploadsNothing(_MockUserFoodsRepo());
    final integrations = uploadsNothing(_MockIntegrationsRepo());
    final formulaPins = uploadsNothing(_MockFormulaPinsRepo());
    final onboardingSurvey = uploadsNothing(_MockOnboardingSurveyRepo());
    final personalFormulas = uploadsNothing(_MockPersonalFormulasRepo());
    final personalTemplates = uploadsNothing(_MockPersonalTemplatesRepo());
    final activities = uploadsNothing(_MockActivitiesRepo());
    final events = uploadsNothing(_MockEventsRepo());
    final carbLoading = uploadsNothing(_MockCarbLoadingRepo());
    final feedback = uploadsNothing(_MockFeedbackRepo());
    final foodPrefs = uploadsNothing(_MockFoodPrefsRepo());
    final users = uploadsNothing(_MockUserRepo());
    final mealLogs = uploadsNothing(_MockMealLogRepo());
    final savedMeals = uploadsNothing(_MockSavedMealsRepo());
    final mealPlans = uploadsNothing(_MockMealPlanRepo());
    final userMemories = uploadsNothing(_MockUserMemoryRepo());
    repos = {
      'activities': activities,
      'events': events,
      'carb_loading_plans': carbLoading,
      'feedback': feedback,
      'food_preferences': foodPrefs,
      'users': users,
      'meal_logs': mealLogs,
      'saved_meals': savedMeals,
      'meal_plans': mealPlans,
      'user_memories': userMemories,
      'user_foods': userFoods,
      'integrations': integrations,
      'formula_pins': formulaPins,
      'onboarding_surveys': onboardingSurvey,
      'personal_formulas': personalFormulas,
      'personal_templates': personalTemplates,
    };
    for (final entry in repos.entries) {
      when(() => entry.value.repositoryKey).thenReturn(entry.key);
    }

    final c = ProviderContainer(
      overrides: [
        contentServiceProvider.overrideWith(testContentService),
        userFoodsRepositoryProvider.overrideWith((ref) async => userFoods),
        integrationsRepositoryProvider.overrideWithValue(integrations),
        formulaPinsRepositoryProvider.overrideWithValue(formulaPins),
        onboardingSurveyRepositoryProvider.overrideWithValue(onboardingSurvey),
        personalFormulasRepositoryProvider.overrideWithValue(personalFormulas),
        personalTemplatesRepositoryProvider.overrideWithValue(
          personalTemplates,
        ),
        appExternalDepsProvider.overrideWithValue(
          AppExternalDeps(
            analytics: analytics,
            supabaseClient: () {
              final client = fakeSupabaseClient(auth: auth);
              when(() => client.functions).thenReturn(functions);
              return client;
            }(),
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
        activitiesRepositoryProvider.overrideWithValue(activities),
        eventsRepositoryProvider.overrideWithValue(events),
        carbLoadingRepositoryProvider.overrideWithValue(carbLoading),
        feedbackRepositoryProvider.overrideWithValue(feedback),
        foodPreferencesRepositoryProvider.overrideWith(
          (ref) async => foodPrefs,
        ),
        userRepositoryProvider.overrideWith((ref) async => users),
        mealLogRepositoryProvider.overrideWithValue(mealLogs),
        savedMealsRepositoryProvider.overrideWithValue(savedMeals),
        mealPlanRepositoryProvider.overrideWithValue(mealPlans),
        userMemoryRepositoryProvider.overrideWithValue(userMemories),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  /// The line the athlete sees after an offline sign-out, from the content
  /// defaults (never hand-copied).
  final unsyncedKeptLine =
      loadDefaultContent()[ContentKeys.settingsSignOutUnsyncedKept]!;

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

  group('ticket 102: the wipe keeps unsynced work', () {
    test(
      'upload failing (offline): clean rows go; dirty rows, their parents, '
      'food preferences and the local-only tables stay; the line is set',
      () async {
        final c = makeContainer();
        for (final repo in repos.values) {
          when(
            () => repo.uploadDirtyRecords(any()),
          ).thenAnswer((_) async => UploadResult.failed('offline'));
        }
        await _seedUnsyncedWork(db, _outgoing);

        await signOutFromPaywall(c);

        // Clean rows of the Finding's tables are gone.
        expect(await _count(db, 'activities', _outgoing), 0);
        expect(await _count(db, 'events', _outgoing), 0);
        expect(await _count(db, 'integrations', _outgoing), 0);
        expect(await _count(db, 'user_entitlements', _outgoing), 0);
        expect(
          await _count(
            db,
            'meal_logs',
            _outgoing,
            where: 'AND needs_upload = 0',
          ),
          0,
        );
        // The offline meal log stays; the offline plan meal keeps its plan.
        expect(
          await _count(
            db,
            'meal_logs',
            _outgoing,
            where: 'AND needs_upload = 1',
          ),
          1,
        );
        expect(await _count(db, 'plan_meals', _outgoing), 1);
        expect(await _count(db, 'meal_plans', _outgoing), 1);
        // The profile stays while unsynced rows stay.
        expect(await _countUsers(db, _outgoing), 1);
        // food_preferences: its own upload failed, so it stays.
        expect(await _count(db, 'food_preferences_table', _outgoing), 1);
        // No server copy: never deleted by a sign-out.
        expect(await _count(db, 'race_checklist_items', _outgoing), 1);
        expect(await _count(db, 'carb_loading_user_foods', _outgoing), 1);
        // The other account is untouched.
        expect(await _rowsFor(db, _other), isNot(_allZero));
        // Sign-out still completes, and says so.
        verify(() => auth.signOut()).called(1);
        expect(c.read(signOutNoticeProvider), unsyncedKeptLine);
      },
    );

    test(
      'upload succeeding: every syncable repository uploads before the wipe, '
      'and no line is set',
      () async {
        final c = makeContainer();
        await _seedUnsyncedWork(db, _outgoing);
        // Each upload sees the account's rows still on the phone.
        final rowsAtUpload = <String, int>{};
        for (final entry in repos.entries) {
          when(() => entry.value.uploadDirtyRecords(any())).thenAnswer((
            _,
          ) async {
            rowsAtUpload[entry.key] = await _count(db, 'meal_logs', _outgoing);
            return UploadResult.successful(1);
          });
        }

        await signOutFromPaywall(c);

        expect(rowsAtUpload.keys, containsAll(repos.keys));
        expect(rowsAtUpload.values, everyElement(2));
        for (final repo in repos.values) {
          verify(() => repo.uploadDirtyRecords(_outgoing)).called(1);
        }
        // The upload marked nothing clean here (mocks), so the dirty rows
        // stay by the wipe rule; the clean ones are gone.
        expect(
          await _count(
            db,
            'meal_logs',
            _outgoing,
            where: 'AND needs_upload = 0',
          ),
          0,
        );
        expect(await _count(db, 'activities', _outgoing), 0);
        expect(c.read(signOutNoticeProvider), isNull);
      },
    );

    test(
      "food preferences whose upload marker is still set stay (wave 27 review)",
      () async {
        final c = makeContainer();
        when(
          () => prefs.getBool(
            FoodPreferencesRepository.uploadPendingKey(_outgoing),
          ),
        ).thenReturn(true);

        await signOutFromPaywall(c);

        expect(await _count(db, 'food_preferences_table', _outgoing), 1);
        expect(await _count(db, 'activities', _outgoing), 0);
      },
    );

    test('account deletion still deletes everything, dirty or not', () async {
      final c = makeContainer();
      await _seedUnsyncedWork(db, _outgoing);

      await c.read(settingsControllerProvider.notifier).deleteAccount();

      expect(await _rowsFor(db, _outgoing), _allZero);
      expect(await _count(db, 'race_checklist_items', _outgoing), 0);
      expect(await _count(db, 'carb_loading_user_foods', _outgoing), 0);
      expect(await _rowsFor(db, _other), isNot(_allZero));
    });
  });

  test(
    'sign-out signs Supabase out first, then logs the RevenueCat SDK out '
    '(125-001; the clear still happens, 03-002)',
    () async {
      final c = makeContainer();

      await signOutFromPaywall(c);

      verifyInOrder([() => auth.signOut(), () => subscription.logOut()]);
      expect(
        c.read(subscriptionStatusProvider).value,
        SubscriptionStatus.none,
      );
    },
  );

  test('the status still clears when the Supabase sign-out throws', () async {
    final c = makeContainer();
    when(() => auth.signOut()).thenThrow(Exception('server 500'));

    await expectLater(signOutFromPaywall(c), throwsA(isA<Exception>()));

    verify(() => subscription.logOut()).called(1);
  });

  group('sign-out names its source (120-007)', () {
    test('from the paywall: source paywall', () async {
      final c = makeContainer();

      await c
          .read(settingsControllerProvider.notifier)
          .signOut(source: SignOutSource.paywall);

      verify(
        () => analytics.track(
          'settings_sign_out_tapped',
          properties: {'source': 'paywall'},
        ),
      ).called(1);
    });

    test('from Settings (the default): source settings', () async {
      final c = makeContainer();

      await c.read(settingsControllerProvider.notifier).signOut();

      verify(
        () => analytics.track(
          'settings_sign_out_tapped',
          properties: {'source': 'settings'},
        ),
      ).called(1);
    });
  });

  group('delete account waits for the server (121-007, 121-009)', () {
    test('delete-user unreachable: rows, RevenueCat identity and session '
        'stay, and the screen hears it needs a connection', () async {
      final c = makeContainer();
      when(
        () => functions.invoke(
          any(),
          method: any(named: 'method'),
          body: any(named: 'body'),
        ),
      ).thenThrow(const SocketException('Network is unreachable'));
      final before = await _rowsFor(db, _outgoing);
      expect(before, isNot(_allZero));

      await expectLater(
        c.read(settingsControllerProvider.notifier).deleteAccount(),
        throwsA(isA<AccountDeletionNeedsConnectionException>()),
      );

      expect(await _rowsFor(db, _outgoing), before);
      verifyNever(() => subscription.logOut());
      verifyNever(() => auth.signOut());
      verifyNever(() => prefs.remove(any()));
      // The shown state is untouched: no error state for the screen to show.
      expect(c.read(settingsControllerProvider).hasValue, isTrue);
      expect(c.read(settingsControllerProvider).hasError, isFalse);
    });

    test('delete-user answers 500: the same, nothing half-deleted', () async {
      final c = makeContainer();
      when(
        () => functions.invoke(
          any(),
          method: any(named: 'method'),
          body: any(named: 'body'),
        ),
      ).thenAnswer(
        (_) async => FunctionResponse(
          status: 500,
          data: {'success': false, 'message': 'Failed to delete auth account'},
        ),
      );

      await expectLater(
        c.read(settingsControllerProvider.notifier).deleteAccount(),
        throwsA(isA<AccountDeletionNeedsConnectionException>()),
      );

      expect(await _rowsFor(db, _outgoing), isNot(_allZero));
      verifyNever(() => subscription.logOut());
      verifyNever(() => auth.signOut());
    });

    test('delete-user answers 200: the wipe, the logout and the sign-out '
        'follow, in that order', () async {
      final c = makeContainer();

      await c.read(settingsControllerProvider.notifier).deleteAccount();

      expect(await _rowsFor(db, _outgoing), _allZero);
      verifyInOrder([
        () => functions.invoke(
          'delete-user',
          method: HttpMethod.post,
          body: any(named: 'body'),
        ),
        () => subscription.logOut(),
        () => auth.signOut(),
      ]);
    });
  });

  group('delete account names where it came from (04-001)', () {
    // The paywall's menu and Settings share the real delete path; only the
    // event name tells a new account deleting itself on the paywall apart
    // from a delete in Settings.
    test('from the paywall: paywall_delete_account_tapped', () async {
      final c = makeContainer();

      await c
          .read(settingsControllerProvider.notifier)
          .deleteAccount(from: AccountDeletionEntry.paywall);

      verify(() => analytics.track('paywall_delete_account_tapped')).called(1);
      verifyNever(() => analytics.track('settings_delete_account_tapped'));
    });

    test('from Settings: settings_delete_account_tapped', () async {
      final c = makeContainer();

      await c.read(settingsControllerProvider.notifier).deleteAccount();

      verify(() => analytics.track('settings_delete_account_tapped')).called(1);
      verifyNever(() => analytics.track('paywall_delete_account_tapped'));
    });
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
            // The table defaults to dirty; these rows are synced.
            needsUpload: const Value(false),
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

/// Unsynced work of [userId] on top of [_seedTwoAccounts]: a second meal log
/// written offline, a plan meal edited offline, a race checklist item and a
/// carb-loading user food (both local-only).
Future<void> _seedUnsyncedWork(AppDatabase db, String userId) async {
  final now = DateTime.utc(2026, 9, 25, 12);
  await db
      .into(db.mealLogsTable)
      .insert(
        MealLogsTableCompanion.insert(
          userId: userId,
          logDate: '2026-09-25',
          name: 'Offline oats',
          source: 'manual',
          createdAt: now,
          updatedAt: now,
          needsUpload: const Value(true),
        ),
      );
  await db.customStatement(
    'UPDATE plan_meals SET needs_upload = 1 WHERE user_id = ?',
    [userId],
  );
  await db
      .into(db.raceChecklistItemsTable)
      .insert(
        RaceChecklistItemsTableCompanion.insert(
          eventId: 'event-$userId',
          userId: userId,
          category: 'gear',
          itemName: 'Shoes',
        ),
      );
  await db
      .into(db.carbLoadingUserFoodsTable)
      .insert(
        CarbLoadingUserFoodsTableCompanion.insert(
          id: 'cluf-$userId',
          deviceId: 'device-$userId',
          userId: userId,
          name: 'my_pasta',
          displayName: 'My pasta',
          carbsPerServing: 65,
        ),
      );
}

Future<int> _count(
  AppDatabase db,
  String table,
  String userId, {
  String where = '',
}) async {
  final rows = await db
      .customSelect(
        'SELECT COUNT(*) AS n FROM $table WHERE user_id = ? $where',
        variables: [Variable<String>(userId)],
      )
      .get();
  return rows.single.read<int>('n');
}

Future<int> _countUsers(AppDatabase db, String userId) async {
  final rows = await db
      .customSelect(
        'SELECT COUNT(*) AS n FROM users WHERE id = ? OR auth_user_id = ?',
        variables: [Variable<String>(userId), Variable<String>(userId)],
      )
      .get();
  return rows.single.read<int>('n');
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
