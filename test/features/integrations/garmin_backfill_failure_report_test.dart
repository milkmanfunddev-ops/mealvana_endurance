// Ticket 19 (Sentry MEALVANA-ENDURANCE-AA / AB): what the app reports when
// garmin-backfill refuses.
//
// garmin-backfill used to answer 502 for every all-failed backfill. Prod logs
// (2026-10-01/02) showed most of those were a DEAD Garmin token: the refresh
// grant came back `invalid_grant`, then Garmin said `401 Token is not active`.
// The function now answers 409 `code: garmin_reauth_required` for that case
// (supabase/functions/garmin-backfill/outcome.ts). This test drives the REAL
// notifier through a REAL FunctionsClient whose HTTP layer returns the exact
// body the function sends, and pins that a dead token is an expected failure
// (ticket 77, Finding 69-010: one note carrying `expected_failure:
// token_expired` and one `expected_failure` analytics event, no Degraded and
// no `error_reported`; only a reconnect fixes it), while an unexpected 500
// stays a Fault.

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mealvana_endurance/features/activities/application/activity_deduplication_service.dart';
import 'package:mealvana_endurance/features/activities/data/activities_repository.dart';
import 'package:mealvana_endurance/features/integrations/data/integrations_repository.dart';
import 'package:mealvana_endurance/features/integrations/domain/integration.dart';
import 'package:mealvana_endurance/features/integrations/presentation/providers/connect_training_controller.dart';
import 'package:mealvana_endurance/features/integrations/presentation/providers/integrations_providers.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/providers/user_id_provider.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/preferences_service.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';

import '../../helpers/fakes/recording_report.dart';
import '../../helpers/widget_test_harness.dart';

class _MockSession extends Mock implements Session {}

class _MockUser extends Mock implements User {}

const _authUid = '00000000-0000-0000-0000-00000000bbbb';

/// The body garmin-backfill's `errorResponse(...)` writes for a dead token:
/// `{success, error, details, code}`, details being the per-type Garmin
/// errors as a JSON string.
final _reauthBody = jsonEncode({
  'success': false,
  'error': 'Garmin connection expired; the athlete must reconnect Garmin',
  'details': jsonEncode({
    'body_composition': '{"errorMessage":"Token is not active"}\n',
    'user_metrics':
        '{"errorMessage":"Too many request: Limit 100 per 1 minute"}',
  }),
  'code': 'garmin_reauth_required',
});

