// Account creation failure reaches Report with its real cause
// (MEALVANA-ENDURANCE-CG, DEV-8Q, DEV-8X; ticket 20).
//
// EmailAuthService used to swallow every signup/link failure into
// `Exception('Account creation failed. Please try again.')`. The controller
// then reported that wrapper, a new object Report's identity dedupe could not
// tie to the cause, so Sentry got a causeless issue (CG) next to the real one
// (CH: `AuthApiException(Invalid API key, 401)`). These seam tests drive the
// real PostOnboardingAuthController through the real EmailAuthService, with
// GoTrue throwing exactly what gotrue 2.16 `GotrueFetch._handleError` throws
// for the response Sentry recorded.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    hide AuthUser, AuthException;

import 'package:mealvana_endurance/features/auth/domain/auth_exceptions.dart';
import 'package:mealvana_endurance/features/auth/presentation/providers/post_onboarding_auth_controller.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';

import '../../helpers/fakes/recording_report.dart';
import '../../helpers/widget_test_harness.dart';

class _MockGoTrue extends Mock implements GoTrueClient {}

class _MockSupabase extends Mock implements SupabaseClient {}

class _MockUser extends Mock implements User {}

class _FakeUserAttributes extends Fake implements UserAttributes {}

const _email = 'athlete@example.com';
const _password = 'password123';

/// A controller wired to the real service over [auth], reporting into
/// [report], plus the container that holds its state.
({ProviderContainer container, PostOnboardingAuthController controller}) _wire(
  GoTrueClient auth,
  RecordingReport report,
) {
  final client = _MockSupabase();
  when(() => client.auth).thenReturn(auth);

  final analytics = MockAnalyticsTracker();
  when(
    () => analytics.track(any(), properties: any(named: 'properties')),
  ).thenAnswer((_) async {});

  final container = ProviderContainer(
    overrides: [
      appExternalDepsProvider.overrideWithValue(
        AppExternalDeps(
          analytics: analytics,
          supabaseClient: client,
          sharedPreferences: MockSharedPreferences(),
        ),
      ),
      analyticsTrackerProvider.overrideWithValue(analytics),
      reportProvider.overrideWithValue(report),
    ],
  );
  addTearDown(container.dispose);
  // The signup screen watches the controller; keep it alive the same way.
  container.listen(postOnboardingAuthControllerProvider, (_, __) {});
  return (
    container: container,
    controller: container.read(postOnboardingAuthControllerProvider.notifier),
  );
}

/// No session: the sessionless (fresh signup) route.
_MockGoTrue _signedOut() {
  final auth = _MockGoTrue();
  when(() => auth.currentUser).thenReturn(null);
  return auth;
}

/// An anonymous session: the uid-preserving link route.
_MockGoTrue _anonymous() {
  final auth = _MockGoTrue();
  final user = _MockUser();
  when(() => user.id).thenReturn('anon-uid');
  when(() => user.isAnonymous).thenReturn(true);
  when(() => auth.currentUser).thenReturn(user);
  return auth;
}

void main() {
  setUpAll(() => registerFallbackValue(_FakeUserAttributes()));

  test('signup: the Fault carries the AuthApiException the server sent, '
      'never the generic wrapper (CG / CH)', () async {
    // CH: POST /auth/v1/signup answered 401 {"message":"Invalid API key"}.
    final cause = AuthApiException('Invalid API key', statusCode: '401');
    final auth = _signedOut();
    when(
      () => auth.signUp(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenThrow(cause);
    final report = RecordingReport();
    final wired = _wire(auth, report);

    final ok = await wired.controller.signUpWithEmail(
      email: _email,
      password: _password,
    );

    expect(ok, isFalse);
    expect(
      wired.container.read(postOnboardingAuthControllerProvider).error,
      same(cause),
    );
    expect(report.faults, isNotEmpty);
    for (final fault in report.faults) {
      // The same object end to end, so the real Report captures it once.
      expect(fault.error, same(cause), reason: '$fault');
      expect(fault.area, 'auth');
    }
    expect(
      report.faults.where(
        (f) => f.error.toString().contains('Account creation failed'),
      ),
      isEmpty,
    );
  });

  test(
    'link: a 500 from GoTrue reaches Report as itself (DEV-8W / DEV-8X)',
    () async {
      // DEV-8W: PUT /auth/v1/user answered 500 while dev SMTP was down.
      final cause = AuthRetryableFetchException(
        message:
            '{"code":"unexpected_failure","message":"Error sending email change email"}',
        statusCode: '500',
      );
      final auth = _anonymous();
      when(() => auth.updateUser(any())).thenThrow(cause);
      final report = RecordingReport();
      final wired = _wire(auth, report);

      final ok = await wired.controller.linkEmailAccount(
        email: _email,
        password: _password,
      );

      expect(ok, isFalse);
      expect(report.faults, isNotEmpty);
      expect(report.faults.every((f) => identical(f.error, cause)), isTrue);
    },
  );

  test('an already-registered address routes to "sign in instead" '
      'and raises no Fault', () async {
    final auth = _signedOut();
    when(
      () => auth.signUp(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenThrow(
      AuthApiException(
        'User already registered',
        statusCode: '422',
        code: 'user_already_exists',
      ),
    );
    final report = RecordingReport();
    final wired = _wire(auth, report);

    final ok = await wired.controller.signUpWithEmail(
      email: _email,
      password: _password,
    );

    expect(ok, isFalse);
    expect(report.faults, isEmpty);
    // The screen routes on this type to show the existing-account dialog.
    expect(
      wired.container.read(postOnboardingAuthControllerProvider).error,
      isA<AccountAlreadyExistsException>(),
    );
  });
}
