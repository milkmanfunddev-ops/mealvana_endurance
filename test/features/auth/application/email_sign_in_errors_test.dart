/// Log In errors told apart (testing-wave 125-002, 125-007, 124-001): the
/// real [EmailAuthService.signInWithEmail] maps GoTrue's answer to one typed
/// [EmailSignInException], so the screen can say wrong email or password, no
/// connection, or that the address still wants its signup code.
///
/// Seam: GoTrue's own exceptions as gotrue throws them, never the service's
/// own types fed back in.
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    hide AuthUser, AuthException;

import 'package:mealvana_endurance/features/auth/application/email_auth_service.dart';
import 'package:mealvana_endurance/features/auth/domain/auth_exceptions.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';

import '../../../helpers/widget_test_harness.dart';

/// GoTrue's answers, as the dev project gave them in the Findings.
final _wrongPassword = AuthApiException(
  'Invalid login credentials',
  statusCode: '400',
  code: 'invalid_credentials',
);
final _notConfirmed = AuthApiException(
  'Email not confirmed',
  statusCode: '400',
  code: 'email_not_confirmed',
);

({ProviderContainer container, MockGoTrueClient goTrue, MockAppLogger logger})
_wired() {
  final goTrue = fakeGoTrueClient() as MockGoTrueClient;
  final prefs = MockSharedPreferences();
  when(() => prefs.getString(any())).thenReturn(null);
  final analytics = MockAnalyticsTracker();
  when(
    () => analytics.track(any(), properties: any(named: 'properties')),
  ).thenAnswer((_) async {});
  final logger = MockAppLogger();
  final container = ProviderContainer(
    overrides: [
      appExternalDepsProvider.overrideWithValue(
        AppExternalDeps(
          analytics: analytics,
          supabaseClient: fakeSupabaseClient(auth: goTrue),
          sentry: mockSentryReporter(),
          logger: logger,
          sharedPreferences: prefs,
        ),
      ),
      analyticsTrackerProvider.overrideWithValue(analytics),
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );
  addTearDown(container.dispose);
  // Auto-dispose: keep the notifier alive across the awaits.
  container.listen(emailAuthServiceProvider, (_, _) {});
  return (container: container, goTrue: goTrue, logger: logger);
}

void main() {
  setUpAll(() {
    registerFallbackValue(StackTrace.empty);
    registerFallbackValue(OtpType.signup);
  });

  group('EmailAuthService.mapSignInError (seam: gotrue exceptions)', () {
    test('invalid_credentials is a wrong email or password', () {
      expect(
        EmailAuthService.mapSignInError(_wrongPassword, email: 'a@b.com'),
        isA<WrongCredentialsException>(),
      );
    });

    test('a socket failure or a retryable fetch is no connection', () {
      expect(
        EmailAuthService.mapSignInError(
          const SocketException('Network is unreachable'),
          email: 'a@b.com',
        ),
        isA<NoConnectionException>(),
      );
      expect(
        EmailAuthService.mapSignInError(
          AuthRetryableFetchException(message: 'Failed host lookup'),
          email: 'a@b.com',
        ),
        isA<NoConnectionException>(),
      );
      expect(
        EmailAuthService.mapSignInError(
          http.ClientException('Connection closed'),
          email: 'a@b.com',
        ),
        isA<NoConnectionException>(),
      );
    });

    test('email_not_confirmed carries the address', () {
      final mapped = EmailAuthService.mapSignInError(
        _notConfirmed,
        email: ' B@Example.com ',
      );
      expect(mapped, isA<EmailNotConfirmedException>());
      expect((mapped as EmailNotConfirmedException).email, 'B@Example.com');
    });

    test('anything else is a general failure', () {
      expect(
        EmailAuthService.mapSignInError(
          AuthApiException('Database error', statusCode: '500'),
          email: 'a@b.com',
        ),
        isA<SignInFailedException>(),
      );
    });
  });

  group('EmailAuthService.signInWithEmail (real notifier)', () {
    test('a wrong password reaches the caller as WrongCredentials', () async {
      final w = _wired();
      when(
        () => w.goTrue.signInWithPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(_wrongPassword);

      await expectLater(
        w.container
            .read(emailAuthServiceProvider.notifier)
            .signInWithEmail(email: 'a@b.com', password: 'nope'),
        throwsA(isA<WrongCredentialsException>()),
      );
    });

    test('no network reaches the caller as NoConnection', () async {
      final w = _wired();
      when(
        () => w.goTrue.signInWithPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(AuthRetryableFetchException(message: 'offline'));

      await expectLater(
        w.container
            .read(emailAuthServiceProvider.notifier)
            .signInWithEmail(email: 'a@b.com', password: 'password1'),
        throwsA(isA<NoConnectionException>()),
      );
    });

    test('an unconfirmed address reaches the caller as EmailNotConfirmed, '
        'logged at info, not as an error (124-001)', () async {
      final w = _wired();
      when(
        () => w.goTrue.signInWithPassword(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenThrow(_notConfirmed);

      await expectLater(
        w.container
            .read(emailAuthServiceProvider.notifier)
            .signInWithEmail(email: 'b@example.com', password: 'password1'),
        throwsA(
          isA<EmailNotConfirmedException>().having(
            (e) => e.email,
            'email',
            'b@example.com',
          ),
        ),
      );
      verifyNever(
        () => w.logger.error(
          any(),
          context: any(named: 'context'),
          error: any(named: 'error'),
          data: any(named: 'data'),
          stackTrace: any(named: 'stackTrace'),
        ),
      );
    });
  });

  group('ResendRateLimitedException (seam: GoTrue\'s 429 message)', () {
    test('reads the wait from "after N seconds"', () {
      expect(
        ResendRateLimitedException.secondsFrom(
          'For security purposes, you can only request this after 37 seconds.',
        ),
        37,
      );
      expect(
        ResendRateLimitedException.secondsFrom('Too many requests'),
        isNull,
      );
    });

    test('matches by code, by status, or by message', () {
      expect(
        ResendRateLimitedException.matches(code: 'over_email_send_rate_limit'),
        isTrue,
      );
      expect(ResendRateLimitedException.matches(statusCode: '429'), isTrue);
      expect(
        ResendRateLimitedException.matches(
          message:
              'Password reset failed: you can only request this after '
              '12 seconds',
        ),
        isTrue,
      );
      expect(
        ResendRateLimitedException.matches(
          code: 'validation_failed',
          statusCode: '400',
          message: 'Invalid email',
        ),
        isFalse,
      );
    });

    test(
      'resendVerificationCode raises it with the wait GoTrue named',
      () async {
        final w = _wired();
        when(
          () => w.goTrue.resend(
            type: any(named: 'type'),
            email: any(named: 'email'),
          ),
        ).thenThrow(
          AuthApiException(
            'For security purposes, you can only request this after 37 seconds.',
            statusCode: '429',
            code: 'over_email_send_rate_limit',
          ),
        );

        await expectLater(
          w.container
              .read(emailAuthServiceProvider.notifier)
              .resendVerificationCode(email: 'a@b.com'),
          throwsA(
            isA<ResendRateLimitedException>().having(
              (e) => e.retryAfterSeconds,
              'retryAfterSeconds',
              37,
            ),
          ),
        );
      },
    );
  });
}
