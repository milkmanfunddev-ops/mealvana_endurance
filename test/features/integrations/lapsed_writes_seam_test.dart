/// A lapsed account cannot connect a training provider or import its
/// workouts (mp-457 §4, mp-491, ticket 12).
///
/// Through the real ConnectTrainingController: connecting, backfilling and
/// importing ask the write guard first; refused, they open the paywall once
/// and never construct a repository or service, so no activity is written
/// or queued. Disconnecting is left open: revoking a third party's access to
/// the account is the account's to do, like sign-out (mp-280 §2).
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/data/activities_repository.dart';
import 'package:mealvana_endurance/features/integrations/presentation/providers/connect_training_controller.dart';
import 'package:mealvana_endurance/features/integrations/presentation/providers/integrations_providers.dart';

import '../../helpers/write_access.dart';

class _FakeState extends Fake implements ConnectTrainingState {}

class _Seeded extends ConnectTrainingController {
  @override
  FutureOr<ConnectTrainingState> build() => _FakeState();
}

void main() {
  late PaywallOpens opens;
  late ProviderContainer container;

  setUp(() {
    opens = PaywallOpens();
    container = ProviderContainer(
      overrides: [
        writesRefused(),
        opens.override,
        integrationsRepositoryProvider.overrideWith(
          untouched('integrationsRepository'),
        ),
        activitiesRepositoryProvider.overrideWith(
          untouched('activitiesRepository'),
        ),
        garminOAuthServiceProvider.overrideWith(
          untouched('garminOAuthService'),
        ),
        finalSurgeSyncServiceProvider.overrideWith(
          untouched('finalSurgeSyncService'),
        ),
        vdotSyncServiceProvider.overrideWith(untouched('vdotSyncService')),
        runnaSyncServiceProvider.overrideWith(untouched('runnaSyncService')),
        trainingPeaksSyncServiceProvider.overrideWith(
          untouched('trainingPeaksSyncService'),
        ),
        connectTrainingControllerProvider.overrideWith(_Seeded.new),
      ],
    );
    addTearDown(container.dispose);
  });

  ConnectTrainingController ctrl() =>
      container.read(connectTrainingControllerProvider.notifier);
  final paths = <String, Future<Object?> Function()>{
    'connectFinalSurge': () => ctrl().connectFinalSurge(),
    'connectGarmin': () => ctrl().connectGarmin(),
    'triggerGarminBackfill': () => ctrl().triggerGarminBackfill(),
    'connectVdot': () => ctrl().connectVdot(),
    'importVdotWorkouts': () => ctrl().importVdotWorkouts(),
    'connectRunna': () => ctrl().connectRunna('https://example.com/feed.ics'),
    'importRunnaWorkouts': () => ctrl().importRunnaWorkouts(),
    'importFinalSurgeWorkouts': () => ctrl().importFinalSurgeWorkouts(),
    'connectTrainingPeaks': () => ctrl().connectTrainingPeaks(),
    'importTrainingPeaksWorkouts': () => ctrl().importTrainingPeaksWorkouts(),
    'importWorkouts': () => ctrl().importWorkouts(),
  };
  for (final entry in paths.entries) {
    test('lapsed: ${entry.key} opens the paywall and writes nothing', () async {
      await container.read(connectTrainingControllerProvider.future);
      await expectWriteRefused(opens, entry.value);
    });
  }
}
