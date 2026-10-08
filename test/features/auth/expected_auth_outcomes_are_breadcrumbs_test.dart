/// Expected auth outcomes are breadcrumbs, not Sentry events (develop-2026-10
/// ticket 41: 30-005, 32-007's offline Log In).
///
/// Seam: the real [PostOnboardingAuthController] over the real
/// [EmailAuthService], in a container that carries the real Riverpod net
/// ([SentryProviderObserver]). Only GoTrue is mocked, and it throws what
/// gotrue throws: `AuthApiException` 400 `invalid_credentials`, 422
/// `email_exists`, 500, and `AuthRetryableFetchException` wrapping a socket
/// failure, never the app's own mapped types (those are what the code under
/// test produces).
///
/// Each outcome: no fault, no degraded, one `expected_failure` count (Lee
/// 2026-10-08: keep the counts), and the screen still gets the typed error.
library;

import 'dart:async' show FutureOr;
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    hide AuthUser, AuthException;

import 'package:mealvana_endurance/features/auth/application/apple_web_authentication.dart';
import 'package:mealvana_endurance/features/auth/application/email_auth_service.dart';
import 'package:mealvana_endurance/features/auth/domain/auth_exceptions.dart';
import 'package:mealvana_endurance/features/auth/presentation/providers/post_onboarding_auth_controller.dart';
import 'package:mealvana_endurance/features/auth/presentation/screens/post_onboarding_auth_screen.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_provider_observer.dart';

import '../../helpers/fakes/recording_analytics_tracker.dart';
import '../../helpers/fakes/recording_report.dart';
import '../../helpers/widget_test_harness.dart';

/// A [RecordingReport] with `SentryReport`'s identity rule, on its shared
/// registry: an error object already captured, or marked as reported
/// (`SentryReport.markReported`), is not captured again (`report.dart`,
/// `_capture`). The count of [faults] is the count of Sentry events.
class _DedupingReport extends RecordingReport {
  bool _firstTime(Object error) {
    if (SentryReport.wasReported(error)) return false;
    SentryReport.markReported(error);
    return true;
  }

  @override
  Future<void> fault(
    Object error, {
    StackTrace? stackTrace,
    String? area,
    Map<String, String>? tags,
    Map<String, dynamic>? extra,
    String? message,
    List<String>? fingerprint,
  }) async {
    if (!_firstTime(error)) return;
    await super.fault(
      error,
      stackTrace: stackTrace,
      area: area,
      tags: tags,
      extra: extra,
      message: message,
    );
  }

  @override
  Future<void> degraded(
    Object error, {
    StackTrace? stackTrace,
    String? area,
    Map<String, String>? tags,
    Map<String, dynamic>? extra,
    String? message,
    List<String>? fingerprint,
  }) async {
    if (!_firstTime(error)) return;
    await super.degraded(
      error,
      stackTrace: stackTrace,
      area: area,
      tags: tags,
      extra: extra,
      message: message,
    );
  }

  List<RecordedReport> get authFlow => calls
      .where((c) => c.severity == 'breadcrumb' && c.area == authFlowCategory)
      .toList();

  List<RecordedReport> get authNotes =>
      notes.where((c) => c.area == 'auth').toList();
}

/// GoTrue's answers, as the dev project gave them in the Findings.
final _wrongPassword = AuthApiException(
  'Invalid login credentials',
  statusCode: '400',
  code: 'invalid_credentials',
);
final _emailExists = AuthApiException(
  'A user with this email address has already been registered',
  statusCode: '422',
  code: 'email_exists',
);

/// gotrue wraps any non-HTTP failure as its `toString()`
/// (`GotrueFetch._handleRequest`).
AuthRetryableFetchException _offline() => AuthRetryableFetchException(
  message: const SocketException(
    "Failed host lookup: 'vlmtsdzpnjnavdgytcmi.supabase.co'",
  ).toString(),
);

typedef _Wired = ({
  ProviderContainer container,
  MockGoTrueClient goTrue,
  _DedupingReport report,
  RecordingAnalyticsTracker analytics,
});

