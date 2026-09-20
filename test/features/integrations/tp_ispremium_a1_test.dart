/// DI-23 — IsPremium ruling A1 (Xuan, 2026-09-20): NO behavior keys on the
/// provider_is_premium flag. These are the behavioral tests replacing the
/// three superseded gate paths:
///
///  * metrics fetch is UNGATED — attempted even when the flag says false
///    (the old gate meant the fetch had never run for any athlete);
///  * refreshPremiumEligibility is informational-only — it never writes
///    block state, whatever the profile reports;
///  * write-back eligibility keys on TP's ACTUAL responses alone: a 403 on
///    a push blocks WITHOUT consulting the profile; a successful push
///    clears the block.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/integrations/application/change_detection_service.dart';
import 'package:mealvana_endurance/features/integrations/application/tp_writeback_service.dart';
import 'package:mealvana_endurance/features/integrations/application/training_peaks_oauth_service.dart';
import 'package:mealvana_endurance/features/integrations/application/training_peaks_sync_service.dart';
import 'package:mealvana_endurance/features/integrations/application/training_peaks_transformer.dart';
import 'package:mealvana_endurance/features/activities/data/activities_repository.dart';
import 'package:mealvana_endurance/features/integrations/data/integrations_repository.dart';
import 'package:mealvana_endurance/features/integrations/data/training_peaks_api_client.dart';
import 'package:mealvana_endurance/features/integrations/domain/integration.dart';
import 'package:mealvana_endurance/features/integrations/domain/integration_exceptions.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/services/preferences_service.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockTpApiClient extends Mock implements TrainingPeaksApiClient {}

class MockTpOAuthService extends Mock implements TrainingPeaksOAuthService {}

class MockIntegrationsRepository extends Mock
    implements IntegrationsRepository {}

class MockActivitiesRepository extends Mock implements ActivitiesRepository {}

class MockChangeDetectionService extends Mock
    implements ChangeDetectionService {}

class FakeAthleteProfile extends Fake implements TrainingPeaksAthleteProfile {
  FakeAthleteProfile(this.isPremium);
  @override
  final bool isPremium;
}

IntegrationModel _integration({bool? isPremium}) => IntegrationModel(
  id: 'i1',
  userId: 'u1',
  provider: 'training_peaks',
  accessToken: 'tok',
  tokenExpiresAt: DateTime.now().add(const Duration(hours: 2)),
  providerAthleteId: 'ath-1',
  providerIsPremium: isPremium,
  updatedAt: DateTime.now(),
);

Future<PreferencesService> _prefs(Map<String, Object> initial) async {
  SharedPreferences.setMockInitialValues(initial);
  return PreferencesService(await SharedPreferences.getInstance());
}

void main() {
  group('A1: metrics fetch is attempt-and-observe, never flag-gated', () {
    test('getAthleteMetrics is called although providerIsPremium is false',
        () async {
      final api = MockTpApiClient();
      final integrationsRepo = MockIntegrationsRepository();
      final activitiesRepo = MockActivitiesRepository();

      when(() => integrationsRepo.getIntegration('u1', 'training_peaks'))
          .thenAnswer((_) async => _integration(isPremium: false));
      when(() => api.getAthleteZones(any()))
          .thenThrow(StateError('zones offline — non-blocking'));
      when(() => api.getAthleteMetrics(any(),
              startDate: any(named: 'startDate'),
              endDate: any(named: 'endDate')))
          .thenAnswer((_) async => const []);
      when(() => integrationsRepo.updateAthleteMetrics(any(), any(),
              metricsJson: any(named: 'metricsJson'),
              weightKg: any(named: 'weightKg')))
          .thenAnswer((_) async {});
      when(() => api.getUpcomingWorkouts(any(),
              days: any(named: 'days'),
              includeDescription: any(named: 'includeDescription')))
          .thenAnswer((_) async => const []);
      when(() => activitiesRepo.getActivitiesByUserAndProvider(any(), any()))
          .thenAnswer((_) async => const []);
      when(() => integrationsRepo.updateSyncStatus(any(), any(),
              status: any(named: 'status'), error: any(named: 'error')))
          .thenAnswer((_) async {});

      final service = TrainingPeaksSyncService(
        apiClient: api,
        integrationsRepository: integrationsRepo,
        activitiesRepository: activitiesRepo,
        transformer: const TrainingPeaksTransformer(),
        changeDetectionService: MockChangeDetectionService(),
      );

      await service.syncWorkouts('u1');

      // The superseded gate returned before this call for every athlete.
      verify(() => api.getAthleteMetrics(any(),
          startDate: any(named: 'startDate'),
          endDate: any(named: 'endDate'))).called(1);
    });
  });

  group('A1: refreshPremiumEligibility is informational-only', () {
    for (final profileSays in [true, false]) {
      test('profile=$profileSays never writes block state', () async {
        final api = MockTpApiClient();
        final oauth = MockTpOAuthService();
        when(() => oauth.getValidAccessToken(any()))
            .thenAnswer((_) async => 'tok');
        when(() => api.getAthleteProfile(any()))
            .thenAnswer((_) async => FakeAthleteProfile(profileSays));
        // Start from the OPPOSITE block state the old code would write.
        final prefs =
            await _prefs({'tp_writeback_premium_blocked': profileSays});
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final service = TpWritebackService(
          apiClient: api,
          oauthService: oauth,
          preferencesService: prefs,
          database: db,
          supabase: null,
        );

        final reported =
            await service.refreshPremiumEligibility(userId: 'u1');

        expect(reported, profileSays);
        // The block state is EXACTLY what it was — the flag decides nothing.
        expect(prefs.tpWritebackPremiumBlocked, profileSays);
      });
    }
  });

  group('A1: the write-back RESPONSE is the evidence', () {
    test('a 403 blocks without consulting the profile', () async {
      final api = MockTpApiClient();
      final oauth = MockTpOAuthService();
      final prefs = await _prefs({});
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final service = TpWritebackService(
        apiClient: api,
        oauthService: oauth,
        preferencesService: prefs,
        database: db,
        supabase: null,
      );

      await service.handleApiException(
        IntegrationApiException('forbidden', statusCode: 403),
        'u1',
        'w1',
      );

      expect(prefs.tpWritebackPremiumBlocked, isTrue);
      verifyNever(() => api.getAthleteProfile(any()));
      verifyNever(() => oauth.getValidAccessToken(any()));
    });

    test('a successful push clears the block', () async {
      final prefs = await _prefs({'tp_writeback_premium_blocked': true});
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final service = TpWritebackService(
        apiClient: MockTpApiClient(),
        oauthService: MockTpOAuthService(),
        preferencesService: prefs,
        database: db,
        supabase: null,
      );

      await service.onPushSucceeded();

      expect(prefs.tpWritebackPremiumBlocked, isFalse);
    });
  });
}
