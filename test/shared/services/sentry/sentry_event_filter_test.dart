// Unit tests for the shared Sentry `beforeSend` noise filter.
//
// Covers the 2026-07-01 audit needles plus the 2026-07-11 follow-up audit
// (MEALVANA-ENDURANCE-DEV-4W/5M/5B/5N/5Q) that closed gaps where a real
// device error string didn't exactly match an existing needle.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'package:mealvana_endurance/shared/services/sentry/sentry_event_filter.dart';

void main() {
  group('isSentryNoise', () {
    // --- Offline / DNS ---
    test('drops SocketException (failed host lookup)', () {
      final event = SentryEvent(
        throwable: const SocketException(
          'Failed host lookup: \'vlmtsdzpnjnavdgytcmi.supabase.co\'',
        ),
      );
      expect(isSentryNoise(event), isTrue);
    });

    // --- Transient TLS / connection resets ---
    test('drops HandshakeException', () {
      final event = SentryEvent(
        throwable: Exception('HandshakeException: Connection terminated during handshake'),
      );
      expect(isSentryNoise(event), isTrue);
    });

    test('drops TimeoutException', () {
      final event = SentryEvent(
        throwable: Exception('TimeoutException after 0:00:30.000000: Future not completed'),
      );
      expect(isSentryNoise(event), isTrue);
    });

    // --- 2026-07-11 audit: DEV-4W ---
    // http.ClientException wraps a plain Future.timeout() as "Operation timed
    // out" — this text does NOT contain "TimeoutException", so it needed its
    // own needle.
    test('drops ClientException: Operation timed out (DEV-4W)', () {
      final event = SentryEvent(
        throwable: http.ClientException(
          'Operation timed out',
          Uri.parse(
            'https://vlmtsdzpnjnavdgytcmi.supabase.co/rest/v1/template_foods?select=id',
          ),
        ),
      );
      expect(isSentryNoise(event), isTrue);
    });

    // --- 2026-07-11 audit: DEV-5M / DEV-5B ---
    // Socket torn down out from under an in-flight request when the app is
    // backgrounded/suspended (auth token refresh, edge-function calls).
    test('drops ClientException: Bad file descriptor (DEV-5M/5B)', () {
      final event = SentryEvent(
        throwable: http.ClientException(
          'Bad file descriptor',
          Uri.parse('https://vlmtsdzpnjnavdgytcmi.supabase.co/auth/v1/token?grant_type=refresh_token'),
        ),
      );
      expect(isSentryNoise(event), isTrue);
    });

    // --- 2026-07-11 audit: DEV-5N ---
    // HttpException phrases a body-phase connection drop differently than the
    // header-phase "Connection closed before full header" needle.
    test('drops HttpException: Connection closed while receiving data (DEV-5N)', () {
      final event = SentryEvent(
        throwable: const HttpException(
          'Connection closed while receiving data, uri = https://vlmtsdzpnjnavdgytcmi.supabase.co/storage/v1/object/public/recipe-images/foo.jpg',
        ),
      );
      expect(isSentryNoise(event), isTrue);
    });

    test('still drops the original "Connection closed before full header" phrasing', () {
      final event = SentryEvent(
        throwable: Exception('Connection closed before full header was received'),
      );
      expect(isSentryNoise(event), isTrue);
    });

    // --- 2026-07-11 audit: DEV-5Q ---
    // A mistyped password is a user mistake, not an app bug.
    test('drops AuthApiException: Invalid login credentials (DEV-5Q)', () {
      final event = SentryEvent(
        throwable: Exception(
          'AuthApiException(message: Invalid login credentials, statusCode: 400, code: invalid_credentials)',
        ),
      );
      expect(isSentryNoise(event), isTrue);
    });

    // --- User-cancelled sign-in ---
    test('drops Google Sign-In cancellation (linkGoogleAccount phrasing)', () {
      final event = SentryEvent(
        throwable: Exception('Google Sign-In was cancelled'),
      );
      expect(isSentryNoise(event), isTrue);
    });

    test('drops Google Sign-In cancellation (signInWithGoogle phrasing)', () {
      final event = SentryEvent(
        throwable: Exception('Google Sign-In cancelled'),
      );
      expect(isSentryNoise(event), isTrue);
    });

    test('drops SignInWithAppleAuthorizationException error 1000', () {
      final event = SentryEvent(
        exceptions: [
          SentryException(
            type: 'SignInWithAppleAuthorizationException',
            value:
                "SignInWithAppleAuthorizationException(AuthorizationErrorCode.unknown, The operation couldn't be completed. (com.apple.AuthenticationServices.AuthorizationError error 1000.))",
          ),
        ],
      );
      expect(isSentryNoise(event), isTrue);
    });

    // --- Debug-only Flutter assertions / web DOM races / test-runner leakage ---
    test('drops ink splashes debug assertion', () {
      final event = SentryEvent(
        message: SentryMessage("Debug mode: 'ink splashes may be invisible' assertion"),
      );
      expect(isSentryNoise(event), isTrue);
    });

    test('drops TestFailure leakage from Patrol runs', () {
      final event = SentryEvent(
        throwable: Exception('TestFailure: Expected: exactly one matching candidate'),
      );
      expect(isSentryNoise(event), isTrue);
    });

    // --- Negative cases: real, actionable errors must NOT be filtered ---
    test('does NOT drop a PostgrestException FK-constraint violation (23503)', () {
      final event = SentryEvent(
        throwable: const PostgrestException(
          message:
              'insert or update on table "logged_meals" violates foreign key constraint "logged_meals_user_id_fkey"',
          code: '23503',
          details: 'Key (user_id)=(...) is not present in table "users".',
        ),
      );
      expect(isSentryNoise(event), isFalse);
    });

    test('does NOT drop an unrelated ClientException (e.g. 500 from an edge function)', () {
      final event = SentryEvent(
        throwable: http.ClientException(
          'Internal Server Error',
          Uri.parse('https://vlmtsdzpnjnavdgytcmi.supabase.co/functions/v1/generate-nutrition-plan-v3'),
        ),
      );
      expect(isSentryNoise(event), isFalse);
    });

    test('does NOT drop a generic unrelated exception', () {
      final event = SentryEvent(
        throwable: StateError('Nutrition plan solver produced a negative carb target'),
      );
      expect(isSentryNoise(event), isFalse);
    });

    test('returns false for an event with no throwable, message, or exceptions', () {
      final event = SentryEvent();
      expect(isSentryNoise(event), isFalse);
    });
  });
}