_Wired _wired() {
  final goTrue = fakeGoTrueClient() as MockGoTrueClient;
  final prefs = MockSharedPreferences();
  when(() => prefs.getString(any())).thenReturn(null);
  final analytics = RecordingAnalyticsTracker();
  final report = _DedupingReport();
  final observer = SentryProviderObserver(report: report);
  final container = ProviderContainer(
    observers: [observer],
    retry: observer.retry,
    overrides: [
      appExternalDepsProvider.overrideWithValue(
        AppExternalDeps(
          analytics: analytics,
          supabaseClient: fakeSupabaseClient(auth: goTrue),
          sharedPreferences: prefs,
          report: report,
        ),
      ),
      reportProvider.overrideWithValue(report),
      analyticsTrackerProvider.overrideWithValue(analytics),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );
  addTearDown(container.dispose);
  // The screens watch the controller; the service is held the same way so
  // the net sees what each writes into its state.
  container.listen(postOnboardingAuthControllerProvider, (_, _) {});
  container.listen(emailAuthServiceProvider, (_, _) {});
  return (
    container: container,
    goTrue: goTrue,
    report: report,
    analytics: analytics,
  );
}

void _signInAnswers(MockGoTrueClient goTrue, Object error) {
  when(
    () => goTrue.signInWithPassword(
      email: any(named: 'email'),
      password: any(named: 'password'),
    ),
  ).thenThrow(error);
}

PostOnboardingAuthController _controller(_Wired w) =>
    w.container.read(postOnboardingAuthControllerProvider.notifier);

Object? _screenError(_Wired w) =>
    w.container.read(postOnboardingAuthControllerProvider).error;

/// No Sentry event, exactly one count with [reason], and every `auth.flow`
/// breadcrumb names [type].
void _isAnOutcome(_Wired w, {required String reason, required Type type}) {
  expect(w.report.faults, isEmpty);
  expect(w.report.degradeds, isEmpty);
  expect(w.analytics.findEvents(expectedFailureEvent), hasLength(1));
  expect(w.analytics.findEvents(expectedFailureEvent).single.properties, {
    'area': 'auth',
    'reason': reason,
  });
  expect(w.report.authFlow, isNotEmpty);
  for (final crumb in w.report.authFlow) {
    expect(crumb.data?['type'], type.toString());
  }
}

/// The Apple sheet's answer, pinned on the controller the screen reads: the
/// state and the `false` the real controller leaves after the service threw
/// [error] (ticket 55's widget half; the service and controller halves are in
/// `oauth_cancel_is_quiet_test.dart`).
class _AppleAnswersController extends PostOnboardingAuthController {
  _AppleAnswersController(this.error);

  final Object error;

  @override
  FutureOr<void> build() {}

  Future<bool> _fail() async {
    state = AsyncError<void>(error, StackTrace.current);
    return false;
  }

  @override
  Future<bool> linkAppleAccount() => _fail();

  @override
  Future<bool> signInWithApple() => _fail();
}

/// Create Your Account on an anonymous session (the Apple button links).
Future<void> _tapAppleOnCreateYourAccount(
  WidgetTester tester,
  Object error,
) async {
  final goTrue = fakeGoTrueClient() as MockGoTrueClient;
  when(() => goTrue.currentUser).thenReturn(
    const User(
      id: 'anon-user',
      appMetadata: <String, dynamic>{},
      userMetadata: <String, dynamic>{},
      aud: 'authenticated',
      createdAt: '2026-10-08T00:00:00Z',
      isAnonymous: true,
    ),
  );
  await smokeScreen(
    tester,
    const PostOnboardingAuthScreen(),
    // Its own Supabase client: smokeScreen's default deps would be a second
    // override of the same provider.
    withAppDeps: false,
    overrides: [
      mockAppExternalDeps(supabaseClient: fakeSupabaseClient(auth: goTrue)),
      appConfigProvider.overrideWithValue(AppConfig.forTesting()),
      mockSharedPreferences(),
      appleSignInAvailableProvider.overrideWithValue(true),
      postOnboardingAuthControllerProvider.overrideWith(
        () => _AppleAnswersController(error),
      ),
    ],
  );
  final apple = find.byKey(const ValueKey('post_onboarding.apple_button'));
  await tester.scrollUntilVisible(apple, 200);
  await tester.tap(apple);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
    registerFallbackValue(OtpType.signup);
  });

  group('email Log In through the real controller and service', () {
    test('a wrong password: WrongCredentials on screen, one service note, '
        'no event', () async {
      final w = _wired();
      _signInAnswers(w.goTrue, _wrongPassword);

      final ok = await _controller(
        w,
      ).signInWithEmail(email: 'a@b.com', password: 'nope-nope');
      await Future<void>.delayed(Duration.zero);

      expect(ok, isFalse);
      expect(_screenError(w), isA<WrongCredentialsException>());
      _isAnOutcome(
        w,
        reason: 'wrong_credentials',
        type: WrongCredentialsException,
      );
      expect(
        w.report.authNotes.where(
          (n) => n.message == 'Email sign in: WrongCredentialsException',
        ),
        hasLength(1),
      );
      // Mixpanel's own failure line stays, naming the outcome.
      expect(
        w.analytics.findEvents('auth_flow_failed').single.properties?['error'],
        'WrongCredentialsException',
      );
    });

    test('offline Log In: NoConnection on screen, one count, no event '
        '(was two: AuthRetryableFetchException and NoConnection)', () async {
      final w = _wired();
      _signInAnswers(w.goTrue, _offline());

      final ok = await _controller(
        w,
      ).signInWithEmail(email: 'a@b.com', password: 'password1');
      await Future<void>.delayed(Duration.zero);

      expect(ok, isFalse);
      expect(_screenError(w), isA<NoConnectionException>());
      _isAnOutcome(w, reason: 'offline', type: NoConnectionException);
    });

    test('a GoTrue 500 is exactly one fault, with area auth', () async {
      final w = _wired();
      _signInAnswers(
        w.goTrue,
        AuthApiException(
          'Internal server error',
          statusCode: '500',
          code: 'unexpected_failure',
        ),
      );

      final ok = await _controller(
        w,
      ).signInWithEmail(email: 'a@b.com', password: 'password1');
      await Future<void>.delayed(Duration.zero);

      expect(ok, isFalse);
      expect(_screenError(w), isA<SignInFailedException>());
      expect(w.report.faults, hasLength(1));
      expect(w.report.faults.single.area, 'auth');
      expect(w.report.faults.single.error, isA<AuthApiException>());
      expect(w.report.authFlow, isEmpty);
      expect(w.analytics.findEvents(expectedFailureEvent), isEmpty);
    });
  });

  group('email signup through the real controller and service', () {
    test('an address that already has an account: AccountAlreadyExists on '
        'screen, not the 422, and no event', () async {
      final w = _wired();
      when(
        () => w.goTrue.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(_emailExists);

      final ok = await _controller(
        w,
      ).signUpWithEmail(email: 'a@b.com', password: 'password1');
      await Future<void>.delayed(Duration.zero);

      expect(ok, isFalse);
      expect(_screenError(w), isA<AccountAlreadyExistsException>());
      expect(
        w.container.read(emailAuthServiceProvider).error,
        isA<AccountAlreadyExistsException>(),
        reason: 'the service writes the outcome, not GoTrue\'s 422',
      );
      _isAnOutcome(
        w,
        reason: 'account_exists',
        type: AccountAlreadyExistsException,
      );
      expect(
        w.analytics.findEvents('auth_account_already_exists'),
        hasLength(1),
      );
    });

    test('a GoTrue 500 on signup is still one fault, with area auth', () async {
      final w = _wired();
      when(
        () => w.goTrue.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(
        AuthApiException(
          'Database error saving new user',
          statusCode: '500',
          code: 'unexpected_failure',
        ),
      );

      final ok = await _controller(
        w,
      ).signUpWithEmail(email: 'a@b.com', password: 'password1');
      await Future<void>.delayed(Duration.zero);

      expect(ok, isFalse);
      expect(w.report.faults, hasLength(1));
      expect(w.report.faults.single.area, 'auth');
      expect(w.analytics.findEvents(expectedFailureEvent), isEmpty);
    });
  });

  // develop-2026-10 ticket 55 (48-001): Close on iOS's "Sign in to your Apple
  // Account" sheet answers 1000. The sheet has said what to do; the screen
  // says nothing more.
  group('Create Your Account after an Apple answer', () {
    testWidgets('no Apple account (1000) shows no snackbar', (tester) async {
      await _tapAppleOnCreateYourAccount(
        tester,
        const AppleNoAccountException(),
      );

      expect(find.byType(SnackBar), findsNothing);
      expect(find.textContaining('Sign in failed'), findsNothing);
    });

    testWidgets('any other Apple failure still says Sign in failed', (
      tester,
    ) async {
      await _tapAppleOnCreateYourAccount(tester, Exception('error 1004'));

      expect(find.textContaining('Sign in failed'), findsOneWidget);
    });
  });
}
