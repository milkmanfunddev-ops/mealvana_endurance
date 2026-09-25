/// What a rejected 6-digit email code says (Finding 32-001).
///
/// GoTrue answers a mistyped code and a stale one alike: 403, code
/// `otp_expired`, "Token has expired or is invalid". The app cannot tell
/// them apart from the answer, so a rejected code must never read as
/// "expired" alone: that sends someone who mistyped to Resend instead of
/// back to the digits.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    hide AuthUser, AuthException;

import 'package:mealvana_endurance/features/auth/application/email_auth_service.dart';
import 'package:mealvana_endurance/features/auth/domain/auth_exceptions.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';

import '../../../helpers/widget_test_harness.dart';

class _MockGoTrue extends Mock implements GoTrueClient {}

class _MockSupabase extends Mock implements SupabaseClient {}

/// GoTrue's answer to any wrong, superseded or stale code.
final _goTrueRejection = AuthApiException(
  'Token has expired or is invalid',
  statusCode: '403',
  code: 'otp_expired',
);

void main() {
  group('InvalidVerificationCodeException.fromGoTrue', () {
    test('a rejected code reads as wrong first, never as expired alone', () {
      final e = InvalidVerificationCodeException.fromGoTrue(
        code: _goTrueRejection.code,
        statusCode: _goTrueRejection.statusCode,
        message: _goTrueRejection.message,
      );
      expect(e.message, InvalidVerificationCodeException.wrongOrExpiredText);
      expect(e.message, startsWith('That code is wrong'));
      expect(
        e.message,
        isNot('That code has expired. Tap resend for a new one.'),
      );
    });

    test('the same answer without a code (older GoTrue) reads the same', () {
      final e = InvalidVerificationCodeException.fromGoTrue(
        statusCode: '403',
        message: 'Token has expired or is invalid',
      );
      expect(e.message, InvalidVerificationCodeException.wrongOrExpiredText);
    });

    test('too many tries says wait, not wrong', () {
      final byCode = InvalidVerificationCodeException.fromGoTrue(
        code: 'over_request_rate_limit',
        statusCode: '429',
        message: 'Request rate limit reached',
      );
      final byStatus = InvalidVerificationCodeException.fromGoTrue(
        statusCode: '429',
        message: 'Too many requests',
      );
      expect(byCode.message, InvalidVerificationCodeException.tooManyTriesText);
      expect(
        byStatus.message,
        InvalidVerificationCodeException.tooManyTriesText,
      );
    });

    test('any other refusal says the code is not right', () {
      final e = InvalidVerificationCodeException.fromGoTrue(
        code: 'validation_failed',
        statusCode: '400',
        message: 'Invalid token',
      );
      expect(e.message, InvalidVerificationCodeException.notRightText);
    });
  });

  group('EmailAuthService.verifyEmailOtp', () {
    setUpAll(() => registerFallbackValue(OtpType.signup));

    test('a code GoTrue rejects throws the wrong-or-expired text', () async {
      final auth = _MockGoTrue();
      when(() => auth.currentUser).thenReturn(null);
      when(
        () => auth.verifyOTP(
          email: any(named: 'email'),
          token: any(named: 'token'),
          type: any(named: 'type'),
        ),
      ).thenThrow(_goTrueRejection);
      final client = _MockSupabase();
      when(() => client.auth).thenReturn(auth);

      final analytics = MockAnalyticsTracker();
      when(
        () => analytics.track(any(), properties: any(named: 'properties')),
      ).thenAnswer((_) async {});
      final deps = AppExternalDeps(
        analytics: analytics,
        supabaseClient: client,
        sentry: MockSentryReporter(),
        logger: MockAppLogger(),
        sharedPreferences: MockSharedPreferences(),
      );
      final container = ProviderContainer(
        overrides: [
          appExternalDepsProvider.overrideWithValue(deps),
          analyticsTrackerProvider.overrideWithValue(analytics),
        ],
      );
      addTearDown(container.dispose);
      final sub = container.listen(emailAuthServiceProvider, (_, __) {});
      addTearDown(sub.close);

      await expectLater(
        container
            .read(emailAuthServiceProvider.notifier)
            .verifyEmailOtp(email: 'a@b.com', token: '123456'),
        throwsA(
          isA<InvalidVerificationCodeException>().having(
            (e) => e.message,
            'message',
            InvalidVerificationCodeException.wrongOrExpiredText,
          ),
        ),
      );
    });
  });
}
