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
import 'dart:io';

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
import 'package:mealvana_endurance/features/integrations/domain/http_retry_client.dart';
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

/// TP answering every request through [handler], with retries that do not
/// wait, so a 5xx or 429 answer runs its retries instantly.
TrainingPeaksApiClient _tp(
  Future<http.Response> Function(http.Request request) handler,
) => TrainingPeaksApiClient(
  clientId: 'cid',
  clientSecret: 'secret',
  appVersion: 'test',
  httpClient: MockClient(handler),
  retryConfig: const RetryConfig(
    maxRetries: 2,
    initialDelayMs: 0,
    maxDelayMs: 0,
  ),
);

bool _isRefresh(http.Request r) => r.url.path.endsWith('/oauth/token');

/// A TP row whose access token is still good by the clock.
IntegrationModel _currentTp() => _expiredTp().copyWith(
  tokenExpiresAt: DateTime.now().add(const Duration(hours: 1)),
);

const _freshToken = {
  'access_token': 'fresh-access',
  'refresh_token': 'fresh-refresh',
  'token_type': 'bearer',
  'expires_in': 3600,
};

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
  setUpAll(() => registerFallbackValue(_expiredTp()));

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
    when(
      () => repo.upsertIntegration(any()),
    ).thenAnswer((i) async => i.positionalArguments.first as IntegrationModel);
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

  // Ticket 76 (Finding 64-001): the other ways TP refuses the connection.
  group('sync: a data call TP answers 401', () {
    test('right after a refresh marks the connection as needing '
        'reconnection', () async {
      final result = await syncService(
        _tp((r) async {
          if (_isRefresh(r)) return _response(200, _freshToken);
          return _response(401, const {'message': 'Authorization denied'});
        }),
      ).syncWorkouts('u1');

      expect(result.success, isFalse);
      expect(result.tokenExpired, isTrue);
      expect(writtenStatuses(), [requiresReauthStatus]);
    });

    test('on a token good by the clock refreshes once, and a second 401 '
        'marks it', () async {
      when(
        () => repo.getIntegration('u1', 'training_peaks'),
      ).thenAnswer((_) async => _currentTp());
      var refreshes = 0;
      final result = await syncService(
        _tp((r) async {
          if (_isRefresh(r)) {
            refreshes++;
            return _response(200, _freshToken);
          }
          return _response(401, const {'message': 'Authorization denied'});
        }),
      ).syncWorkouts('u1');

      expect(refreshes, 1);
      expect(result.tokenExpired, isTrue);
      expect(writtenStatuses(), [requiresReauthStatus]);
    });

    test('on a token good by the clock, a refresh that fixes it ends in '
        'success', () async {
      when(
        () => repo.getIntegration('u1', 'training_peaks'),
      ).thenAnswer((_) async => _currentTp());
      final activities = _MockActivitiesRepository();
      when(
        () => activities.cleanupDuplicateProviderActivities(
          userId: any(named: 'userId'),
          provider: any(named: 'provider'),
        ),
      ).thenAnswer((_) async => 0);
      when(
        () => activities.getActivitiesByUserAndProvider(any(), any()),
      ).thenAnswer((_) async => []);
      final tokensSeen = <String?>[];
      final result = await TrainingPeaksSyncService(
        apiClient: _tp((r) async {
          if (_isRefresh(r)) return _response(200, _freshToken);
          if (!r.url.path.startsWith('/v2/workouts/')) {
            return _response(404, const {});
          }
          final auth = r.headers['Authorization'];
          tokensSeen.add(auth);
          return auth == 'Bearer fresh-access'
              ? http.Response('[]', 200)
              : _response(401, const {'message': 'Authorization denied'});
        }),
        integrationsRepository: repo,
        activitiesRepository: activities,
        transformer: const TrainingPeaksTransformer(),
        changeDetectionService: ChangeDetectionService(),
      ).syncWorkouts('u1');

      expect(tokensSeen, ['Bearer stale-access', 'Bearer fresh-access']);
      expect(result.success, isTrue);
      expect(writtenStatuses(), ['success']);
    });

    test('in the date-range sync marks it too', () async {
      final now = DateTime.now();
      final result =
          await syncService(
            _tp((r) async {
              if (_isRefresh(r)) return _response(200, _freshToken);
              return _response(401, const {'message': 'Authorization denied'});
            }),
          ).syncWorkoutsByDateRange(
            'u1',
            startDate: now,
            endDate: now.add(const Duration(days: 7)),
          );

      expect(result.tokenExpired, isTrue);
      expect(writtenStatuses(), [requiresReauthStatus]);
    });

    test('in the event sync marks it too', () async {
      final result = await syncService(
        _tp((r) async {
          if (_isRefresh(r)) return _response(200, _freshToken);
          return _response(401, const {'message': 'Authorization denied'});
        }),
      ).syncEvents('u1', days: 3);

      expect(result.success, isFalse);
      expect(writtenStatuses(), [requiresReauthStatus]);
    });

    test('in the next-event sync marks it too', () async {
      final result = await syncService(
        _tp((r) async {
          if (_isRefresh(r)) return _response(200, _freshToken);
          return _response(401, const {'message': 'Authorization denied'});
        }),
      ).syncNextEvent('u1');

      expect(result.success, isFalse);
      expect(writtenStatuses(), [requiresReauthStatus]);
    });

    for (final status in [503, 429]) {
      test('$status after a refresh stays an ordinary error', () async {
        final result = await syncService(
          _tp((r) async {
            if (_isRefresh(r)) return _response(200, _freshToken);
            return _response(status, const {'message': 'Try later'});
          }),
        ).syncWorkouts('u1');

        expect(result.success, isFalse);
        expect(result.tokenExpired, isFalse);
        expect(writtenStatuses(), ['error']);
      });
    }
  });

  group('a network error during the refresh', () {
    TrainingPeaksApiClient offline() => _tp((r) async {
      if (_isRefresh(r)) throw const SocketException('Network is unreachable');
      fail('unexpected request after a failed refresh: ${r.url}');
    });

    test('is an ordinary error the workout sync returns', () async {
      final result = await syncService(offline()).syncWorkouts('u1');

      expect(result.success, isFalse);
      expect(result.tokenExpired, isFalse);
      expect(writtenStatuses(), ['error']);
    });

    test('is an ordinary error the event sync returns', () async {
      final result = await syncService(offline()).syncEvents('u1');

      expect(result.success, isFalse);
      expect(writtenStatuses(), ['error']);
    });

    test('is an ordinary error on the write-back token path', () async {
      final token = await TrainingPeaksOAuthService(
        apiClient: offline(),
        repository: repo,
        clientId: 'cid',
      ).getValidAccessToken('u1');

      expect(token, isNull);
      expect(writtenStatuses(), ['error']);
    });
  });
}
