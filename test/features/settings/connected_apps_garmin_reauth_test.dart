// Ticket 138 (Finding 118-016): Garmin's "Token is not active" needs a
// reconnect. develop's garmin-backfill answers ticket 19's 409
// `garmin_reauth_required`, with `requires_reauth: true` since ticket 138
// (mealplanning's server answers 401 instead); the
// real ConnectTrainingController marks the local garmin row, and Connected
// Apps shows Reconnect in the Garmin card like the other providers.
//
// The chain runs from the edge function's answer (the only faked link: the
// FunctionsClient) through the real controller, the real IntegrationsRepository
// on in-memory Drift, to the pixels.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mealvana_endurance/features/activities/application/activity_deduplication_service.dart';
import 'package:mealvana_endurance/features/activities/data/activities_repository.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/integrations/data/integrations_repository.dart';
import 'package:mealvana_endurance/features/integrations/domain/integration.dart';
import 'package:mealvana_endurance/features/integrations/domain/integration_exceptions.dart';
import 'package:mealvana_endurance/features/integrations/presentation/providers/connect_training_controller.dart';
import 'package:mealvana_endurance/features/integrations/presentation/providers/integrations_providers.dart';
import 'package:mealvana_endurance/features/settings/presentation/screens/connected_apps_screen.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/providers/user_id_provider.dart';
import 'package:mealvana_endurance/shared/services/prefs_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/widget_test_harness.dart';
import '../../helpers/test_content.dart';

class _MockUser extends Mock implements User {}

class _MockSession extends Mock implements Session {}

class _MockFunctions extends Mock implements FunctionsClient {}

const _profileId = 'local-profile-garmin';
const _authUid = '00000000-0000-0000-0000-00000000cccc';

UserProfile _athlete() => UserProfile(
  id: _profileId,
  deviceId: 'device-garmin-138',
  authUserId: _authUid,
  authProvider: 'email',
  isAnonymous: false,
  gender: Gender.male,
  birthday: DateTime(1990, 1, 1),
  heightFeet: 5,
  heightInches: 10,
  weightPounds: 160,
  runsWithWaterBottle: false,
  onboardingCompleted: true,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 8, 1),
  appVersion: '1.0.0',
);

IntegrationModel _garminRow() => IntegrationModel(
  userId: _profileId,
  provider: 'garmin',
  accessToken: 'garmin-access',
  refreshToken: 'garmin-refresh',
  tokenExpiresAt: DateTime.now().add(const Duration(hours: 3)),
  providerAthleteId: 'garmin-user-1',
  providerAthleteName: 'Garmin Athlete',
  isActive: true,
  lastSyncStatus: 'success',
);

