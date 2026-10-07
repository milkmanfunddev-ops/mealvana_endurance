/// Why a rejected 6-digit email code was rejected (Finding 32-001, then
/// develop-2026-10 ticket 21, 01-002).
///
/// GoTrue answers a mistyped code and a stale one alike: 403, code
/// `otp_expired`, "Token has expired or is invalid". The code's age decides:
/// under [signupCodeLifetime] it is wrong, at or past it expired. Lee's
/// ruling: each case gets its own message. The service seam is in
/// `email_auth_service_verify_test.dart`.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    hide AuthUser, AuthException;

import 'package:mealvana_endurance/features/auth/domain/auth_exceptions.dart';
import 'package:mealvana_endurance/features/auth/domain/signup_code.dart';

/// GoTrue's answer to any wrong, superseded or stale code.
final _goTrueRejection = AuthApiException(
  'Token has expired or is invalid',
  statusCode: '403',
  code: 'otp_expired',
);

VerificationCodeRejection _reasonAt(Duration? age, {AuthApiException? e}) {
  final answer = e ?? _goTrueRejection;
  return InvalidVerificationCodeException.fromGoTrue(
    code: answer.code,
    statusCode: answer.statusCode,
    message: answer.message,
    codeAge: age,
  ).reason;
}

void main() {
  group('InvalidVerificationCodeException.fromGoTrue', () {
    test('a refusal of a young code is wrong, never expired', () {
      expect(
        _reasonAt(const Duration(seconds: 44)),
        VerificationCodeRejection.wrong,
      );
      expect(
        _reasonAt(signupCodeLifetime - const Duration(seconds: 1)),
        VerificationCodeRejection.wrong,
      );
    });

    test('the same refusal at or past the lifetime is expired', () {
      expect(_reasonAt(signupCodeLifetime), VerificationCodeRejection.expired);
      expect(
        _reasonAt(const Duration(minutes: 61)),
        VerificationCodeRejection.expired,
      );
    });

    test('an unknown age reads as wrong', () {
      expect(_reasonAt(null), VerificationCodeRejection.wrong);
    });

    test('the answer without a code (older GoTrue) reads the same', () {
      final e = InvalidVerificationCodeException.fromGoTrue(
        statusCode: '403',
        message: 'Token has expired or is invalid',
        codeAge: const Duration(hours: 2),
      );
      expect(e.reason, VerificationCodeRejection.expired);
    });

    test('a 429 is too many tries, whatever the age', () {
      final byCode = InvalidVerificationCodeException.fromGoTrue(
        code: 'over_request_rate_limit',
        statusCode: '429',
        message: 'Request rate limit reached',
        codeAge: const Duration(hours: 2),
      );
      final byStatus = InvalidVerificationCodeException.fromGoTrue(
        statusCode: '429',
        message: 'Too many requests',
      );
      expect(byCode.reason, VerificationCodeRejection.tooManyTries);
      expect(byStatus.reason, VerificationCodeRejection.tooManyTries);
    });

    test('any other refusal is wrong', () {
      final e = InvalidVerificationCodeException.fromGoTrue(
        code: 'validation_failed',
        statusCode: '400',
        message: 'Invalid token',
        codeAge: const Duration(hours: 2),
      );
      expect(e.reason, VerificationCodeRejection.wrong);
    });
  });
}
