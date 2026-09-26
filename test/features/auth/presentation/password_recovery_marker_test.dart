/// A recovery session is signed out unless the new password is saved
/// (testing-wave 124-003, Lee 2026-09-26). The right reset code signs the
/// phone in; that session is marked pending, Set New Password clears the
/// marker, Cancel or back signs it out, and a marker still set at startup
/// (the app was quit on Set New Password) signs out before routing.
///
/// Seam: the real [PasswordRecoveryController] and the real
/// [AppStartupService.endAbandonedRecovery] over real SharedPreferences, with
/// only GoTrue faked.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mealvana_endurance/features/app_startup/application/app_startup_service.dart';
import 'package:mealvana_endurance/features/auth/presentation/providers/password_recovery_controller.dart';
import 'package:mealvana_endurance/features/subscription/application/subscription_status_provider.dart';
import 'package:mealvana_endurance/features/subscription/data/subscription_service.dart';
import 'package:mealvana_endurance/features/subscription/data/user_entitlements_repository.dart';
import 'package:mealvana_endurance/features/subscription/domain/entitlement.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/notification_service.dart';

import '../../../helpers/widget_test_harness.dart';

class _MockAnalyticsTracker extends Mock implements AnalyticsTracker {}

class _MockUserResponse extends Mock implements UserResponse {}

class _MockAuthResponse extends Mock implements AuthResponse {}

class _MockSession extends Mock implements Session {}

class _MockUser extends Mock implements User {}

class _MockSubscriptionService extends Mock implements SubscriptionService {}

class _MockEntitlementsRepo extends Mock
    implements UserEntitlementsRepository {}

class _FakeScheduler implements LocalNotificationScheduler {
  @override
  Future<bool> scheduleOnce({
    required int id,
    required DateTime when,
    required String title,
    required String body,
    String? payload,
  }) async => true;

  @override
  Future<void> cancel(int id) async {}
}

class _FakeUserAttributes extends Fake implements UserAttributes {}

