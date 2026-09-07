// The connect-identity seam test: a platform connect must be readable by the
// onboarding autofill under whatever user id it was written to.
//
// The shipped bug this pins: ConnectTrainingController resolves the LOCAL
// PROFILE id (`user.id`) for a returning athlete, while the first version of
// the autofill provider read under the AUTH uid. For a returning user those
// are different values, so the connect "succeeded" — token stored, workouts
// synced — and every screen downstream saw nothing. The fix walks the same
// candidate ids the controller can resolve and reads the first that holds
// data (`_candidateDataUserIds`).
//
// Patrol cannot catch this class: on iOS the OAuth flow runs inside
// ASWebAuthenticationSession, which Apple sandboxes from UI automation, so no
// automated flow ever reaches "connected". The seam is therefore drawn at
// the ONE boundary we do not own — the OAuth handshake — and everything else
// runs for real: the controller's id resolution, IntegrationsRepository,
// Drift, and the autofill provider's read.
//
// Two details keep this test from being theatre (see the learning notes):
//  - the fake PERSISTS through the real repository, so there is a real row
//    whose user_id can mismatch;
//  - the fake writes under the id it is HANDED — hard-coding one would
//    delete the very value under test.

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mealvana_endurance/features/activities/application/activity_deduplication_service.dart';
import 'package:mealvana_endurance/features/activities/data/activities_repository.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/integrations/application/final_surge_oauth_service.dart';
import 'package:mealvana_endurance/features/integrations/data/integrations_repository.dart';
import 'package:mealvana_endurance/features/integrations/domain/integration.dart';
import 'package:mealvana_endurance/features/integrations/presentation/providers/connect_training_controller.dart';
import 'package:mealvana_endurance/features/integrations/presentation/providers/integrations_providers.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/providers/onboarding_controller.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/providers/onboarding_preview_providers.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/providers/user_id_provider.dart';

import '../../helpers/widget_test_harness.dart';

class _MockFinalSurgeOAuth extends Mock implements FinalSurgeOAuthService {}

class _MockUser extends Mock implements User {}

/// The returning-athlete condition — the whole bug lives in these two ids
/// being different values.
const _localProfileId = 'local-profile-id';
const _authUid = '00000000-0000-0000-0000-00000000aaaa';

UserProfile _returningAthlete() => UserProfile(
  id: _localProfileId,
  deviceId: 'device-seam-001',
  authUserId: _authUid,
  authProvider: 'email',
  isAnonymous: false,
  gender: Gender.female,
  birthday: DateTime(1994, 7, 1),
  heightFeet: 5,
  heightInches: 8,
  weightPounds: 150,
  runsWithWaterBottle: false,
  // Returning athlete: onboarding done, so the controller resolves the
  // local profile id (not the auth uid) as _currentUserId.
  onboardingCompleted: true,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 8, 1),
  appVersion: '1.0.0',
);

