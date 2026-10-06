/// Ticket 18 (Sentry MEALVANA-ENDURANCE-CK / DEV-93, C9 / CA, BZ):
/// `settingsControllerProvider` is auto-dispose, and the Settings screen is
/// often gone before its async work ends (sign-out, account deletion, a quick
/// back-swipe). The old code then touched `ref` or `state` after the await
/// and threw `UnmountedRefException`:
///
/// - `build()` read `athleteZonesProvider` after the profile lookups (CK);
/// - `_saveProfile()` assigned `state` after the save (C9), so a save that
///   had already reached the repository still threw at its caller.
///
/// Both run through the real notifier in a `ProviderContainer`.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/auth/application/supabase_auth_service.dart';
import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/coach_mode/data/coach_repository.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/features/daily_macros/application/daily_macro_service.dart';
import 'package:mealvana_endurance/features/integrations/presentation/providers/athlete_zones_provider.dart';
import 'package:mealvana_endurance/features/settings/presentation/providers/settings_controller.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';
import 'package:mocktail/mocktail.dart';
import 'package:riverpod/riverpod.dart';

import '../../helpers/fakes/recording_report.dart';

class _MockUserRepository extends Mock implements UserRepository {}

class _MockCoachRepository extends Mock implements CoachRepository {}

class _MockContentService extends Mock implements ContentService {}

class _MockDailyMacroService extends Mock implements DailyMacroService {}

/// Every failure Riverpod reports, as the app's Sentry observer would see it.
final class _FailureLog extends ProviderObserver {
  final List<Object> errors = [];

  @override
  void providerDidFail(
    ProviderObserverContext context,
    Object error,
    StackTrace stackTrace,
  ) {
    errors.add(error);
  }
}

UserProfile _profile() => UserProfile(
  id: 'u1',
  deviceId: 'd1',
  gender: Gender.male,
  birthday: DateTime(1985, 3, 20),
  heightFeet: 5,
  heightInches: 11,
  weightPounds: 165,
  runsWithWaterBottle: false,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
  appVersion: '1.0.0',
);

void main() {
  setUpAll(() => registerFallbackValue(_profile()));

  late _MockUserRepository repo;
  late Completer<UserRepository> repoGate;
  late _FailureLog failures;
  late RecordingReport report;
  late int zoneBuilds;
  late ProviderContainer container;

  setUp(() {
    repo = _MockUserRepository();
    when(() => repo.getCurrentUser()).thenAnswer((_) async => _profile());
    final coach = _MockCoachRepository();
    when(() => coach.isUserApprovedCoach(any())).thenAnswer((_) async => false);
    final content = _MockContentService();
    when(
      () => content.getValue(any(), defaultValue: any(named: 'defaultValue')),
    ).thenAnswer(
      (inv) => inv.namedArguments[#defaultValue] as String? ?? '',
    );
    repoGate = Completer<UserRepository>();
    failures = _FailureLog();
    report = RecordingReport();
    zoneBuilds = 0;
    container = ProviderContainer(
      observers: [failures],
      overrides: [
        currentUserProvider.overrideWith((ref) => Stream.value(null)),
        coachRepositoryProvider.overrideWithValue(coach),
        contentServiceProvider.overrideWithValue(content),
        dailyMacroServiceProvider.overrideWithValue(_MockDailyMacroService()),
        userRepositoryProvider.overrideWith((ref) => repoGate.future),
        athleteZonesProvider('u1').overrideWith((ref) async {
          zoneBuilds++;
          return null;
        }),
        reportProvider.overrideWithValue(report),
      ],
    );
    addTearDown(container.dispose);
  });

  test('build disposed while loading the profile finishes without a throw '
      'and skips the zone lookup', () async {
    final sub = container.listen(settingsControllerProvider, (_, _) {});
    await pumpEventQueue();
    sub.close();
    await container.pump();
    expect(container.exists(settingsControllerProvider), isFalse);

    repoGate.complete(repo);
    await pumpEventQueue();

    expect(failures.errors, isEmpty);
    expect(report.faults, isEmpty);
    expect(zoneBuilds, 0, reason: 'a disposed build must not read ref');
  });

  test('a save whose controller is disposed mid-write still reaches the '
      'repository and returns without a throw', () async {
    repoGate.complete(repo);
    final writeGate = Completer<void>();
    UserProfile? written;
    when(
      () => repo.updateUserProfile(any(), needsUpload: any(named: 'needsUpload')),
    ).thenAnswer((inv) async {
      await writeGate.future;
      written = inv.positionalArguments.first as UserProfile;
    });

    final sub = container.listen(settingsControllerProvider, (_, _) {});
    await container.read(settingsControllerProvider.future);
    final notifier = container.read(settingsControllerProvider.notifier);

    final save = notifier.updateCyclingPreferences(ftpWatts: 250);
    await pumpEventQueue();
    sub.close();
    await container.pump();
    expect(container.exists(settingsControllerProvider), isFalse);

    writeGate.complete();
    await expectLater(save, completes);

    expect(written?.ftpWatts, 250);
    expect(failures.errors, isEmpty);
    expect(report.faults, isEmpty);
  });
}
