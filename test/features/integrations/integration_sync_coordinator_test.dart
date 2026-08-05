import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mealvana_endurance/features/activities/data/activities_repository.dart';
import 'package:mealvana_endurance/features/integrations/application/integration_sync_coordinator.dart';
import 'package:mealvana_endurance/features/integrations/application/runna_sync_service.dart';
import 'package:mealvana_endurance/features/integrations/data/integrations_repository.dart';
import 'package:mealvana_endurance/features/integrations/domain/integration.dart';
import 'package:mealvana_endurance/features/integrations/presentation/providers/connect_training_controller.dart';
import 'package:mealvana_endurance/features/integrations/presentation/providers/integrations_providers.dart';
import 'package:mealvana_endurance/shared/data/syncable_repository.dart';
import 'package:mealvana_endurance/shared/services/logging_service.dart';
import 'package:mealvana_endurance/shared/services/sync/sync_coordinator.dart';

/// Regression coverage for the staleness/cooldown bookkeeping in
/// [IntegrationSyncCoordinator].
///
/// The bug this guards: every provider sync service catches its own errors and
/// reports them in a result object instead of throwing, so the coordinator's
/// `catch` block never fires on an ordinary sync failure. The coordinator used
/// to fall straight through to "stamp last-sync = now", which meant one failed
/// fetch locked the provider out of retries for the whole 4h staleness window
/// and never armed the 5m failure cooldown. Observed on the simulator as:
///
///   ❌ [runna] Sync failed (network): Could not reach the Runna calendar
///   ✅ Integration sync complete for runna
///   🔄 Integration sync skipped (runna) - data is fresh
const _userId = 'user-1';

class _MockIntegrationsRepository extends Mock
    implements IntegrationsRepository {}

class _MockActivitiesRepository extends Mock implements ActivitiesRepository {}

class _MockRunnaSyncService extends Mock implements RunnaSyncService {}

class _FakeSyncCoordinator extends SyncCoordinator {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeConnectTrainingController extends ConnectTrainingController {
  // The real build() reaches for the Drift database; the coordinator only ever
  // asks this controller whether a manual sync is already running.
  @override
  FutureOr<ConnectTrainingState> build() => const ConnectTrainingState();

  @override
  bool isSyncingProvider(String provider) => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _SilentLogger implements AppLogger {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

IntegrationModel _runnaIntegration() => const IntegrationModel(
  id: 'int-1',
  userId: _userId,
  provider: 'runna',
  accessToken: 'https://example.test/runna.ics',
  providerAthleteId: 'abcd1234',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockIntegrationsRepository integrationsRepo;
  late _MockActivitiesRepository activitiesRepo;
  late _MockRunnaSyncService runnaSync;
  late ProviderContainer container;

  setUp(() {
    SharedPreferences.setMockInitialValues({});

    integrationsRepo = _MockIntegrationsRepository();
    activitiesRepo = _MockActivitiesRepository();
    runnaSync = _MockRunnaSyncService();

    when(
      () => integrationsRepo.getActiveIntegrationsForUser(any()),
    ).thenAnswer((_) async => [_runnaIntegration()]);
    when(
      () => activitiesRepo.uploadDirtyRecords(any()),
    ).thenAnswer((_) async => const UploadResult(success: true, count: 0));

    container = ProviderContainer(
      overrides: [
        integrationsRepositoryProvider.overrideWithValue(integrationsRepo),
        activitiesRepositoryProvider.overrideWithValue(activitiesRepo),
        runnaSyncServiceProvider.overrideWithValue(runnaSync),
        appLoggerProvider.overrideWithValue(_SilentLogger()),
        syncCoordinatorProvider.overrideWith(() => _FakeSyncCoordinator()),
        connectTrainingControllerProvider.overrideWith(
          () => _FakeConnectTrainingController(),
        ),
      ],
    );
    addTearDown(container.dispose);
  });

  IntegrationSyncCoordinator coordinator() =>
      container.read(integrationSyncCoordinatorProvider.notifier);

  Future<int?> storedLastSyncMillis() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('integration_runna_last_sync');
  }

  group('failed sync does not count as fresh data', () {
    test('a network failure leaves the staleness clock unstamped', () async {
      when(
        () => runnaSync.syncWorkouts(any()),
      ).thenAnswer((_) async => RunnaSyncResult.networkError('Connection refused'));

      await coordinator().ensureIntegrationsSynced(_userId);

      expect(
        await storedLastSyncMillis(),
        isNull,
        reason: 'a failed sync must not record a successful sync time',
      );
    });

    test('an API failure leaves the staleness clock unstamped', () async {
      when(
        () => runnaSync.syncWorkouts(any()),
      ).thenAnswer((_) async => RunnaSyncResult.error('Bad feed'));

      await coordinator().ensureIntegrationsSynced(_userId);

      expect(await storedLastSyncMillis(), isNull);
    });

    test('a successful sync does stamp the staleness clock', () async {
      when(
        () => runnaSync.syncWorkouts(any()),
      ).thenAnswer((_) async => const RunnaSyncResult(success: true));

      await coordinator().ensureIntegrationsSynced(_userId);

      expect(await storedLastSyncMillis(), isNotNull);
    });
  });

  group('failure cooldown', () {
    test('a failure arms the 5-minute cooldown, suppressing the next attempt', () async {
      when(
        () => runnaSync.syncWorkouts(any()),
      ).thenAnswer((_) async => RunnaSyncResult.networkError('Connection refused'));

      final sut = coordinator();
      await sut.ensureIntegrationsSynced(_userId);
      await sut.ensureIntegrationsSynced(_userId);

      // Second pass is inside the cooldown, so the service is hit exactly once.
      verify(() => runnaSync.syncWorkouts(_userId)).called(1);
    });

    test(
      'forceSyncIntegrations bypasses the cooldown so manual retry still works',
      () async {
        when(
          () => runnaSync.syncWorkouts(any()),
        ).thenAnswer((_) async => RunnaSyncResult.networkError('Connection refused'));

        final sut = coordinator();
        await sut.ensureIntegrationsSynced(_userId);
        await sut.forceSyncIntegrations(_userId);

        verify(() => runnaSync.syncWorkouts(_userId)).called(2);
      },
    );

    test('a later success clears the failure cooldown', () async {
      when(
        () => runnaSync.syncWorkouts(any()),
      ).thenAnswer((_) async => const RunnaSyncResult(success: true));

      final sut = coordinator();
      await sut.forceSyncIntegrations(_userId);

      // Staleness now suppresses ensureIntegrationsSynced, but for the right
      // reason — and markProviderSynced/forceSync remain available.
      await sut.forceSyncIntegrations(_userId);
      verify(() => runnaSync.syncWorkouts(_userId)).called(2);
    });
  });

  group('post-sync upload', () {
    test('dirty activities are not uploaded when the sync failed', () async {
      when(
        () => runnaSync.syncWorkouts(any()),
      ).thenAnswer((_) async => RunnaSyncResult.networkError('Connection refused'));

      await coordinator().ensureIntegrationsSynced(_userId);

      verifyNever(() => activitiesRepo.uploadDirtyRecords(any()));
    });

    test('dirty activities are uploaded after a successful sync', () async {
      when(
        () => runnaSync.syncWorkouts(any()),
      ).thenAnswer((_) async => const RunnaSyncResult(success: true));

      await coordinator().ensureIntegrationsSynced(_userId);

      verify(() => activitiesRepo.uploadDirtyRecords(_userId)).called(1);
    });
  });
}
