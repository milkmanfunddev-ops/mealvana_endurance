// A cancelled provider sign-in is the athlete's turn, not a failure
// (develop-2026-10 ticket 55, 50-007).
//
// All four OAuth connects (V.O2, TrainingPeaks, Final Surge, Garmin) call
// `FlutterWebAuth2.authenticate` with no catch, so closing the sheet throws
// the plugin's `PlatformException(CANCELED)` straight into
// `ConnectTrainingController._connectProvider`'s one catch. The seam is the
// OAuth service's `authenticate` (the browser handshake, which cannot run
// headless); it throws exactly what the plugin throws. The controller, the
// repositories over in-memory Drift, the report and the tracker are real or
// recording fakes.
//
// Cancel: no fault, no degraded, one `expected_failure {area: vdot, reason:
// oauth_cancelled}`, no `integration_connect_failed`, no error line in state.
// Any other plugin error still faults and tracks the failure.

import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mealvana_endurance/features/activities/application/activity_deduplication_service.dart';
import 'package:mealvana_endurance/features/activities/data/activities_repository.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/daily_macros/data/daily_macro_targets_repository.dart';
import 'package:mealvana_endurance/features/integrations/application/vdot_oauth_service.dart';
import 'package:mealvana_endurance/features/integrations/data/integrations_repository.dart';
import 'package:mealvana_endurance/features/integrations/presentation/providers/connect_training_controller.dart';
import 'package:mealvana_endurance/features/integrations/presentation/providers/integrations_providers.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/providers/user_id_provider.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';

import '../../helpers/fakes/recording_analytics_tracker.dart';
import '../../helpers/fakes/recording_report.dart';
import '../../helpers/widget_test_harness.dart';

class _MockVdotOAuth extends Mock implements VdotOAuthService {}

class _MockUser extends Mock implements User {}

const _profileId = 'local-profile-id';
const _authUid = '00000000-0000-0000-0000-00000000bbbb';

UserProfile _athlete() => UserProfile(
  id: _profileId,
  deviceId: 'device-seam-055',
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

void main() {
  late AppDatabase db;
  late _MockVdotOAuth oauth;
  late RecordingReport report;
  late RecordingAnalyticsTracker analytics;
  late ProviderContainer container;

  setUp(() async {
    db = AppDatabase.memory();
    addTearDown(db.close);

    final authUser = _MockUser();
    when(() => authUser.id).thenReturn(_authUid);
    when(() => authUser.isAnonymous).thenReturn(false);
    final goTrue = fakeGoTrueClient();
    when(() => goTrue.currentUser).thenReturn(authUser);
    final supabase = fakeSupabaseClient(auth: goTrue);

    report = RecordingReport();
    analytics = RecordingAnalyticsTracker();
    oauth = _MockVdotOAuth();

    container = ProviderContainer(
      overrides: [
        appExternalDepsProvider.overrideWithValue(
          AppExternalDeps(
            analytics: analytics,
            supabaseClient: supabase,
            sharedPreferences: MockSharedPreferences(),
            report: report,
          ),
        ),
        reportProvider.overrideWithValue(report),
        mockSharedPreferences(),
        inMemoryDatabaseOverride(db),
        integrationsRepositoryProvider.overrideWithValue(
          IntegrationsRepository(
            database: db,
            supabase: supabase,
            report: RecordingReport(),
          ),
        ),
        activitiesRepositoryProvider.overrideWithValue(
          ActivitiesRepository(
            supabase: supabase,
            database: db,
            report: RecordingReport(),
            deduplicationService: ActivityDeduplicationService(),
          ),
        ),
        // Built from Supabase.instance in the app; a connect reads it before
        // the handshake, so it is given one here (or it faults on its own).
        dailyMacroTargetsRepositoryProvider.overrideWithValue(
          DailyMacroTargetsRepository(
            database: db,
            supabase: supabase,
            report: RecordingReport(),
          ),
        ),
        userIdProvider.overrideWith((ref) async => _authUid),
        // THE SEAM: the browser handshake.
        vdotOAuthServiceProvider.overrideWithValue(oauth),
      ],
    );
    addTearDown(container.dispose);
    container.listen(connectTrainingControllerProvider, (_, _) {});

    await db.userDao.saveUserProfile(_athlete());
    await container.read(connectTrainingControllerProvider.future);
  });

  Future<bool> connectVdot() =>
      container.read(connectTrainingControllerProvider.notifier).connectVdot();

  ConnectTrainingState state() =>
      container.read(connectTrainingControllerProvider).requireValue;

  test('Cancel on the V.O2 sheet: no fault, no degraded, one '
      'oauth_cancelled count, no connect_failed, no error line', () async {
    when(() => oauth.authenticate(any())).thenThrow(
      PlatformException(code: 'CANCELED', message: 'User canceled login'),
    );

    expect(await connectVdot(), isFalse);

    expect(report.faults, isEmpty);
    expect(report.degradeds, isEmpty);
    expect(report.notes.where((n) => n.area == 'vdot'), hasLength(1));
    expect(analytics.findEvents(expectedFailureEvent).single.properties, {
      'area': 'vdot',
      'reason': 'oauth_cancelled',
    });
    expect(analytics.findEvents('integration_connect_failed'), isEmpty);
    expect(state().isConnecting, isFalse);
    expect(state().connectingProvider, isNull);
    expect(state().errorMessage, isNull);
    expect(state().isVdotConnected, isFalse);
  });

  test(
    'any other plugin error still faults once and tracks the failure',
    () async {
      when(() => oauth.authenticate(any())).thenThrow(
        PlatformException(code: 'ERROR', message: 'Something went wrong'),
      );

      expect(await connectVdot(), isFalse);

      expect(report.faults, hasLength(1));
      expect(report.faults.single.area, 'vdot');
      expect(analytics.findEvents(expectedFailureEvent), isEmpty);
      expect(analytics.findEvents('integration_connect_failed'), hasLength(1));
      expect(state().isConnecting, isFalse);
      expect(state().errorMessage, isNotNull);
    },
  );
}
