// Ticket 20 (auth group): the allow-list entries added 2026-10-06, each fed
// the exception the producer actually throws, built the way the producer
// builds it (gotrue 2.16 `GotrueFetch._handleError`, package:http, the
// google_sign_in and purchases_flutter platform channels). Strings are the
// ones Sentry recorded on the named issues.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show AuthApiException, AuthRetryableFetchException;

import 'package:mealvana_endurance/features/auth/domain/auth_exceptions.dart';
import 'package:mealvana_endurance/shared/core/bootstrap/sentry_event_filter.dart';
import 'package:mealvana_endurance/shared/services/report/expected_failures.dart';

ExpectedFailure? classify(Object error) =>
    classifyExpectedFailure(describeThrowable(error));

final _refreshUri = Uri.parse(
  'https://wvmvsodrvbkxfydabqed.supabase.co/auth/v1/token?grant_type=refresh_token',
);

void main() {
  group('connection aborts are Degraded (connection_reset)', () {
    test('ClientException: Software caused connection abort (CW)', () {
      // CW arrived through the SDK's HTTP client, not Report.
      final error = http.ClientException(
        'Software caused connection abort',
        _refreshUri,
      );
      expect(classify(error), ExpectedFailure.connectionReset);

      final out = filterSentryEvent(
        SentryEvent(throwable: error),
        debugBuild: true,
      );
      expect(out?.level, SentryLevel.warning);
      expect(out?.tags?['expected_failure'], 'connection_reset');
    });

    test('AuthRetryableFetchException wrapping the abort (CX)', () {
      // gotrue wraps any non-Response error as its toString().
      final error = AuthRetryableFetchException(
        message: http.ClientException(
          'Software caused connection abort',
          _refreshUri,
        ).toString(),
      );
      expect(classify(error), ExpectedFailure.connectionReset);
    });

    test('AuthRetryableFetchException wrapping a reset by peer (DEV-5)', () {
      final error = AuthRetryableFetchException(
        message: http.ClientException(
          'Connection reset by peer',
          _refreshUri,
        ).toString(),
      );
      expect(classify(error), ExpectedFailure.connectionReset);
    });
  });

  group('google_sign_in on Android', () {
    PlatformException signInFailed(String detail) =>
        PlatformException(code: 'sign_in_failed', message: detail);

    test('status 8 (INTERNAL_ERROR) is a transient Play services failure, '
        'obfuscated or not (CF)', () {
      expect(
        classify(signInFailed('K3.a: 8: ')),
        ExpectedFailure.playServicesTransient,
      );
      expect(
        classify(
          signInFailed('com.google.android.gms.common.api.ApiException: 8: '),
        ),
        ExpectedFailure.playServicesTransient,
      );
    });

    test('status 7 (NETWORK_ERROR) is offline', () {
      expect(classify(signInFailed('K3.a: 7: ')), ExpectedFailure.offline);
    });

    test('status 10 (DEVELOPER_ERROR: SHA-1 / OAuth client mismatch) and '
        '12500 stay Faults', () {
      expect(classify(signInFailed('K3.a: 10: ')), isNull);
      expect(classify(signInFailed('K3.a: 12500: ')), isNull);
    });
  });

  test('RevenueCat code 10 network error is store_network '
      '(DEV-8M, 9J, 9S, 9T, 9X)', () {
    final error = PlatformException(
      code: '10',
      message: 'A network error has occurred. Could not connect to the server.',
      details: <String, Object?>{
        'underlyingErrorMessage': 'Could not connect to the server.',
        'readableErrorCode': 'NETWORK_ERROR',
        'code': 10,
        'readable_error_code': 'NETWORK_ERROR',
      },
    );
    expect(classify(error), ExpectedFailure.storeNetwork);
  });

  group('auth control-flow signals and user input', () {
    test('OAuthAccountNotFoundException is account_not_found (CE, CQ, CZ)', () {
      expect(
        classify(const OAuthAccountNotFoundException(provider: 'google')),
        ExpectedFailure.accountNotFound,
      );
      expect(
        classify(const OAuthAccountNotFoundException(provider: 'apple')),
        ExpectedFailure.accountNotFound,
      );
    });

    test('EmailVerificationRequiredException is verification_pending '
        '(DEV-8R)', () {
      expect(
        classify(const EmailVerificationRequiredException()),
        ExpectedFailure.verificationPending,
      );
    });

    test('login before verifying is verification_pending (DEV-9N)', () {
      final error = AuthApiException(
        'Email not confirmed',
        statusCode: '400',
        code: 'email_not_confirmed',
      );
      expect(classify(error), ExpectedFailure.verificationPending);
    });

    test('a wrong or expired code is invalid_credentials (DEV-95, DEV-9P)', () {
      expect(
        classify(
          const InvalidVerificationCodeException(
            'That code is wrong or has expired. Check the digits, or tap '
            'Resend for a new one.',
          ),
        ),
        ExpectedFailure.invalidCredentials,
      );
      // SupabaseAuthService wraps the GoTrue error into its own message.
      final otp = AuthApiException(
        'Token has expired or is invalid',
        statusCode: '403',
        code: 'otp_expired',
      );
      expect(
        classifyExpectedFailure('AuthException Code verification failed: $otp'),
        ExpectedFailure.invalidCredentials,
      );
    });

    test('an existing account is account_exists (DEV-8D)', () {
      expect(
        classify(
          AccountAlreadyExistsException(
            'This Google account is already linked to another account',
          ),
        ),
        ExpectedFailure.accountExists,
      );
      expect(
        classify(
          AuthApiException(
            'User already registered',
            statusCode: '422',
            code: 'user_already_exists',
          ),
        ),
        ExpectedFailure.accountExists,
      );
    });

    test('a resend inside the cooldown is rate_limited (DEV-9Q)', () {
      final error = AuthApiException(
        'For security purposes, you can only request this after 37 seconds.',
        statusCode: '429',
        code: 'over_email_send_rate_limit',
      );
      expect(
        classifyExpectedFailure('AuthException Password reset failed: $error'),
        ExpectedFailure.rateLimited,
      );
    });
  });

  group('real auth failures stay Faults', () {
    test('Invalid API key (CH) is a misconfigured build, not noise', () {
      expect(
        classify(AuthApiException('Invalid API key', statusCode: '401')),
        isNull,
      );
    });

    test('GoTrue 500 unexpected_failure (DEV-8P, DEV-8W) stays a Fault', () {
      expect(
        classify(
          AuthRetryableFetchException(
            message:
                '{"code":"unexpected_failure","message":"Error sending confirmation email"}',
            statusCode: '500',
          ),
        ),
        isNull,
      );
    });
  });
}
