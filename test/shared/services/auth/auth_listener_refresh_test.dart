/// The auth listener keeps the startup snapshot live (round develop-2026-10,
/// ticket 56): a `signedIn` event refreshes it once, an ordinary sign-out
/// refreshes it once, and an onboarding sign-out (which preserves cached
/// onboarding data) does not touch it. Drives the real
/// `AuthListenerService` over a fake `onAuthStateChange` stream.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mealvana_endurance/features/app_startup/application/app_startup_provider.dart';
import 'package:mealvana_endurance/shared/database/app_database.dart';
import 'package:mealvana_endurance/shared/database/database_provider.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/auth/auth_listener_service.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';
import 'package:mealvana_endurance/shared/services/supabase/supabase_client_provider.dart';
import 'package:mealvana_endurance/shared/services/sync/sync_coordinator.dart';

import '../../../helpers/fakes/fake_supabase_client.dart';
import '../../../helpers/fakes/recording_report.dart';

class _MockAnalytics extends Mock implements AnalyticsTracker {}

class _MockPrefs extends Mock implements SharedPreferences {}

class _FakeUser extends Fake implements User {
  _FakeUser(this.id);
  @override
  final String id;
}

class _FakeSession extends Fake implements Session {
  _FakeSession(this.user);
  @override
  final User user;
}

/// Startup already resolved; records each refresh instead of reading.
class _RecordingStartup extends AppStartup {
  _RecordingStartup(this.reasons);
  final List<String> reasons;

  @override
  Future<AppStartupData> build() async =>
      const AppStartupData(user: null, hasCompletedOnboarding: false);

  @override
  Future<void> refreshSession({required String reason}) async {
    reasons.add(reason);
  }
}

class _NoopSyncCoordinator extends SyncCoordinator {
  @override
  SyncState build() => SyncState.idle;

  @override
  Future<void> resetRepositorySyncState() async {}
}

const _userId = 'cccccccc-0000-4000-8000-000000000056';

void main() {
  late StreamController<AuthState> authStates;
  late ProviderContainer container;
  late List<String> refreshes;

  setUp(() async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    authStates = StreamController<AuthState>.broadcast();
    addTearDown(authStates.close);
    refreshes = [];

    final auth = MockGoTrueClient();
    when(() => auth.currentUser).thenReturn(null);
    when(() => auth.currentSession).thenReturn(null);
    when(() => auth.onAuthStateChange).thenAnswer((_) => authStates.stream);

    final analytics = _MockAnalytics();
    when(
      () => analytics.track(any(), properties: any(named: 'properties')),
    ).thenAnswer((_) async {});
    when(analytics.resetUser).thenAnswer((_) async {});
    final report = RecordingReport();

    final client = fakeSupabaseClient(auth: auth);
    container = ProviderContainer(
      overrides: [
        appExternalDepsProvider.overrideWithValue(
          AppExternalDeps(
            analytics: analytics,
            supabaseClient: client,
            sharedPreferences: _MockPrefs(),
            report: report,
          ),
        ),
        reportProvider.overrideWithValue(report),
        supabaseClientProvider.overrideWithValue(client),
        appDatabaseProvider.overrideWithValue(db),
        syncCoordinatorProvider.overrideWith(_NoopSyncCoordinator.new),
        appStartupProvider.overrideWith(() => _RecordingStartup(refreshes)),
      ],
    );
    addTearDown(container.dispose);
    // Held as AppStartupWidget holds it in the app.
    final held = container.listen(appStartupProvider, (_, __) {});
    addTearDown(held.close);
    await container.read(appStartupProvider.future);

    container.read(authListenerServiceProvider).initialize();
  });

  Future<void> emit(AuthChangeEvent event, {String? userId}) async {
    authStates.add(
      AuthState(event, userId == null ? null : _FakeSession(_FakeUser(userId))),
    );
    // Let the listener's async handler run to completion.
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  test('a signedIn event refreshes the startup snapshot once', () async {
    await emit(AuthChangeEvent.signedIn, userId: _userId);

    expect(refreshes, ['signed_in']);
  });

  test('a restored session (initialSession) does not refresh: build read '
      'it', () async {
    await emit(AuthChangeEvent.initialSession, userId: _userId);

    expect(refreshes, isEmpty);
  });

  test('an ordinary sign-out refreshes the startup snapshot once', () async {
    await emit(AuthChangeEvent.signedOut);

    expect(refreshes, ['signed_out']);
  });

  test('an onboarding sign-out does not refresh', () async {
    container.read(authListenerServiceProvider).markOnboardingSignOut();
    await emit(AuthChangeEvent.signedOut);

    expect(refreshes, isEmpty);
  });
}
