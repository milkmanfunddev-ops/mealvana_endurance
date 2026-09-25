// Ticket 108, Finding 32-003 (Lee, 2026-09-25): once Set New Password
// succeeds, every session of the account ends, the recovery session the reset
// code opened and any other device alike. The athlete then signs in once with
// the new password. A failed update signs nothing out.
//
// Seam: the real PasswordRecoveryController over the real
// SupabaseAuthService, with only GoTrue faked.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mealvana_endurance/features/auth/presentation/providers/password_recovery_controller.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';

import '../../../helpers/fakes/fake_supabase_client.dart';
import '../../../helpers/widget_test_harness.dart';

class _MockAnalyticsTracker extends Mock implements AnalyticsTracker {}

class _MockUserResponse extends Mock implements UserResponse {}

class _FakeUserAttributes extends Fake implements UserAttributes {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeUserAttributes());
    registerFallbackValue(SignOutScope.local);
  });

  late MockGoTrueClient goTrue;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    goTrue = MockGoTrueClient();
    when(() => goTrue.currentUser).thenReturn(null);
    when(() => goTrue.currentSession).thenReturn(null);
    when(
      () => goTrue.onAuthStateChange,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => goTrue.signOut(scope: any(named: 'scope')),
    ).thenAnswer((_) async {});

    container = ProviderContainer(
      overrides: [
        appExternalDepsProvider.overrideWithValue(
          AppExternalDeps(
            analytics: _MockAnalyticsTracker(),
            supabaseClient: fakeSupabaseClient(auth: goTrue),
            sentry: mockSentryReporter(),
            logger: MockAppLogger(),
            sharedPreferences: prefs,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    // Auto-dispose: keep the notifier alive across the awaits.
    container.listen(passwordRecoveryControllerProvider, (_, _) {});
  });

  test('a successful reset signs out every session (global scope)', () async {
    when(
      () => goTrue.updateUser(any()),
    ).thenAnswer((_) async => _MockUserResponse());

    final ok = await container
        .read(passwordRecoveryControllerProvider.notifier)
        .setNewPassword('new-password-123');

    expect(ok, isTrue);
    verifyInOrder([
      () => goTrue.updateUser(any()),
      () => goTrue.signOut(scope: SignOutScope.global),
    ]);
    verifyNever(() => goTrue.signOut(scope: SignOutScope.local));
    verifyNever(() => goTrue.signOut(scope: SignOutScope.others));
  });

  test('a failed reset signs nothing out', () async {
    when(() => goTrue.updateUser(any())).thenThrow(Exception('weak password'));

    final ok = await container
        .read(passwordRecoveryControllerProvider.notifier)
        .setNewPassword('new-password-123');

    expect(ok, isFalse);
    verifyNever(() => goTrue.signOut(scope: any(named: 'scope')));
  });

  test(
    'the reset still succeeds when ending the other sessions fails',
    () async {
      when(
        () => goTrue.updateUser(any()),
      ).thenAnswer((_) async => _MockUserResponse());
      when(
        () => goTrue.signOut(scope: any(named: 'scope')),
      ).thenThrow(Exception('offline'));

      final ok = await container
          .read(passwordRecoveryControllerProvider.notifier)
          .setNewPassword('new-password-123');

      // The password changed; the athlete goes on to Log In as usual.
      expect(ok, isTrue);
      verify(() => goTrue.signOut(scope: SignOutScope.global)).called(1);
    },
  );
}
