// Finding 02-001: a signed-out phone that still held another account's
// profile and TrainingPeaks connection pre-filled that person's name and
// email into a stranger's onboarding, and saved the email onto the new
// account.
//
// The prefill provider read under "the newest local profile", whoever it
// belonged to. ConnectTrainingController never writes under that id when
// nobody is signed in (it uses the session's profile, else a temp id), so
// the prefill has no business reading under it either. The rows are real
// (in-memory Drift through the real IntegrationsRepository); only the auth
// session is faked.

import 'package:drift/drift.dart' show Value;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mealvana_endurance/features/integrations/data/integrations_repository.dart';
import 'package:mealvana_endurance/features/integrations/presentation/providers/integrations_providers.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/providers/onboarding_preview_providers.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';

import '../../helpers/widget_test_harness.dart';

class _MockUser extends Mock implements User {}

const _strangerProfileId = 'stranger-profile-id';
const _strangerAuthUid = '00000000-0000-0000-0000-0000000000ab';

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.memory();
    addTearDown(db.close);

    // Someone else's profile and live TrainingPeaks connection, left on the
    // device (the profile row still names its auth uid).
    final now = DateTime.utc(2026, 9, 23);
    await db
        .into(db.userProfilesTable)
        .insert(
          UserProfilesTableCompanion.insert(
            id: _strangerProfileId,
            deviceId: 'device-shared',
            authUserId: const Value(_strangerAuthUid),
            authProvider: const Value('email'),
            isAnonymous: const Value(false),
            onboardingCompleted: const Value(true),
            firstName: const Value('Xuan'),
            email: const Value('xuan@mealvana.io'),
            updatedAt: Value(now),
          ),
        );
    await db
        .into(db.integrationsTable)
        .insert(
          IntegrationsTableCompanion.insert(
            userId: _strangerProfileId,
            provider: 'training_peaks',
            accessToken: 'token',
            providerAthleteId: 'tp-1',
            providerAthleteName: const Value('Xuan Huang'),
            providerAthleteEmail: const Value('xuan@mealvana.io'),
            providerAthleteGender: const Value('f'),
            isActive: const Value(true),
            createdAt: now,
            updatedAt: now,
          ),
        );
  });

  ProviderContainer makeContainer({required User? signedIn}) {
    final goTrue = fakeGoTrueClient();
    when(() => goTrue.currentUser).thenReturn(signedIn);
    final supabase = fakeSupabaseClient(auth: goTrue);
    final repository = IntegrationsRepository(
      database: db,
      supabase: supabase,
      logger: MockAppLogger(),
      sentry: mockSentryReporter(),
    );
    final c = ProviderContainer(
      overrides: [
        mockAppExternalDeps(supabaseClient: supabase),
        mockSharedPreferences(),
        inMemoryDatabaseOverride(db),
        integrationsRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test(
    'signed out, another account\'s connection pre-fills nothing (02-001)',
    () async {
      final c = makeContainer(signedIn: null);

      final profile = await c.read(onboardingIntegrationProfileProvider.future);

      expect(profile.hasAnything, isFalse);
      expect(profile.firstName, isNull);
      expect(profile.email, isNull);
    },
  );

  test('signed in as the profile\'s owner, the connection still pre-fills', () async {
    // Control: the returning-athlete path (connect_identity_seam_test)
    // keeps working — a profile the session owns is read under its own id.
    final owner = _MockUser();
    when(() => owner.id).thenReturn(_strangerAuthUid);
    when(() => owner.isAnonymous).thenReturn(false);
    final c = makeContainer(signedIn: owner);

    final profile = await c.read(onboardingIntegrationProfileProvider.future);

    expect(profile.firstName, 'Xuan');
    expect(profile.email, 'xuan@mealvana.io');
    expect(profile.detailsSource, 'TrainingPeaks');
  });
}