void main() {
  late AppDatabase db;
  late RecordingReport report;
  late IntegrationsRepository repository;

  Future<ProviderContainer> containerAnswering(int status, String body) async {
    db = AppDatabase.memory();
    addTearDown(db.close);
    report = RecordingReport();

    // The automatic backfill ran moments ago (cooldown), so only the
    // explicit call below reaches garmin-backfill.
    SharedPreferences.setMockInitialValues({
      'garmin_backfill_last_at_$_authUid':
          DateTime.now().millisecondsSinceEpoch,
    });
    final prefs = await SharedPreferences.getInstance();

    final functions = FunctionsClient(
      'https://example.supabase.co/functions/v1',
      const {},
      httpClient: MockClient((request) async {
        expect(request.url.path, endsWith('/garmin-backfill'));
        return http.Response(
          body,
          status,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(functions.dispose);

    final session = _MockSession();
    when(() => session.accessToken).thenReturn('athlete-jwt');
    // A signed-in athlete, so the controller works on their real id.
    final authUser = _MockUser();
    when(() => authUser.id).thenReturn(_authUid);
    when(() => authUser.isAnonymous).thenReturn(false);
    final goTrue = fakeGoTrueClient();
    when(() => goTrue.currentSession).thenReturn(session);
    when(() => goTrue.currentUser).thenReturn(authUser);
    final supabase = fakeSupabaseClient(auth: goTrue);
    when(() => supabase.functions).thenReturn(functions);

    // The repository's own push has no server here; its report is apart
    // from the controller's, which is what this test reads.
    repository = IntegrationsRepository(
      database: db,
      supabase: supabase,
      report: RecordingReport(),
    );
    // A connected Garmin whose token Garmin has since refused.
    await repository.upsertIntegration(
      IntegrationModel(
        userId: _authUid,
        provider: 'garmin',
        accessToken: 'garmin-access',
        refreshToken: 'garmin-refresh',
        providerAthleteId: 'garmin-user-1',
        isActive: true,
        lastSyncStatus: 'success',
      ),
    );

    final container = ProviderContainer(
      overrides: [
        mockAppExternalDeps(supabaseClient: supabase),
        sharedPreferencesProvider.overrideWithValue(prefs),
        preferencesServiceProvider.overrideWith(
          (ref) => PreferencesService(prefs),
        ),
        inMemoryDatabaseOverride(db),
        reportProvider.overrideWithValue(report),
        integrationsRepositoryProvider.overrideWithValue(repository),
        activitiesRepositoryProvider.overrideWithValue(
          ActivitiesRepository(
            supabase: supabase,
            database: db,
            report: report,
            deduplicationService: ActivityDeduplicationService(),
          ),
        ),
        userIdProvider.overrideWith((ref) async => _authUid),
      ],
    );
    addTearDown(container.dispose);
    // Keep the auto-dispose controller alive across the awaits below.
    container.listen(connectTrainingControllerProvider, (_, _) {});
    await container.read(connectTrainingControllerProvider.future);
    return container;
  }

  test('a dead Garmin token (409 garmin_reauth_required) is an expected '
      'failure, not Degraded or a Fault', () async {
    final container = await containerAnswering(409, _reauthBody);
    final analytics = container.read(appExternalDepsProvider).analytics;
    clearInteractions(analytics);

    final queued = await container
        .read(connectTrainingControllerProvider.notifier)
        .triggerGarminBackfill();

    expect(queued, isFalse);
    expect(report.faults, isEmpty);
    expect(report.degradeds, isEmpty);
    final garminNotes = report.notes.where((n) => n.area == 'garmin').toList();
    expect(garminNotes, hasLength(1));
    expect(garminNotes.single.message, contains('reconnect Garmin'));
    expect(garminNotes.single.data, {'expected_failure': 'token_expired'});
    verify(
      () => analytics.track(
        expectedFailureEvent,
        properties: {'area': 'garmin', 'reason': 'token_expired'},
      ),
    ).called(1);
    verifyNever(
      () => analytics.track(
        errorReportedEvent,
        properties: any(named: 'properties'),
      ),
    );

    final row = await repository.getIntegration(_authUid, 'garmin');
    expect(row!.lastSyncStatus, requiresReauthStatus);
    expect(
      container.read(connectTrainingControllerProvider).value!
          .garminNeedsReauth,
      isTrue,
    );
  });

  test('an unexpected 500 from garmin-backfill stays a Fault', () async {
    final container = await containerAnswering(
      500,
      jsonEncode({'success': false, 'error': 'Internal server error'}),
    );

    await container
        .read(connectTrainingControllerProvider.notifier)
        .triggerGarminBackfill();

    expect(report.faults, hasLength(1));
    expect(report.faults.single.message, 'Garmin backfill invoke failed');
  });

  group('isGarminReauthRequired', () {
    test('reads the code from a decoded JSON body', () {
      expect(
        isGarminReauthRequired(409, jsonDecode(_reauthBody) as Map),
        isTrue,
      );
    });

    test('needs the 409 and the code together', () {
      expect(isGarminReauthRequired(502, jsonDecode(_reauthBody)), isFalse);
      expect(isGarminReauthRequired(409, {'code': 'other'}), isFalse);
      expect(isGarminReauthRequired(409, 'garmin_reauth_required'), isTrue);
    });
  });
}
