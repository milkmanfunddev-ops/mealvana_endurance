/// Seam tests through the real `SettingsController.signOut()` (docs/test/README.md,
/// Seam tests): the outgoing account leaves nothing on the device.
///
/// Findings 14-004 (another account's Drift rows survive sign-out), 03-002
/// (the RevenueCat SDK stays identified as the last account) and 02-003
/// (the controller's Ref was read after the auto-dispose that follows a
/// listener-less `ref.read`). Ported from mealplanning (t33); develop has no
/// meal-plan or entitlement tables and identifies RevenueCat for AI credits.
/// Ticket 102 (Finding 86-007): an offline sign-out keeps the unsynced rows,
/// their parents and the local-only tables, and says so; an online sign-out
/// uploads every syncable repository before the wipe.
/// Ticket 139 (121-007): a delete the server did not confirm changes nothing.
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
import 'package:mealvana_endurance/features/ai_credits/data/revenuecat_service.dart';
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
import 'package:mealvana_endurance/features/onboarding/data/onboarding_survey_repository.dart';
import 'package:mealvana_endurance/features/personal_templates/data/personal_templates_repository.dart';
import 'package:mealvana_endurance/features/settings/application/sign_out_notice.dart';
import 'package:mealvana_endurance/features/settings/domain/account_deletion_exceptions.dart';
import 'package:mealvana_endurance/features/settings/domain/settings_state.dart';
import 'package:mealvana_endurance/features/settings/presentation/providers/settings_controller.dart';
import 'package:mealvana_endurance/features/user_foods/data/user_foods_repository.dart';
import 'package:mealvana_endurance/shared/data/syncable_repository.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/database/database_provider.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';

import '../../helpers/fakes/fake_supabase_client.dart';
import '../../helpers/fakes/recording_report.dart';
import '../../helpers/test_content.dart';

// ─── Mocks ───────────────────────────────────────────────────────────────────

class _MockUser extends Mock implements User {}

class _MockAnalytics extends Mock implements AnalyticsTracker {}

class _MockPrefs extends Mock implements SharedPreferences {}

class _MockRevenueCat extends Mock implements RevenueCatService {}

class _MockFunctionsClient extends Mock implements FunctionsClient {}

class _MockActivitiesRepo extends Mock implements ActivitiesRepository {}

class _MockEventsRepo extends Mock implements EventsRepository {}

class _MockCarbLoadingRepo extends Mock implements CarbLoadingRepository {}

class _MockFeedbackRepo extends Mock implements FeedbackRepository {}

class _MockFoodPrefsRepo extends Mock implements FoodPreferencesRepository {}

class _MockUserRepo extends Mock implements UserRepository {}

class _MockMealLogRepo extends Mock implements MealLogRepository {}

class _MockSavedMealsRepo extends Mock implements SavedMealsRepository {}

class _MockUserFoodsRepo extends Mock implements UserFoodsRepository {}

class _MockIntegrationsRepo extends Mock implements IntegrationsRepository {}

class _MockFormulaPinsRepo extends Mock implements FormulaPinsRepository {}

class _MockOnboardingSurveyRepo extends Mock
    implements OnboardingSurveyRepository {}

class _MockPersonalFormulasRepo extends Mock
    implements PersonalFormulasRepository {}

class _MockPersonalTemplatesRepo extends Mock
    implements PersonalTemplatesRepository {}

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

    report = RecordingReport();
    prefs = _MockPrefs();
    when(() => prefs.remove(any())).thenAnswer((_) async => true);
    when(() => prefs.getString(any())).thenReturn(null);

    revenueCat = _MockRevenueCat();
    when(() => revenueCat.logOut()).thenAnswer((_) async {});

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
    repos = {
      'activities': activities,
      'events': events,
      'carb_loading_plans': carbLoading,
      'feedback': feedback,
      'food_preferences': foodPrefs,
      'users': users,
      'meal_logs': mealLogs,
      'saved_meals': savedMeals,
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
            sharedPreferences: prefs,
            report: report,
          ),
        ),
        reportProvider.overrideWithValue(report),
        sharedPreferencesProvider.overrideWithValue(prefs),
        appDatabaseProvider.overrideWithValue(db),
        revenueCatServiceProvider.overrideWithValue(revenueCat),
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
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  /// The line the athlete sees after an offline sign-out, from the content
  /// defaults (never hand-copied).
  final unsyncedKeptLine =
      loadDefaultContent()[ContentKeys.settingsSignOutUnsyncedKept]!;

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

  group('ticket 102: the wipe keeps unsynced work', () {
    test(
      'upload failing (offline): clean rows go; dirty rows, food preferences '
      'and the local-only tables stay; the line is set',
      () async {
        final c = makeContainer();
        for (final repo in repos.values) {
          when(
            () => repo.uploadDirtyRecords(any()),
          ).thenAnswer((_) async => UploadResult.failed('offline'));
        }
        await _seedUnsyncedWork(db, _outgoing);

        await signOutUnheld(c);

        // Clean rows of the Finding's tables are gone.
        expect(await _count(db, 'activities', _outgoing), 0);
        expect(await _count(db, 'events', _outgoing), 0);
        expect(await _count(db, 'integrations', _outgoing), 0);
        expect(
          await _count(
            db,
            'meal_logs',
            _outgoing,
            where: 'AND needs_upload = 0',
          ),
          0,
        );
        // The offline meal log stays.
        expect(
          await _count(
            db,
            'meal_logs',
            _outgoing,
            where: 'AND needs_upload = 1',
          ),
          1,
        );
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

        await signOutUnheld(c);

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
      verifyNever(() => revenueCat.logOut());
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
      verifyNever(() => revenueCat.logOut());
      verifyNever(() => auth.signOut());
    });
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

/// Unsynced work of [userId] on top of [_seedTwoAccounts]: a second meal log
/// written offline, a race checklist item and a carb-loading user food (both
/// local-only).
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
    await count('SELECT COUNT(*) AS n FROM meal_logs WHERE user_id = ?'),
    await count(
      'SELECT COUNT(*) AS n FROM food_preferences_table WHERE user_id = ?',
    ),
    await count(
      'SELECT COUNT(*) AS n FROM carb_loading_plans WHERE user_id = ?',
    ),
  ];
}
