// Ticket 64 (Finding 21-004): a TrainingPeaks token refresh that TP refuses
// for good marks the connection as needing reconnection, so the athlete can
// see it where connections are shown.
//
// Seam: TrainingPeaks' OAuth token endpoint → the stored integration row.
// The producer side is a real HTTP answer (status + OAuth error body, as TP
// sends it) fed through the real [TrainingPeaksApiClient]; only the
// repository at the far end is a double, and the assertion is on what gets
// written to it.
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mealvana_endurance/features/activities/data/activities_repository.dart';
import 'package:mealvana_endurance/features/integrations/application/change_detection_service.dart';
import 'package:mealvana_endurance/features/integrations/application/training_peaks_oauth_service.dart';
import 'package:mealvana_endurance/features/integrations/application/training_peaks_sync_service.dart';
import 'package:mealvana_endurance/features/integrations/application/training_peaks_transformer.dart';
import 'package:mealvana_endurance/features/integrations/data/integrations_repository.dart';
import 'package:mealvana_endurance/features/integrations/data/training_peaks_api_client.dart';
import 'package:mealvana_endurance/features/integrations/domain/integration.dart';
import 'package:mocktail/mocktail.dart';

class _MockIntegrationsRepository extends Mock
    implements IntegrationsRepository {}

class _MockActivitiesRepository extends Mock implements ActivitiesRepository {}

class _MockChangeDetectionService extends Mock
    implements ChangeDetectionService {}

/// A TP row whose access token has already expired, so any sync or write
/// path must refresh first.
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

/// TP's token endpoint answering [status] with [body]; any other request is
/// a test failure (nothing past the refresh may run).
TrainingPeaksApiClient _tpAnswering(int status, Map<String, dynamic> body) {
  final client = MockClient((request) async {
    if (request.url.path.endsWith('/oauth/token')) {
      return _response(status, body);
    }
    fail('unexpected request after a failed refresh: ${request.url}');
  });
  return TrainingPeaksApiClient(
    clientId: 'cid',
    clientSecret: 'secret',
    appVersion: 'test',
    httpClient: client,
  );
}

http.Response _response(int status, Map<String, dynamic> body) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json'},
);

const _invalidGrant = {
  'error': 'invalid_grant',
  'error_description': 'The refresh token is invalid or expired.',
};

void main() {
  late _MockIntegrationsRepository repo;

  setUp(() {
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
  });

  TrainingPeaksSyncService syncService(TrainingPeaksApiClient api) =>
      TrainingPeaksSyncService(
        apiClient: api,
        integrationsRepository: repo,
        activitiesRepository: _MockActivitiesRepository(),
        transformer: const TrainingPeaksTransformer(),
        changeDetectionService: _MockChangeDetectionService(),
      );

  List<String> writtenStatuses() => verify(
    () => repo.updateSyncStatus(
      'u1',
      'training_peaks',
      status: captureAny(named: 'status'),
      error: any(named: 'error'),
    ),
  ).captured.cast<String>();

  group('sync: a refresh TP refuses for good', () {
    for (final status in [400, 401]) {
      test('$status marks the connection as needing reconnection', () async {
        final result = await syncService(
          _tpAnswering(status, _invalidGrant),
        ).syncWorkouts('u1');

        expect(result.success, isFalse);
        expect(result.tokenExpired, isTrue);
        expect(writtenStatuses(), [requiresReauthStatus]);
      });
    }

    test('the event sync marks it too', () async {
      final result = await syncService(
        _tpAnswering(400, _invalidGrant),
      ).syncEvents('u1');

      expect(result.success, isFalse);
      expect(writtenStatuses(), [requiresReauthStatus]);
    });
  });

  test('sync: a TP outage during refresh is not a reconnect', () async {
    final result = await syncService(
      _tpAnswering(503, const {'message': 'Service Unavailable'}),
    ).syncWorkouts('u1');

    expect(result.success, isFalse);
    expect(result.tokenExpired, isFalse);
    verifyNever(
      () => repo.updateSyncStatus(
        any(),
        any(),
        status: requiresReauthStatus,
        error: any(named: 'error'),
      ),
    );
  });

  group('write-back token path (OAuth service)', () {
    TrainingPeaksOAuthService oauth(TrainingPeaksApiClient api) =>
        TrainingPeaksOAuthService(
          apiClient: api,
          repository: repo,
          clientId: 'cid',
        );

    test(
      'a 400 on refresh marks the connection as needing reconnection',
      () async {
        final token = await oauth(
          _tpAnswering(400, _invalidGrant),
        ).getValidAccessToken('u1');

        expect(token, isNull);
        expect(writtenStatuses(), [requiresReauthStatus]);
      },
    );

    test('a 400 on a forced refresh marks it too', () async {
      final token = await oauth(
        _tpAnswering(400, _invalidGrant),
      ).forceRefreshToken('u1');

      expect(token, isNull);
      expect(writtenStatuses(), [requiresReauthStatus]);
    });

    test('a 503 on refresh is recorded as an error, not a reconnect', () async {
      await oauth(
        _tpAnswering(503, const {'message': 'Service Unavailable'}),
      ).getValidAccessToken('u1');

      expect(writtenStatuses(), ['error']);
    });
  });

  group('IntegrationModel.needsReconnect', () {
    test('reads the stored requires_reauth status', () {
      expect(
        _expiredTp().copyWith(lastSyncStatus: 'requires_reauth').needsReconnect,
        isTrue,
      );
      expect(_expiredTp().needsReconnect, isFalse);
      expect(
        _expiredTp().copyWith(lastSyncStatus: 'error').needsReconnect,
        isFalse,
      );
    });
  });
}
