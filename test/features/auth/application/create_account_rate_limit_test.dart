/// A second Create Account inside GoTrue's gap is a wait, not a failure
/// (develop-2026-10 ticket 42, 30-008).
///
/// Seam: GoTrue's own 429 as gotrue 2.16 throws it (`AuthApiException`,
/// status 429, code `over_email_send_rate_limit`, "For security purposes,
/// you can only request this after N seconds."), through the real
/// [PostOnboardingAuthController] and [EmailAuthService], with the real
/// Riverpod net ([SentryProviderObserver]) judging what lands in state.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    hide AuthUser, AuthException;

import 'package:mealvana_endurance/features/auth/domain/auth_exceptions.dart';
import 'package:mealvana_endurance/features/auth/presentation/providers/post_onboarding_auth_controller.dart';
import 'package:mealvana_endurance/features/auth/presentation/screens/email_signup_screen.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_provider_observer.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';

import '../../../helpers/fakes/recording_report.dart';
import '../../../helpers/test_content.dart';
import '../../../helpers/widget_test_harness.dart';

class _MockGoTrue extends Mock implements GoTrueClient {}

class _MockSupabase extends Mock implements SupabaseClient {}

class _FakeUserAttributes extends Fake implements UserAttributes {}

/// GoTrue's 429 on a second email to one address inside its gap.
AuthApiException _tooSoon(int seconds) => AuthApiException(
  'For security purposes, you can only request this after $seconds seconds.',
  statusCode: '429',
  code: 'over_email_send_rate_limit',
);

/// An anonymous session, as Welcome → Build My Plan leaves it (run 30).
User _anonymousUser() => User.fromJson({
  'id': '1ffc8851-0000-4000-8000-000000000030',
  'aud': 'authenticated',
  'role': 'authenticated',
  'email': '',
  'is_anonymous': true,
  'app_metadata': <String, dynamic>{},
  'user_metadata': <String, dynamic>{},
  'created_at': '2026-10-08T14:00:00Z',
})!;

typedef _Wired = ({
  ProviderContainer container,
  _MockGoTrue goTrue,
  RecordingReport report,
  List<String> events,
});

Future<_Wired> _wire({User? session}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final goTrue = _MockGoTrue();
  when(() => goTrue.currentUser).thenReturn(session);
  final client = _MockSupabase();
  when(() => client.auth).thenReturn(goTrue);

  final events = <String>[];
  final analytics = MockAnalyticsTracker();
  when(
    () => analytics.track(any(), properties: any(named: 'properties')),
  ).thenAnswer((inv) async => events.add(inv.positionalArguments.first));

  final report = RecordingReport();
  final observer = SentryProviderObserver(report: report);
  final container = ProviderContainer(
    observers: [observer],
    retry: observer.retry,
    overrides: [
      appExternalDepsProvider.overrideWithValue(
        AppExternalDeps(
          analytics: analytics,
          supabaseClient: client,
          sharedPreferences: prefs,
          report: report,
        ),
      ),
      analyticsTrackerProvider.overrideWithValue(analytics),
      reportProvider.overrideWithValue(report),
    ],
  );
  addTearDown(container.dispose);
  // The signup screen watches the controller; keep it alive the same way.
  container.listen(postOnboardingAuthControllerProvider, (_, _) {});
  return (container: container, goTrue: goTrue, report: report, events: events);
}

Matcher _waits(int seconds) => isA<ResendRateLimitedException>().having(
  (e) => e.retryAfterSeconds,
  'retryAfterSeconds',
  seconds,
);

void main() {
  setUpAll(() => registerFallbackValue(_FakeUserAttributes()));

  test('upgrade path: "after 0 seconds" waits 1 s; one note, no fault, no '
      'auth_flow_failed', () async {
    final w = await _wire(session: _anonymousUser());
    when(() => w.goTrue.updateUser(any())).thenThrow(_tooSoon(0));

    final ok = await w.container
        .read(postOnboardingAuthControllerProvider.notifier)
        .linkEmailAccount(email: 'athlete@example.com', password: 'secret-pw1');

    expect(ok, isFalse);
    expect(
      w.container.read(postOnboardingAuthControllerProvider).error,
      _waits(1),
    );
    expect(w.report.faults, isEmpty);
    expect(w.report.degradeds, isEmpty);
    expect(w.report.notes.map((n) => n.message), [
      'Create account rate limited',
    ]);
    expect(w.report.notes.single.data, {'retry_after_s': 1});
    expect(w.events, isNot(contains('auth_flow_failed')));
    expect(w.events, isNot(contains('email_account_linking_failed')));
  });

  test('plain path: "after 47 seconds" waits 47 s', () async {
    final w = await _wire();
    when(
      () => w.goTrue.signUp(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    ).thenThrow(_tooSoon(47));

    final ok = await w.container
        .read(postOnboardingAuthControllerProvider.notifier)
        .signUpWithEmail(email: 'athlete@example.com', password: 'secret-pw1');

    expect(ok, isFalse);
    expect(
      w.container.read(postOnboardingAuthControllerProvider).error,
      _waits(47),
    );
    expect(w.report.faults, isEmpty);
    expect(w.report.notes.single.data, {'retry_after_s': 47});
    expect(w.events, isNot(contains('auth_flow_failed')));
    expect(w.events, isNot(contains('email_signup_failed')));
  });

  testWidgets('the form counts Create Account down from the content key, '
      'with no snackbar', (tester) async {
    final content = loadDefaultContent();
    await smokeScreen(
      tester,
      const EmailSignupScreen(),
      overrides: [
        contentServiceProvider.overrideWith(testContentService),
        postOnboardingAuthControllerProvider.overrideWith(
          () => _RateLimitedController(47),
        ),
      ],
    );

    await tester.enterText(
      find.byKey(const ValueKey('signup_email.email_field')),
      'athlete@example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('signup_email.password_field')),
      'secret-pw1',
    );
    await tester.enterText(
      find.byKey(const ValueKey('signup_email.confirm_password_field')),
      'secret-pw1',
    );
    final button = find.byKey(
      const ValueKey('signup_email.create_account_button'),
    );
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();

    expect(content['auth.email_signup.create_in'], 'Create Account in {n}s');
    expect(find.text('Create Account in 47s'), findsOneWidget);
    expect(tester.widget<KylePrimaryButton>(button).onPressed, isNull);
    expect(find.byType(SnackBar), findsNothing);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Create Account in 46s'), findsOneWidget);

    // The countdown's timer goes with the screen, inside the test body.
    await tester.pumpWidget(const SizedBox());
  });
}

/// The controller as the real one leaves a 429 (see the seam tests above):
/// false, with the wait in state.
class _RateLimitedController extends PostOnboardingAuthController {
  _RateLimitedController(this.seconds);

  final int seconds;

  @override
  FutureOr<void> build() {}

  @override
  Future<bool> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    state = AsyncError(ResendRateLimitedException(seconds), StackTrace.empty);
    return false;
  }
}