void main() {
  late AppDatabase db;
  late IntegrationsRepository repository;
  late ActivitiesRepository activitiesRepository;
  late SupabaseClient supabase;
  late _MockFunctions functions;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.memory();
    addTearDown(db.close);

    final authUser = _MockUser();
    when(() => authUser.id).thenReturn(_authUid);
    when(() => authUser.isAnonymous).thenReturn(false);
    final session = _MockSession();
    when(() => session.accessToken).thenReturn('supabase-jwt');
    final goTrue = fakeGoTrueClient();
    when(() => goTrue.currentUser).thenReturn(authUser);
    when(() => goTrue.currentSession).thenReturn(session);
    supabase = fakeSupabaseClient(auth: goTrue);
    functions = _MockFunctions();
    when(
      () => (supabase as MockSupabaseClient).functions,
    ).thenReturn(functions);

    repository = IntegrationsRepository(database: db, supabase: supabase);
    activitiesRepository = ActivitiesRepository(
      supabase: supabase,
      database: db,
      deduplicationService: ActivityDeduplicationService(),
    );
    await db.userDao.saveUserProfile(_athlete());
    await repository.upsertIntegration(_garminRow());
  });

  /// garmin-backfill's answer when Garmin says "Token is not active".
  void garminRefusesToken() {
    when(
      () => functions.invoke(
        'garmin-backfill',
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      ),
    ).thenThrow(
      // The body garmin-backfill sends (errorResponse + outcome.ts).
      const FunctionException(
        status: 409,
        details: {
          'success': false,
          'error':
              'Garmin connection expired; the athlete must reconnect Garmin',
          'details':
              '{"activities":"{\\"errorMessage\\":\\"Token is not active\\"}"}',
          'code': 'garmin_reauth_required',
          'requires_reauth': true,
        },
      ),
    );
  }

  Future<ProviderContainer> pumpSettings(WidgetTester tester) async {
    tester.view.physicalSize = standardPhoneSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final container = ProviderContainer(
      overrides: [
        mockAppExternalDeps(supabaseClient: supabase),
        sharedPreferencesProvider.overrideWithValue(prefs),
        inMemoryDatabaseOverride(db),
        integrationsRepositoryProvider.overrideWithValue(repository),
        activitiesRepositoryProvider.overrideWithValue(activitiesRepository),
        userIdProvider.overrideWith((ref) async => _authUid),
        contentServiceProvider.overrideWith(testContentService),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: wrapForTest(const ConnectedAppsScreen()),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Finder inCard(String key, Finder matching) =>
      find.descendant(of: find.byKey(ValueKey(key)), matching: matching);

  final content = loadDefaultContent();
  final reconnect = content['settings.connection_reconnect_button']!;
  const garmin = 'connected_apps.garmin_connect_button';

  testWidgets('a working Garmin connection shows Sync Now', (tester) async {
    // The session kick's backfill answers fine.
    when(
      () => functions.invoke(
        'garmin-backfill',
        headers: any(named: 'headers'),
        body: any(named: 'body'),
      ),
    ).thenAnswer(
      (_) async => FunctionResponse(
        status: 200,
        data: const {
          'success': true,
          'queued': {'body_composition': 202},
        },
      ),
    );

    await pumpSettings(tester);

    expect(inCard(garmin, find.text('Sync Now')), findsOneWidget);
    expect(inCard(garmin, find.text(reconnect)), findsNothing);
    // The note names the button it points at (119-008).
    expect(find.textContaining('Tap Sync Now'), findsOneWidget);
    expect(find.textContaining('Tap Refresh'), findsNothing);
    // The successful backfill re-reads body comp 5 s and 20 s later.
    await tester.pump(const Duration(seconds: 21));
  });

  testWidgets(
    "garmin-backfill's requires_reauth marks the row and shows Reconnect",
    (tester) async {
      garminRefusesToken();
      final container = await pumpSettings(tester);

      await tester.runAsync(() async {
        final ok = await container
            .read(connectTrainingControllerProvider.notifier)
            .triggerGarminBackfill();
        expect(ok, isFalse);
      });
      await tester.pumpAndSettle();

      final row = await repository.getIntegration(_profileId, 'garmin');
      expect(row!.lastSyncStatus, requiresReauthStatus);
      expect(row.lastSyncError, isNot(contains('FunctionException')));
      // Ticket 37: the row holds the code; the screen never shows it.
      expect(row.lastSyncError, reauthRequiredCode);
      expect(inCard(garmin, find.text(reconnect)), findsOneWidget);
      expect(inCard(garmin, find.text('Sync Now')), findsNothing);
      expect(find.textContaining('reauth_required'), findsNothing);
    },
  );

  testWidgets('a stored requires_reauth survives a fresh build', (
    tester,
  ) async {
    garminRefusesToken();
    await tester.runAsync(() async {
      await repository.updateSyncStatus(
        _profileId,
        'garmin',
        status: requiresReauthStatus,
        error: reauthRequiredCode,
      );
    });

    await pumpSettings(tester);

    expect(inCard(garmin, find.text(reconnect)), findsOneWidget);
    expect(find.textContaining('reauth_required'), findsNothing);
  });
}
