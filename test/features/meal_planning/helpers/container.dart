/// ProviderContainer wiring shared by the meal-planning controller tests.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/data/syncable_repository.dart';
import 'package:mealvana_endurance/shared/providers/user_id_provider.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/connectivity_checker.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';
import 'package:mealvana_endurance/shared/services/sync/sync_coordinator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fakes.dart';

class _FakeAnalytics extends Fake implements AnalyticsTracker {}

class _FakePrefs extends Fake implements SharedPreferences {}

/// A [SyncCoordinator] whose sync entry points are no-ops — controller tests
/// exercise the repositories directly, not the coordinator.
class NoopSyncCoordinator extends SyncCoordinator {
  final List<String> ensured = [];

  @override
  Future<void> ensureSynced(
    String repoKey,
    String userId, {
    SyncableRepository? repository,
  }) async {
    ensured.add(repoKey);
  }

  @override
  Future<void> forceSyncRepository(
    String repoKey,
    String userId, {
    required SyncableRepository repository,
  }) async {
    ensured.add('force:$repoKey');
  }
}

AppExternalDeps testDeps({Report? report}) => AppExternalDeps(
  analytics: _FakeAnalytics(),
  supabaseClient: supabaseWithSession(),
  sharedPreferences: _FakePrefs(),
  report: report ?? RecordingReport(),
);

/// Base overrides every controller test wants: a signed-in user, fake
/// external deps, a no-op sync coordinator and a stubbed connectivity.
List<Override> baseOverrides({
  String userId = 'user-1',
  RecordingReport? report,
  StubConnectivity? connectivity,
  NoopSyncCoordinator? sync,
}) {
  final r = report ?? RecordingReport();
  return [
    userIdProvider.overrideWith((ref) async => userId),
    reportProvider.overrideWithValue(r),
    appExternalDepsProvider.overrideWithValue(testDeps(report: r)),
    connectivityCheckerProvider.overrideWithValue(
      connectivity ?? StubConnectivity(),
    ),
    syncCoordinatorProvider.overrideWith(() => sync ?? NoopSyncCoordinator()),
  ];
}

ProviderContainer testContainer(List<Override> overrides) {
  final container = ProviderContainer(overrides: overrides);
  addTearDown(container.dispose);
  return container;
}

/// Let pending microtasks / short timers run.
Future<void> settle([Duration d = const Duration(milliseconds: 30)]) =>
    Future<void>.delayed(d);
