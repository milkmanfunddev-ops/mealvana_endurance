// Ticket 84 (Finding 69-012, device side of ticket 76): the app reports a
// provider's status and error code, never its error body.
//
// Seam: a provider's HTTP answer → what reaches Report (Sentry), the thrown
// exception's text, the on-screen error and analytics. The producer side is
// Garmin's real refusal shape, whose `error_description` carried a refresh
// token as base64 JSON, fed as an HTTP answer through the real client or
// service (`package:http/testing.dart`). Only the far ends are doubles: a
// recording Report, a recording analytics tracker, a mocked repository.
// Tests run with kDebugMode true, so they also prove the old debug-only
// `\nBody: ...` path is gone.
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mealvana_endurance/features/activities/application/activity_deduplication_service.dart';
import 'package:mealvana_endurance/features/activities/data/activities_repository.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/daily_macros/data/daily_macro_targets_repository.dart';
import 'package:mealvana_endurance/features/integrations/application/change_detection_service.dart';
import 'package:mealvana_endurance/features/integrations/application/garmin_oauth_service.dart';
import 'package:mealvana_endurance/features/integrations/application/training_peaks_oauth_service.dart';
import 'package:mealvana_endurance/features/integrations/application/training_peaks_sync_service.dart';
import 'package:mealvana_endurance/features/integrations/application/training_peaks_transformer.dart';
import 'package:mealvana_endurance/features/integrations/data/final_surge_api_client.dart';
import 'package:mealvana_endurance/features/integrations/data/http_retry_client.dart';
import 'package:mealvana_endurance/features/integrations/data/integrations_repository.dart';
import 'package:mealvana_endurance/features/integrations/data/training_peaks_api_client.dart';
import 'package:mealvana_endurance/features/integrations/data/vdot_api_client.dart';
import 'package:mealvana_endurance/features/integrations/domain/integration.dart';
import 'package:mealvana_endurance/features/integrations/domain/integration_exceptions.dart';
import 'package:mealvana_endurance/features/integrations/presentation/providers/connect_training_controller.dart';
import 'package:mealvana_endurance/features/integrations/presentation/providers/integrations_providers.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/providers/user_id_provider.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';

import '../../helpers/fakes/recording_analytics_tracker.dart';
import '../../helpers/fakes/recording_report.dart';
import '../../helpers/widget_test_harness.dart';

/// The refresh token hidden in the description, as Garmin sent it.
const _token = 'rt-live-5f2c';
final _tokenB64 = base64Encode(
  utf8.encode(jsonEncode({'refreshTokenValue': _token})),
);

/// Garmin's real refusal shape (Finding 69-012), the token inside.
String get _garminBody => jsonEncode({
  'error': 'invalid_grant',
  'error_description': 'Invalid refresh token: $_tokenB64',
});

/// Every fragment that must not reach a report or an exception's text.
List<String> get _forbidden => [
  _token,
  _tokenB64,
  for (var i = 0; i + 12 <= _tokenB64.length; i += 4)
    _tokenB64.substring(i, i + 12),
  'Invalid refresh token',
  'error_description',
];

void _expectRedacted(String text, {String reason = ''}) {
  for (final f in _forbidden) {
    expect(text, isNot(contains(f)), reason: '$reason leaked "$f": $text');
  }
}

/// Everything a recorded call would send to Sentry, flattened to text.
String _reportText(RecordedReport r) => [
  r.error?.toString(),
  r.message,
  r.extra?.toString(),
  r.tags?.toString(),
  r.data?.toString(),
].whereType<String>().join(' | ');

void _expectReportsRedacted(RecordingReport report) {
  expect(report.calls, isNotEmpty);
  for (final c in report.calls) {
    _expectRedacted(_reportText(c), reason: c.severity);
  }
}

http.Response _json(int status, String body) =>
    http.Response(body, status, headers: {'content-type': 'application/json'});

class _MockIntegrationsRepository extends Mock
    implements IntegrationsRepository {}

class _MockActivitiesRepository extends Mock implements ActivitiesRepository {}

class _MockChangeDetectionService extends Mock
    implements ChangeDetectionService {}

class _MockGarminOAuth extends Mock implements GarminOAuthService {}

class _MockUser extends Mock implements User {}

IntegrationModel _expiredTp() => IntegrationModel(
  id: 'i1',
  userId: 'u1',
  provider: 'training_peaks',
  accessToken: 'stale-access',
  refreshToken: 'stale-refresh',
  tokenExpiresAt: DateTime.now().subtract(const Duration(hours: 3)),
  providerAthleteId: 'ath-1',
  lastSyncStatus: 'success',
  updatedAt: DateTime.now(),
);

const _noRetry = RetryConfig(maxRetries: 0, initialDelayMs: 0, maxDelayMs: 0);