const _marker = PasswordRecoveryController.recoveryPendingKey;

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeUserAttributes());
    registerFallbackValue(SignOutScope.local);
    registerFallbackValue(OtpType.recovery);
    registerFallbackValue(StackTrace.empty);
  });

  late MockGoTrueClient goTrue;
  late SharedPreferences prefs;
  late _MockSubscriptionService subscription;
  late ProviderContainer container;

  /// GoTrue holding the recovery session the right code opened.
  void signedIn() {
    final session = _MockSession();
    final user = _MockUser();
    when(() => user.id).thenReturn('recovering-user');
    when(() => session.user).thenReturn(user);
    when(() => goTrue.currentSession).thenReturn(session);
    when(() => goTrue.currentUser).thenReturn(user);
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    goTrue = MockGoTrueClient();
    when(() => goTrue.currentUser).thenReturn(null);
    when(() => goTrue.currentSession).thenReturn(null);
    when(
      () => goTrue.onAuthStateChange,
    ).thenAnswer((_) => const Stream.empty());
    when(
      () => goTrue.signOut(scope: any(named: 'scope')),
    ).thenAnswer((_) async {});
    when(
      () => goTrue.verifyOTP(
        email: any(named: 'email'),
        token: any(named: 'token'),
        type: any(named: 'type'),
      ),
    ).thenAnswer((_) async => _MockAuthResponse());
    when(
      () => goTrue.updateUser(any()),
    ).thenAnswer((_) async => _MockUserResponse());

    subscription = _MockSubscriptionService();
    when(() => subscription.setStatusListener(any())).thenReturn(null);
    when(
      () => subscription.currentAppUserId(),
    ).thenAnswer((_) async => 'recovering-user');
    when(() => subscription.logIn(any())).thenAnswer((_) async {});
    when(() => subscription.logOut()).thenAnswer((_) async {});
    when(
      () => subscription.fetchStatus(),
    ).thenAnswer((_) async => SubscriptionStatus.none);
    final entitlements = _MockEntitlementsRepo();
    when(() => entitlements.currentUserId).thenReturn(null);
    when(
      () => entitlements.authUserIdChanges,
    ).thenAnswer((_) => const Stream<String?>.empty());

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
        sharedPreferencesProvider.overrideWithValue(prefs),
        subscriptionServiceProvider.overrideWithValue(subscription),
        userEntitlementsRepositoryProvider.overrideWithValue(entitlements),
        localNotificationSchedulerProvider.overrideWithValue(_FakeScheduler()),
        entitlementAnswerTimeoutProvider.overrideWithValue(
          const Duration(milliseconds: 20),
        ),
      ],
    );
    addTearDown(container.dispose);
    // Auto-dispose: keep the notifier alive across the awaits.
    container.listen(passwordRecoveryControllerProvider, (_, _) {});
  });

  PasswordRecoveryController controller() =>
      container.read(passwordRecoveryControllerProvider.notifier);

  test('the right code marks a recovery pending', () async {
    expect(await controller().verifyResetCode('a@b.com', '123456'), isTrue);
    expect(prefs.getBool(_marker), isTrue);
  });

  test('a refused code marks nothing', () async {
    when(
      () => goTrue.verifyOTP(
        email: any(named: 'email'),
        token: any(named: 'token'),
        type: any(named: 'type'),
      ),
    ).thenThrow(AuthApiException('Token has expired or is invalid'));

    expect(await controller().verifyResetCode('a@b.com', '000000'), isFalse);
    expect(prefs.getBool(_marker), isNull);
  });

  test('saving the new password clears the marker (then signs out '
      'everywhere, ticket 108)', () async {
    await prefs.setBool(_marker, true);

    expect(await controller().setNewPassword('new-password-123'), isTrue);

    expect(prefs.getBool(_marker), isNull);
    verify(() => goTrue.signOut(scope: SignOutScope.global)).called(1);
  });

  test('a failed password update keeps the marker', () async {
    await prefs.setBool(_marker, true);
    when(() => goTrue.updateUser(any())).thenThrow(Exception('weak'));

    expect(await controller().setNewPassword('short'), isFalse);
    expect(prefs.getBool(_marker), isTrue);
  });

  test('cancel signs the recovery session out, clears the marker and lets '
      'the RevenueCat identity go', () async {
    signedIn();
    await prefs.setBool(_marker, true);

    await controller().cancelRecovery();

    verify(() => goTrue.signOut(scope: SignOutScope.local)).called(1);
    verify(() => subscription.logOut()).called(1);
    expect(prefs.getBool(_marker), isNull);
  });

  test('cancel with no session signs nothing out and never throws', () async {
    await prefs.setBool(_marker, true);

    await controller().cancelRecovery();

    verifyNever(() => goTrue.signOut(scope: any(named: 'scope')));
    expect(prefs.getBool(_marker), isNull);
  });

  group('AppStartupService.endAbandonedRecovery', () {
    AppStartupService startup() =>
        AppStartupService(container.read(_refProvider));

    test('a marker still set at startup signs out before routing', () async {
      signedIn();
      await prefs.setBool(_marker, true);

      await startup().endAbandonedRecovery();

      verify(() => goTrue.signOut(scope: SignOutScope.local)).called(1);
      expect(prefs.getBool(_marker), isNull);
    });

    test('no marker: an ordinary signed-in start is left alone', () async {
      signedIn();

      await startup().endAbandonedRecovery();

      verifyNever(() => goTrue.signOut(scope: any(named: 'scope')));
    });

    test(
      'a marker with no session clears itself and signs nothing out',
      () async {
        await prefs.setBool(_marker, true);

        await startup().endAbandonedRecovery();

        verifyNever(() => goTrue.signOut(scope: any(named: 'scope')));
        expect(prefs.getBool(_marker), isNull);
      },
    );

    test('running twice: the second run finds no marker', () async {
      signedIn();
      await prefs.setBool(_marker, true);

      await startup().endAbandonedRecovery();
      await startup().endAbandonedRecovery();

      verify(() => goTrue.signOut(scope: SignOutScope.local)).called(1);
    });
  });
}

/// A Ref into the test container, for building the service the way its
/// provider does.
final _refProvider = Provider<Ref>((ref) => ref);