void main() {
  late AppDatabase db;
  late IntegrationsRepository repository;
  late _MockFinalSurgeOAuth oauth;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase.memory();
    addTearDown(db.close);

    // Signed-in, NON-anonymous session under the auth uid.
    final authUser = _MockUser();
    when(() => authUser.id).thenReturn(_authUid);
    when(() => authUser.isAnonymous).thenReturn(false);
    final goTrue = fakeGoTrueClient();
    when(() => goTrue.currentUser).thenReturn(authUser);
    final supabase = fakeSupabaseClient(auth: goTrue);

    // REAL repository, in-memory Drift, fake network. Overridden explicitly
    // because integrationsRepositoryProvider constructs its own via
    // Supabase.instance, which does not exist in a test VM.
    repository = IntegrationsRepository(
      database: db,
      supabase: supabase,
      logger: MockAppLogger(),
      sentry: mockSentryReporter(),
    );

    oauth = _MockFinalSurgeOAuth();

    // Same explicit construction as the integrations repository, for the
    // same reason: activitiesRepositoryProvider builds from Supabase.instance.
    final activitiesRepository = ActivitiesRepository(
      supabase: supabase,
      database: db,
      logger: MockAppLogger(),
      sentry: mockSentryReporter(),
      deduplicationService: ActivityDeduplicationService(
        logger: MockAppLogger(),
      ),
    );

    container = ProviderContainer(
      overrides: [
        mockAppExternalDeps(supabaseClient: supabase),
        mockSharedPreferences(),
        inMemoryDatabaseOverride(db),
        integrationsRepositoryProvider.overrideWithValue(repository),
        activitiesRepositoryProvider.overrideWithValue(activitiesRepository),
        userIdProvider.overrideWith((ref) async => _authUid),
        // THE SEAM. The only faked link in the chain: the browser handshake.
        finalSurgeOAuthServiceProvider.overrideWithValue(oauth),
      ],
    );
    addTearDown(container.dispose);

    // The fake mirrors the tail of the real authenticate(): it persists an
    // integration through the REAL repository, under the userId the
    // controller hands it. A fake that merely returned a model would leave
    // no row to read back — the test would pass vacuously.
    when(() => oauth.authenticate(any())).thenAnswer((invocation) async {
      final userId = invocation.positionalArguments.first as String;
      return repository.upsertIntegration(
        IntegrationModel(
          userId: userId,
          provider: 'final_surge',
          accessToken: 'seam-test-token',
          providerAthleteId: 'fs-athlete-42',
          providerAthleteName: 'Xuan Huang',
          providerAthleteEmail: 'xuan@example.com',
          isActive: true,
        ),
      );
    });

    // Returning athlete already in the local database.
    await db.userDao.saveUserProfile(_returningAthlete());
  });

  test('a Final Surge connect is readable by the onboarding autofill '
      'under the id it was written to', () async {
    // Let the controller finish its id resolution, then connect.
    await container.read(connectTrainingControllerProvider.future);
    final connected = await container
        .read(connectTrainingControllerProvider.notifier)
        .connectFinalSurge();
    expect(connected, isTrue, reason: 'the faked handshake must succeed');

    // Precondition proof — the bug condition genuinely holds: the row was
    // written under the LOCAL PROFILE id, and nothing exists under the
    // auth uid. If these two ever point at the same id, this test has
    // stopped exercising the mismatch and must be re-seeded.
    final underProfileId = await repository.getIntegration(
      _localProfileId,
      'final_surge',
    );
    final underAuthUid = await repository.getIntegration(
      _authUid,
      'final_surge',
    );
    expect(
      underProfileId,
      isNotNull,
      reason: 'the connect must persist under the controller-resolved id',
    );
    expect(
      underAuthUid,
      isNull,
      reason:
          'seam integrity: if a row exists under the auth uid too, the '
          'id-mismatch condition is gone and this test proves nothing',
    );

    // The read under test: the autofill provider must find the profile by
    // walking the candidate ids — this exact read returned empty before
    // the fix, stranding "Synced 21 workouts" next to blank name fields.
    final autofill = await container.read(
      onboardingIntegrationProfileProvider.future,
    );
    expect(autofill.firstName, 'Xuan');
    expect(autofill.lastName, 'Huang');
    expect(autofill.email, 'xuan@example.com');
    expect(autofill.detailsSource, 'Final Surge');
  });

  test(
    'disconnecting wipes what the platform gave us — autofill and workouts',
    () async {
      // The disconnect side of the seam, mirroring the real service's tail
      // exactly like authenticate() above: deactivate through the REAL
      // repository, under the id the controller hands it.
      when(() => oauth.disconnect(any())).thenAnswer((invocation) async {
        await repository.deactivateIntegration(
          invocation.positionalArguments.first as String,
          'final_surge',
        );
      });

      // Real activities repository over the same fake network — overridden
      // for the same reason as the integrations one (Supabase.instance).
      final activitiesRepo = container.read(activitiesRepositoryProvider);

      // Connect, then set the stage the way onboarding actually leaves it:
      // the platform's workouts imported, plus one the athlete logged
      // manually (which a disconnect must NOT touch)...
      await container.read(connectTrainingControllerProvider.future);
      await container
          .read(connectTrainingControllerProvider.notifier)
          .connectFinalSurge();

      // Distinct titles/times per seed — identical rows get collapsed by the
      // deduplication pass inside the provider-activity load, which would
      // quietly turn "removed both workouts" into "removed the one keeper".
      Future<void> seedActivity(
        String id, {
        String? provider,
        required String title,
        required DateTime at,
      }) => db
          .into(db.activitiesTable)
          .insert(
            ActivitiesTableCompanion.insert(
              id: Value(id),
              userId: _localProfileId,
              activityType: 'running',
              title: title,
              scheduledDateTime: at,
              createdAt: DateTime(2026, 8, 13),
              updatedAt: DateTime(2026, 8, 13),
              syncedFromProvider: provider == null
                  ? const Value.absent()
                  : Value(provider),
            ),
          );
      await seedActivity(
        'aaaaaaaa-0000-0000-0000-000000000001',
        provider: 'final_surge',
        title: 'Imported easy run',
        at: DateTime(2026, 8, 20, 7),
      );
      await seedActivity(
        'aaaaaaaa-0000-0000-0000-000000000002',
        provider: 'final_surge',
        title: 'Imported long run',
        at: DateTime(2026, 8, 22, 8),
      );
      await seedActivity(
        'aaaaaaaa-0000-0000-0000-000000000003',
        title: 'Manual run',
        at: DateTime(2026, 8, 21, 6),
      );

      // ...and the personal-info screen having applied the autofill: values
      // written into the draft and RECORDED as platform-supplied, except the
      // last name, which the athlete edited and now owns.
      final onboarding = container.read(onboardingControllerProvider.notifier);
      onboarding.updatePersonalInfo(
        firstName: 'Xuan',
        lastName: 'Huang',
        email: 'xuan@example.com',
      );
      onboarding.recordIntegrationAutofill({'firstName', 'lastName', 'email'});
      onboarding.releaseIntegrationAutofill('lastName');

      // The act under test — the REAL disconnect path, not a direct call to
      // clearIntegrationAutofill(): the widget tests already prove the
      // clearing mechanism; this proves disconnect actually invokes it.
      await container
          .read(connectTrainingControllerProvider.notifier)
          .disconnectFinalSurge();

      // 1. The platform's workouts are gone; the manual one survives.
      final remaining = await activitiesRepo.getActivitiesByUserAndProvider(
        _localProfileId,
        'final_surge',
      );
      expect(
        remaining,
        isEmpty,
        reason: 'disconnect must delete every workout the provider imported',
      );
      // Quantified at the table level too, so the assertion cannot be
      // satisfied by dedup hiding rows from the repository query: no
      // provider-sourced row may remain alive.
      final aliveProviderRows =
          await (db.select(db.activitiesTable)..where(
                (t) =>
                    t.syncedFromProvider.equals('final_surge') &
                    t.deletedAt.isNull(),
              ))
              .get();
      expect(aliveProviderRows, isEmpty);
      final manualRow =
          await (db.select(db.activitiesTable)..where(
                (t) => t.id.equals('aaaaaaaa-0000-0000-0000-000000000003'),
              ))
              .getSingle();
      expect(
        manualRow.deletedAt,
        isNull,
        reason:
            'a manually logged workout is the athlete\'s, not the '
            'provider\'s — disconnect must leave it alone',
      );

      // 2. The autofilled draft fields are cleared; the athlete-owned edit
      // survives.
      expect(onboarding.draft.firstName, isNull);
      expect(onboarding.draft.email, isNull);
      expect(
        onboarding.draft.lastName,
        'Huang',
        reason: 'a field the athlete edited is theirs and must survive',
      );

      // 3. The integration row is inactive, so the autofill provider now
      // yields nothing for any later screen.
      final autofill = await container.read(
        onboardingIntegrationProfileProvider.future,
      );
      expect(autofill.hasAnything, isFalse);
    },
  );

  test('an inactive integration does not pre-fill anything', () async {
    // Disconnected-then-reconnected histories leave inactive rows behind;
    // autofilling a stranger's stale identity from one would be worse than
    // filling nothing.
    await repository.upsertIntegration(
      IntegrationModel(
        userId: _localProfileId,
        provider: 'final_surge',
        accessToken: 'stale-token',
        providerAthleteId: 'fs-athlete-42',
        providerAthleteName: 'Someone Else',
        providerAthleteEmail: 'else@example.com',
        isActive: false,
      ),
    );

    final autofill = await container.read(
      onboardingIntegrationProfileProvider.future,
    );
    expect(autofill.hasAnything, isFalse);
  });
}