void main() {
  setUpAll(() => registerFallbackValue(_expiredTp()));

  group('TrainingPeaks refresh', () {
    late _MockIntegrationsRepository repo;
    late RecordingReport report;

    setUp(() {
      report = RecordingReport();
      repo = _MockIntegrationsRepository();
      when(
        () => repo.getIntegration('u1', 'training_peaks'),
      ).thenAnswer((_) async => _expiredTp());
      when(
        () => repo.updateSyncStatus(
          any(),
          any(),
          status: any(named: 'status'),
          error: any(named: 'error'),
        ),
      ).thenAnswer((_) async {});
      when(() => repo.upsertIntegration(any())).thenAnswer(
        (i) async => i.positionalArguments.first as IntegrationModel,
      );
    });

    TrainingPeaksApiClient tpRefusing() => TrainingPeaksApiClient(
      clientId: 'cid',
      clientSecret: 'secret',
      appVersion: 'test',
      retryConfig: _noRetry,
      report: report,
      httpClient: MockClient((r) async {
        if (r.url.path.endsWith('/oauth/token')) return _json(400, _garminBody);
        fail('unexpected request after a failed refresh: ${r.url}');
      }),
    );

    TrainingPeaksOAuthService oauth() => TrainingPeaksOAuthService(
      apiClient: tpRefusing(),
      repository: repo,
      clientId: 'cid',
      report: report,
    );

    void expectOneRedactedDegraded() {
      expect(report.faults, isEmpty);
      final d = report.degradeds.single;
      expect(d.extra, {'statusCode': 400, 'errorCode': 'invalid_grant'});
      expect(d.error.toString(), contains('400'));
      expect(d.error.toString(), contains('invalid_grant'));
      _expectReportsRedacted(report);
    }

    test(
      'refreshTokenIfNeeded: one degraded with status and code only',
      () async {
        expect(await oauth().refreshTokenIfNeeded('u1'), isNull);
        expectOneRedactedDegraded();
      },
    );

    test('forceRefreshToken: the same', () async {
      expect(await oauth().forceRefreshToken('u1'), isNull);
      expectOneRedactedDegraded();
    });

    test('sync service _refreshToken (via a sync): the same', () async {
      final result = await TrainingPeaksSyncService(
        apiClient: tpRefusing(),
        integrationsRepository: repo,
        activitiesRepository: _MockActivitiesRepository(),
        transformer: const TrainingPeaksTransformer(),
        changeDetectionService: _MockChangeDetectionService(),
        report: report,
      ).syncWorkouts('u1');

      expect(result.success, isFalse);
      expect(result.error ?? '', isNot(contains(_token)));
      expectOneRedactedDegraded();
    });
  });

  test('TrainingPeaks code exchange: the exception text has no body', () async {
    final api = TrainingPeaksApiClient(
      clientId: 'cid',
      clientSecret: 'secret',
      appVersion: 'test',
      httpClient: MockClient((_) async => _json(400, _garminBody)),
    );
    final e = await api
        .exchangeCodeForToken('code', 'app://cb')
        .then<Object?>((_) => null, onError: (Object e) => e);

    expect(e, isA<TrainingPeaksApiException>());
    expect(
      e.toString(),
      'TrainingPeaksApiException: Token exchange failed '
      '(status: 400, error: invalid_grant)',
    );
    _expectRedacted(e.toString());
    _expectRedacted((e! as IntegrationApiException).reportExtra.toString());
  });

  group('Final Surge code exchange', () {
    Future<Object?> exchange(http.Response answer) =>
        FinalSurgeApiClient(
              clientId: 'cid',
              clientSecret: 'x' * 64,
              httpClient: MockClient((_) async => answer),
            )
            .exchangeCodeForToken('code')
            .then<Object?>((_) => null, onError: (Object e) => e);

    test('a 400 with the body: status and code only', () async {
      final e = await exchange(_json(400, _garminBody));
      expect(e, isA<FinalSurgeApiException>());
      expect(e.toString(), contains('400'));
      expect(e.toString(), contains('invalid_grant'));
      _expectRedacted(e.toString());
      _expectRedacted((e! as IntegrationApiException).reportExtra.toString());
    });

    test('a 200 whose error is free text: no detail at all', () async {
      final e = await exchange(
        _json(200, jsonEncode({'error': 'Invalid refresh token: $_token'})),
      );
      expect(e, isA<FinalSurgeApiException>());
      expect((e! as FinalSurgeApiException).message, 'Token exchange failed');
      _expectRedacted(e.toString());
    });
  });

  group('Garmin code exchange', () {
    test('tokenExchangeFailure: status and code only', () {
      final e = GarminOAuthService.tokenExchangeFailure(
        http.Response(_garminBody, 400),
      );
      expect(e.message, 'Token exchange failed: 400 invalid_grant');
      _expectRedacted(e.toString());
    });

    test('through the connect path: the fault, the error line and analytics '
        'hold no token', () async {
      final db = AppDatabase.memory();
      addTearDown(db.close);
      final authUser = _MockUser();
      when(
        () => authUser.id,
      ).thenReturn('00000000-0000-0000-0000-00000000bbbb');
      when(() => authUser.isAnonymous).thenReturn(false);
      final goTrue = fakeGoTrueClient();
      when(() => goTrue.currentUser).thenReturn(authUser);
      final supabase = fakeSupabaseClient(auth: goTrue);
      final report = RecordingReport();
      final analytics = RecordingAnalyticsTracker();
      final garmin = _MockGarminOAuth();
      when(
        () => garmin.authenticate(
          any(),
          skipRemoteMapping: any(named: 'skipRemoteMapping'),
        ),
      ).thenThrow(
        GarminOAuthService.tokenExchangeFailure(
          http.Response(_garminBody, 400),
        ),
      );

      final container = ProviderContainer(
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
          dailyMacroTargetsRepositoryProvider.overrideWithValue(
            DailyMacroTargetsRepository(
              database: db,
              supabase: supabase,
              report: RecordingReport(),
            ),
          ),
          userIdProvider.overrideWith(
            (ref) async => '00000000-0000-0000-0000-00000000bbbb',
          ),
          garminOAuthServiceProvider.overrideWithValue(garmin),
        ],
      );
      addTearDown(container.dispose);
      container.listen(connectTrainingControllerProvider, (_, _) {});
      await db.userDao.saveUserProfile(
        UserProfile(
          id: 'local-profile-id',
          deviceId: 'device-seam-084',
          authUserId: '00000000-0000-0000-0000-00000000bbbb',
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
        ),
      );
      await container.read(connectTrainingControllerProvider.future);

      expect(
        await container
            .read(connectTrainingControllerProvider.notifier)
            .connectGarmin(),
        isFalse,
      );

      final fault = report.faults.single;
      expect(fault.error.toString(), contains('400 invalid_grant'));
      _expectReportsRedacted(report);
      final state = container
          .read(connectTrainingControllerProvider)
          .requireValue;
      _expectRedacted(state.errorMessage ?? '', reason: 'errorMessage');
      final failed = analytics.findEvents('integration_connect_failed');
      expect(failed, hasLength(1));
      _expectRedacted(failed.single.properties.toString(), reason: 'analytics');
    });
  });

  group('V.O2 code exchange', () {
    Future<Object?> exchange(Map<String, dynamic> body) =>
        VdotApiClient(
              clientId: 'cid',
              clientSecret: 'secret',
              authBaseUrl: 'https://auth.example',
              apiBaseUrl: 'https://api.example',
              httpClient: MockClient((_) async => _json(400, jsonEncode(body))),
            )
            .exchangeCodeForToken('code', redirectUri: 'app://cb')
            .then<Object?>((_) => null, onError: (Object e) => e);

    test('invalid_code: the code only, never the description', () async {
      final e = await exchange({
        'status': 'NOK',
        'error': 'invalid_code',
        'error_description': 'code $_token is invalid',
      });
      expect(e, isA<VdotApiException>());
      expect(
        (e! as VdotApiException).message,
        'Token exchange failed: invalid_code',
      );
      _expectRedacted(e.toString());
      _expectRedacted((e as IntegrationApiException).reportExtra.toString());
    });

    test('invalid_payload still gets its hint', () async {
      final e = await exchange({
        'status': 'NOK',
        'error': 'invalid_payload',
        'error_description': 'code $_token is invalid',
      });
      final msg = (e! as VdotApiException).message;
      expect(msg, startsWith('Token exchange failed: invalid_payload ('));
      expect(msg, contains('client_secret'));
      _expectRedacted(e.toString());
    });

    test('Garmin-shaped body: the code, no description', () async {
      final e = await exchange(jsonDecode(_garminBody) as Map<String, dynamic>);
      expect(
        (e! as VdotApiException).message,
        'Token exchange failed: invalid_grant',
      );
      _expectRedacted(e.toString());
    });
  });

  group('HttpRetryClient.mapStatusToException', () {
    for (final status in [403, 500, 418]) {
      test('$status: toString and reportExtra hold status and code only', () {
        final e = HttpRetryClient.mapStatusToException(
          _json(status, _garminBody),
          provider: 'final_surge',
        )!;
        expect(e.reportExtra, {
          'statusCode': status,
          'errorCode': 'invalid_grant',
        });
        _expectRedacted(e.toString());
        _expectRedacted(e.reportExtra.toString());
        expect(e.toString(), contains('invalid_grant'));
      });
    }
  });
}
