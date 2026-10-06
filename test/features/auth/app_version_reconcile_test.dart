// users.app_version must report the build the athlete is RUNNING (Major,
// 2026-09-24).
//
// The column read '1.0.0' for all 330 prod users, because it was written once
// at account creation from a hardcoded constant. Two defects in one column:
// the value was never real, and even a real one would have frozen at the
// version first installed. That made every rollout unreadable — and, per the
// ops blueprint's D7 precondition, made it impossible to close a Critical,
// since a client-side fix whose predicate fails cannot be told apart from an
// athlete who has not updated.
//
// These run through the REAL AuthService notifier (CLAUDE.md: every controller
// write path gets one test through the real notifier), with the platform
// channel replaced by a provider override — a unit test cannot read
// PackageInfo.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:mealvana_endurance/features/auth/application/auth_service.dart';
import 'package:mealvana_endurance/features/auth/data/user_repository.dart';
import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/run_parameters.dart';
import 'package:mealvana_endurance/shared/services/app_version_service.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';

import '../../helpers/fakes/recording_report.dart';

class _MockUserRepository extends Mock implements UserRepository {}

class _FakeUserProfile extends Fake implements UserProfile {}

UserProfile _profile({required String appVersion}) => UserProfile(
  id: 'c4ecf49f-0000-4000-8000-000000000000',
  deviceId: 'device-1',
  authUserId: 'c4ecf49f-0000-4000-8000-000000000000',
  authProvider: 'apple',
  isAnonymous: false,
  gender: Gender.other,
  birthday: DateTime(1990, 1, 1),
  heightFeet: 5,
  heightInches: 10,
  weightPounds: 150,
  runsWithWaterBottle: false,
  gutTraining: GutTraining.moderate,
  sweatRate: SweatRateCat.medium,
  unitSystem: UnitSystem.imperial,
  onboardingCompleted: true,
  appVersion: appVersion,
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime(2026, 1, 1),
);

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeUserProfile());
  });

  late _MockUserRepository repo;

  ProviderContainer containerWith({required String running}) {
    final container = ProviderContainer(
      overrides: [
        // The service reports through Report; a recording one keeps the
        // reconcile's own outcome the only thing under test.
        reportProvider.overrideWithValue(RecordingReport()),
        runningAppVersionProvider.overrideWith((ref) async => running),
        userRepositoryProvider.overrideWith((ref) async => repo),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  setUp(() {
    repo = _MockUserRepository();
    when(
      () =>
          repo.updateUserProfile(any(), needsUpload: any(named: 'needsUpload')),
    ).thenAnswer((_) async {});
  });

  test('a stale stored version is rewritten to the running one', () async {
    when(
      () => repo.getCurrentUser(),
    ).thenAnswer((_) async => _profile(appVersion: '1.0.0'));

    await containerWith(
      running: '1.28.0',
    ).read(authServiceProvider).reconcileAppVersion();

    final captured =
        verify(
              () => repo.updateUserProfile(captureAny(), needsUpload: true),
            ).captured.single
            as UserProfile;
    expect(captured.appVersion, '1.28.0');
  });

  test('offline-first: the update is queued, never written through', () async {
    when(
      () => repo.getCurrentUser(),
    ).thenAnswer((_) async => _profile(appVersion: '1.24.0'));

    await containerWith(
      running: '1.28.0',
    ).read(authServiceProvider).reconcileAppVersion();

    // needsUpload: false would make a launch wait on Supabase.
    verifyNever(() => repo.updateUserProfile(any(), needsUpload: false));
  });

  test('an up-to-date version writes nothing', () async {
    when(
      () => repo.getCurrentUser(),
    ).thenAnswer((_) async => _profile(appVersion: '1.28.0'));

    await containerWith(
      running: '1.28.0',
    ).read(authServiceProvider).reconcileAppVersion();

    verifyNever(
      () =>
          repo.updateUserProfile(any(), needsUpload: any(named: 'needsUpload')),
    );
  });

  test('no profile yet (pre-onboarding) is not an error', () async {
    when(() => repo.getCurrentUser()).thenAnswer((_) async => null);

    await containerWith(
      running: '1.28.0',
    ).read(authServiceProvider).reconcileAppVersion();

    verifyNever(
      () =>
          repo.updateUserProfile(any(), needsUpload: any(named: 'needsUpload')),
    );
  });

  test(
    'a repository failure never propagates — telemetry cannot cost a launch',
    () async {
      when(() => repo.getCurrentUser()).thenThrow(StateError('db closed'));

      await expectLater(
        containerWith(
          running: '1.28.0',
        ).read(authServiceProvider).reconcileAppVersion(),
        completes,
      );
    },
  );
}
