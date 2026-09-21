// Signing in over a sessionless onboarding id (mp-459).
//
// With no anonymous session, the connect step before sign-up writes its
// rows under a temp id kept in prefs (`onboarding_temp_user_id`). The
// sign-in services still hand that id to `completeAuthentication` as the
// "previous user". It was an auth uid once; now it is only a local key with
// no profile row behind it, and `migrateAnonymousUserData` returned early on
// exactly that ("No anonymous profile found") while the caller then cleared
// the pref — orphaning the connection and the workouts under a dead id.
//
// Two rules pinned here:
//  1. A previous id with no local profile is treated as a fresh login and
//     reports nothing migrated; the rows stay where they are for
//     `saveAllOnboardingData` to re-key onto the account.
//  2. The sign-in call site keeps the temp pref when nothing was migrated,
//     so that re-key can find it.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    hide AuthUser, AuthException;

import 'package:mealvana_endurance/features/auth/application/auth_migration_service.dart';
import 'package:mealvana_endurance/features/auth/application/email_auth_service.dart';
import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/sync/sync_coordinator.dart';

import '../../helpers/widget_test_harness.dart';

class _MockUserRepository extends Mock implements UserRepository {}

class _MockUser extends Mock implements User {}

class _MockSession extends Mock implements Session {}

class _MockAuthResponse extends Mock implements AuthResponse {}

class _MockAuthMigrationService extends Mock implements AuthMigrationService {}

class _FakeUserProfile extends Fake implements UserProfile {}

class _NoopSyncCoordinator extends SyncCoordinator {
  @override
  SyncState build() => SyncState.idle;

  @override
  Future<bool> sync({
    required String userId,
    SyncTrigger trigger = SyncTrigger.manual,
    bool skipInvalidation = false,
  }) async => true;
}

const _tempId = 'temp-onboarding-0001';
const _accountUid = '00000000-0000-0000-0000-0000000000ac';

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeUserProfile());
  });

  group('AuthMigrationService.completeAuthentication', () {
    test(
      'a previous id with no profile row is a fresh login, nothing migrated',
      () async {
        final db = AppDatabase.memory();
        addTearDown(db.close);
        final repo = _MockUserRepository();
        // The temp id holds rows (a synced workout) but no profile.
        when(
          () => repo.getUserProfileById(_tempId),
        ).thenAnswer((_) async => null);
        when(
          () => repo.hasLocalDataWorthMigrating(_tempId),
        ).thenAnswer((_) async => true);
        when(
          () => repo.checkUserHasData(_tempId),
        ).thenAnswer((_) async => false);
        // A brand-new account: nothing remote yet.
        when(
          () => repo.fetchAndSaveRemoteProfile(_accountUid),
        ).thenAnswer((_) async => null);
        when(
          () => repo.saveUserProfile(
            any(),
            needsUpload: any(named: 'needsUpload'),
          ),
        ).thenAnswer((_) async {});
        when(
          () => repo.createUserInSupabase(any(), any()),
        ).thenAnswer((invocation) async => invocation.positionalArguments[1]);

        final goTrue = fakeGoTrueClient();
        final service = AuthMigrationService(
          userRepository: repo,
          database: db,
          supabase: fakeSupabaseClient(auth: goTrue),
          sentry: mockSentryReporter(),
        );

        final migrated = await service.completeAuthentication(
          previousUserId: _tempId,
          wasAnonymous: true,
          newUserId: _accountUid,
          authProvider: 'google',
        );

        expect(migrated, isFalse, reason: 'a temp id is not a user to merge');
        // The fresh-login path ran: the account got its stub profile...
        final saved =
            verify(
                  () => repo.saveUserProfile(
                    captureAny(),
                    needsUpload: any(named: 'needsUpload'),
                  ),
                ).captured.single
                as UserProfile;
        expect(saved.id, _accountUid);
        expect(saved.isAnonymous, isFalse);
        // ...and the merge that would have deleted the account's rows and
        // re-keyed under a profile that does not exist never started.
        verifyNever(() => repo.checkUserHasData(_tempId));
      },
    );
  });

  group('EmailAuthService.signInWithEmail', () {
    test('keeps the temp onboarding id when nothing was migrated', () async {
      final user = _MockUser();
      when(() => user.id).thenReturn(_accountUid);
      when(() => user.email).thenReturn('ava@example.com');
      when(() => user.isAnonymous).thenReturn(false);
      final response = _MockAuthResponse();
      when(() => response.user).thenReturn(user);
      when(() => response.session).thenReturn(_MockSession());

      final goTrue = fakeGoTrueClient() as MockGoTrueClient;
      when(
        () => goTrue.signInWithPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => response);

      final prefs = MockSharedPreferences();
      when(() => prefs.getString(any())).thenReturn(null);
      when(
        () => prefs.getString('onboarding_temp_user_id'),
      ).thenReturn(_tempId);
      when(() => prefs.remove(any())).thenAnswer((_) async => true);

      final migration = _MockAuthMigrationService();
      when(
        () => migration.completeAuthentication(
          previousUserId: any(named: 'previousUserId'),
          wasAnonymous: any(named: 'wasAnonymous'),
          newUserId: any(named: 'newUserId'),
          authProvider: any(named: 'authProvider'),
          preservedUserId: any(named: 'preservedUserId'),
        ),
      ).thenAnswer((_) async => false);

      final analytics = MockAnalyticsTracker();
      when(
        () => analytics.track(any(), properties: any(named: 'properties')),
      ).thenAnswer((_) async {});

      final container = ProviderContainer(
        overrides: [
          appExternalDepsProvider.overrideWithValue(
            AppExternalDeps(
              analytics: analytics,
              supabaseClient: fakeSupabaseClient(auth: goTrue),
              sentry: mockSentryReporter(),
              logger: MockAppLogger(),
              sharedPreferences: prefs,
            ),
          ),
          analyticsTrackerProvider.overrideWithValue(analytics),
          sharedPreferencesProvider.overrideWithValue(prefs),
          authMigrationServiceProvider.overrideWith((ref) async => migration),
          syncCoordinatorProvider.overrideWith(_NoopSyncCoordinator.new),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(emailAuthServiceProvider.notifier)
          .signInWithEmail(email: 'ava@example.com', password: 'password123');

      // The temp id was offered as the previous user...
      final captured = verify(
        () => migration.completeAuthentication(
          previousUserId: captureAny(named: 'previousUserId'),
          wasAnonymous: any(named: 'wasAnonymous'),
          newUserId: any(named: 'newUserId'),
          authProvider: any(named: 'authProvider'),
          preservedUserId: any(named: 'preservedUserId'),
        ),
      ).captured;
      expect(captured.single, _tempId);
      // ...and, nothing having moved, the pref stays for the onboarding save
      // to re-key the rows under it.
      verifyNever(() => prefs.remove('onboarding_temp_user_id'));
    });
  });
}
