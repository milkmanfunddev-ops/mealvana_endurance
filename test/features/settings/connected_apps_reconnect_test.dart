// Ticket 64 (Finding 21-004): a connection whose token refresh the provider
// refused for good shows Reconnect in Settings > Connected Apps, not Sync.
//
// The chain runs for real from the provider's answer to the pixels: TP's
// token endpoint answers 400 invalid_grant (the only faked link, an HTTP
// double) → TrainingPeaksSyncService → IntegrationsRepository on in-memory
// Drift → the real ConnectTrainingController's build → ConnectedAppsScreen.
// V.O2's sync service already stored `requires_reauth` before this ticket; its
// row is seeded with that stored value.
//
// Ticket 37 (develop-2026-10): the row holds the code `reauth_required`, and
// the snackbar and the card's error line show its content text, never the
// code.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mealvana_endurance/features/activities/application/activity_deduplication_service.dart';
import 'package:mealvana_endurance/features/activities/data/activities_repository.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/integrations/application/change_detection_service.dart';
import 'package:mealvana_endurance/features/integrations/application/training_peaks_sync_service.dart';
import 'package:mealvana_endurance/features/integrations/application/training_peaks_transformer.dart';
import 'package:mealvana_endurance/features/integrations/data/integrations_repository.dart';
import 'package:mealvana_endurance/features/integrations/data/training_peaks_api_client.dart';
import 'package:mealvana_endurance/features/integrations/domain/integration.dart';
import 'package:mealvana_endurance/features/integrations/domain/integration_exceptions.dart';
import 'package:mealvana_endurance/features/integrations/presentation/providers/integrations_providers.dart';
import 'package:mealvana_endurance/features/integrations/presentation/providers/reconnect_notice_controller.dart';
import 'package:mealvana_endurance/features/settings/presentation/screens/connected_apps_screen.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/providers/user_id_provider.dart';

import '../../helpers/widget_test_harness.dart';
import '../../helpers/test_content.dart';

class _MockUser extends Mock implements User {}

const _profileId = 'local-profile-id';
const _authUid = '00000000-0000-0000-0000-00000000bbbb';

UserProfile _athlete() => UserProfile(
  id: _profileId,
  deviceId: 'device-reconnect-064',
  authUserId: _authUid,
  authProvider: 'email',
  isAnonymous: false,
  gender: Gender.female,
  birthday: DateTime(1994, 7, 1),
  heightFeet: 5,
  heightInches: 8,
  weightPounds: 150,
  runsWithWaterBottle: false,
  onboardingCompleted: true,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 8, 1),
  appVersion: '1.0.0',
);

IntegrationModel _row(String provider, {required bool expired}) =>
    IntegrationModel(
      userId: _profileId,
      provider: provider,
      accessToken: 'stale-access',
      refreshToken: 'stale-refresh',
      tokenExpiresAt: expired
          ? DateTime.now().subtract(const Duration(hours: 3))
          : DateTime.now().add(const Duration(hours: 3)),
      providerAthleteId: '$provider-athlete',
      providerAthleteName: 'Test Athlete',
      isActive: true,
      lastSyncStatus: 'success',
    );

/// TP's OAuth endpoint refusing the refresh token, as it did on 2026-09-24.
TrainingPeaksApiClient _tpRefusingRefresh() => TrainingPeaksApiClient(
  clientId: 'cid',
  clientSecret: 'secret',
  appVersion: 'test',
  httpClient: MockClient((request) async {
    if (request.url.path.endsWith('/oauth/token')) {
      return http.Response(
        jsonEncode({'error': 'invalid_grant'}),
        400,
        headers: {'content-type': 'application/json'},
      );
    }
    fail('unexpected request after a refused refresh: ${request.url}');
  }),
);

void main() {
  late AppDatabase db;
  late IntegrationsRepository repository;
  late ActivitiesRepository activitiesRepository;
  late SupabaseClient supabase;

  setUp(() async {
    db = AppDatabase.memory();
    addTearDown(db.close);

    final authUser = _MockUser();
    when(() => authUser.id).thenReturn(_authUid);
    when(() => authUser.isAnonymous).thenReturn(false);
    final goTrue = fakeGoTrueClient();
    when(() => goTrue.currentUser).thenReturn(authUser);
    supabase = fakeSupabaseClient(auth: goTrue);

    repository = IntegrationsRepository(database: db, supabase: supabase);
    activitiesRepository = ActivitiesRepository(
      supabase: supabase,
      database: db,
      deduplicationService: ActivityDeduplicationService(),
    );
    await db.userDao.saveUserProfile(_athlete());
  });

  Future<void> pumpSettings(
    WidgetTester tester, {
    TrainingPeaksApiClient? tpApi,
  }) async {
    tester.view.physicalSize = standardPhoneSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mockAppExternalDeps(supabaseClient: supabase),
          mockSharedPreferences(),
          inMemoryDatabaseOverride(db),
          integrationsRepositoryProvider.overrideWithValue(repository),
          activitiesRepositoryProvider.overrideWithValue(activitiesRepository),
          userIdProvider.overrideWith((ref) async => _authUid),
          contentServiceProvider.overrideWith(testContentService),
          // Ticket 77: the card also follows a Drift watch of the rows. These
          // tests write Drift from runAsync's real zone, which would wait on a
          // watch query queued in the fake zone (and the watch's close timer
          // outlives the tree). The cards here read the controller's own
          // flags; the watch is driven in connected_apps_garmin_reauth_test
          // and reauth_from_server_row_seam_test.
          integrationsNeedingReconnectProvider(
            _profileId,
          ).overrideWith((ref) => const Stream<Set<String>>.empty()),
          if (tpApi != null)
            trainingPeaksSyncServiceProvider.overrideWith(
              (ref) async => TrainingPeaksSyncService(
                apiClient: tpApi,
                integrationsRepository: repository,
                activitiesRepository: activitiesRepository,
                transformer: const TrainingPeaksTransformer(),
                changeDetectionService: ChangeDetectionService(),
              ),
            ),
        ],
        // Settings mode: no onContinue.
        child: wrapForTest(const ConnectedAppsScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder inCard(String key, Finder matching) =>
      find.descendant(of: find.byKey(ValueKey(key)), matching: matching);

  final content = loadDefaultContent();
  final reconnect = content['settings.connection_reconnect_button']!;
  final note = content['settings.connection_needs_reconnect']!;

  testWidgets(
    'a TrainingPeaks refresh refused with 400 shows Reconnect, not Sync',
    (tester) async {
      await tester.runAsync(() async {
        await repository.upsertIntegration(
          _row('training_peaks', expired: true),
        );
        final result = await TrainingPeaksSyncService(
          apiClient: _tpRefusingRefresh(),
          integrationsRepository: repository,
          activitiesRepository: activitiesRepository,
          transformer: const TrainingPeaksTransformer(),
          changeDetectionService: ChangeDetectionService(),
        ).syncWorkouts(_profileId);
        expect(result.tokenExpired, isTrue);
      });

      await pumpSettings(tester);

      const tp = 'connected_apps.trainingpeaks_connect_button';
      expect(inCard(tp, find.text(reconnect)), findsOneWidget);
      expect(inCard(tp, find.text(note)), findsOneWidget);
      expect(inCard(tp, find.text('Sync Now')), findsNothing);
    },
  );

  testWidgets('a V.O2 connection needing a sign-in shows Reconnect', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await repository.upsertIntegration(_row('vdot', expired: false));
      await repository.updateSyncStatus(
        _profileId,
        'vdot',
        status: requiresReauthStatus,
        error: reauthRequiredCode,
      );
    });

    await pumpSettings(tester);

    const vdot = 'connected_apps.vdot_connect_button';
    expect(inCard(vdot, find.text(reconnect)), findsOneWidget);
    expect(inCard(vdot, find.text('Sync Now')), findsNothing);
    // The stored code never reaches the screen.
    expect(find.textContaining('reauth_required'), findsNothing);
  });

  testWidgets(
    'Sync Now refused by TrainingPeaks: the row holds reauth_required and '
    'the snackbar and card show the content text, never the code',
    (tester) async {
      await tester.runAsync(() async {
        await repository.upsertIntegration(
          _row('training_peaks', expired: true),
        );
      });

      await pumpSettings(tester, tpApi: _tpRefusingRefresh());

      const tp = 'connected_apps.trainingpeaks_connect_button';
      expect(inCard(tp, find.text('Sync Now')), findsOneWidget);
      await tester.tap(inCard(tp, find.text('Sync Now')));
      // The sync runs real Drift and HTTP-double futures.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final row = await tester.runAsync(
        () => repository.getIntegration(_profileId, 'training_peaks'),
      );
      expect(row!.lastSyncStatus, requiresReauthStatus);
      expect(row.lastSyncError, 'reauth_required');

      final reauthText = content['integrations.sync_error_reauth']!
          .replaceAll('{provider}', 'TrainingPeaks');
      // The snackbar.
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text(reauthText),
        ),
        findsOneWidget,
      );
      // The error line under the cards (built once scrolled into view).
      const errorLine = ValueKey('connected_apps.error_line');
      await tester.scrollUntilVisible(
        find.byKey(errorLine),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(tester.widget<Text>(find.byKey(errorLine)).data, reauthText);
      expect(find.textContaining('reauth_required'), findsNothing);
      expect(find.textContaining('Sync failed:'), findsNothing);

      // Let the snackbar's 4 s timer run out inside the test body.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'ticket 47 (32-005): a disconnected row that still stores '
    'requires_reauth shows Connect, not Reconnect',
    (tester) async {
      await tester.runAsync(() async {
        // Run 32's stale rows: inactive, tokens cleared, status kept.
        for (final provider in ['training_peaks', 'vdot']) {
          await repository.upsertIntegration(
            _row(provider, expired: true).copyWith(
              isActive: false,
              accessToken: '',
              lastSyncStatus: requiresReauthStatus,
              lastSyncError: reauthRequiredCode,
            ),
          );
        }
      });

      await pumpSettings(tester);

      for (final card in [
        'connected_apps.trainingpeaks_connect_button',
        'connected_apps.vdot_connect_button',
      ]) {
        expect(inCard(card, find.text('Connect')), findsOneWidget);
        expect(inCard(card, find.text(reconnect)), findsNothing);
        expect(inCard(card, find.text(note)), findsNothing);
        expect(inCard(card, find.text('Sync Now')), findsNothing);
      }
    },
  );

  testWidgets(
    'ticket 47 (32-006): a successful Sync Now stamps the card\'s '
    '"Last synced" without leaving the screen',
    (tester) async {
      final zonesBody = File(
        'docs/integration/api-exploration/training-peaks/examples/'
        'athlete-zones.json',
      ).readAsStringSync();
      // A live token whose grant lacks metrics:read (run 32's fresh row).
      final tpApi = TrainingPeaksApiClient(
        clientId: 'cid',
        clientSecret: 'secret',
        appVersion: 'test',
        httpClient: MockClient((request) async {
          final path = request.url.path;
          if (path.startsWith('/v2/metrics/')) {
            return http.Response('', 401);
          }
          if (path == '/v1/athlete/profile/zones') {
            return http.Response(zonesBody, 200);
          }
          if (path.startsWith('/v2/workouts/') ||
              path.startsWith('/v2/events/')) {
            return http.Response('[]', 200);
          }
          fail('unexpected request: ${request.url}');
        }),
      );
      // The sync coordinator stamps its staleness clock through
      // SharedPreferences.getInstance(), outside the provider override.
      SharedPreferences.setMockInitialValues({});
      await tester.runAsync(() async {
        await repository.upsertIntegration(
          _row('training_peaks', expired: false).copyWith(
            lastSyncAt: DateTime(2026, 9, 28, 12),
          ),
        );
      });

      await pumpSettings(tester, tpApi: tpApi);

      const tp = 'connected_apps.trainingpeaks_connect_button';
      expect(
        inCard(tp, find.textContaining('Last synced: Sep 28')),
        findsOneWidget,
      );
      await tester.tap(inCard(tp, find.text('Sync Now')));
      // The sync runs real Drift and HTTP-double futures.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 500)),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      final row = await tester.runAsync(
        () => repository.getIntegration(_profileId, 'training_peaks'),
      );
      expect(row!.lastSyncStatus, 'success');
      expect(
        inCard(tp, find.text('Last synced: Just now')),
        findsOneWidget,
      );
      expect(inCard(tp, find.textContaining('Sep 28')), findsNothing);

      // Let any snackbar timer run out inside the test body.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('a working connection still shows Sync Now', (tester) async {
    await tester.runAsync(() async {
      await repository.upsertIntegration(
        _row('training_peaks', expired: false),
      );
    });

    await pumpSettings(tester);

    const tp = 'connected_apps.trainingpeaks_connect_button';
    expect(inCard(tp, find.text('Sync Now')), findsOneWidget);
    expect(inCard(tp, find.text(reconnect)), findsNothing);
  });
}
