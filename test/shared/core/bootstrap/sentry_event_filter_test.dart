// Unit tests for the shared Sentry `beforeSend` filter.
//
// Since 2026-10-05 (spec: .scratch/sentry/spec.md) expected failures are
// DOWNGRADED to warning and tagged `expected_failure`, not dropped; only
// test-runner leaks are dropped. The needles come from the 2026-07-01 audit
// plus the 2026-07-11 follow-up (MEALVANA-ENDURANCE-DEV-4W/5M/5B/5N/5Q) that
// closed gaps where a real device error string didn't match a needle.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import 'package:mealvana_endurance/shared/core/bootstrap/sentry_event_filter.dart';

/// The filter turned [event] into a tagged warning (an expected failure).
bool isDowngraded(SentryEvent event) {
  final out = filterSentryEvent(event, debugBuild: true);
  return out != null &&
      out.level == SentryLevel.warning &&
      (out.tags?.containsKey('expected_failure') ?? false);
}

void main() {
  group('filterSentryEvent', () {
    // --- Offline / DNS ---
    test('downgrades SocketException (failed host lookup)', () {
      final event = SentryEvent(
        throwable: const SocketException(
          'Failed host lookup: \'vlmtsdzpnjnavdgytcmi.supabase.co\'',
        ),
      );
      expect(isDowngraded(event), isTrue);
    });

    // --- Transient TLS / connection resets ---
    test('downgrades HandshakeException', () {
      final event = SentryEvent(
        throwable: Exception(
          'HandshakeException: Connection terminated during handshake',
        ),
      );
      expect(isDowngraded(event), isTrue);
    });

    test('downgrades TimeoutException', () {
      final event = SentryEvent(
        throwable: Exception(
          'TimeoutException after 0:00:30.000000: Future not completed',
        ),
      );
      expect(isDowngraded(event), isTrue);
    });

    // --- 2026-07-11 audit: DEV-4W ---
    // http.ClientException wraps a plain Future.timeout() as "Operation timed
    // out" — this text does NOT contain "TimeoutException", so it needed its
    // own needle.
    test('downgrades ClientException: Operation timed out (DEV-4W)', () {
      final event = SentryEvent(
        throwable: http.ClientException(
          'Operation timed out',
          Uri.parse(
            'https://vlmtsdzpnjnavdgytcmi.supabase.co/rest/v1/template_foods?select=id',
          ),
        ),
      );
      expect(isDowngraded(event), isTrue);
    });

    // --- 2026-07-11 audit: DEV-5M / DEV-5B ---
    // Socket torn down out from under an in-flight request when the app is
    // backgrounded/suspended (auth token refresh, edge-function calls).
    test('downgrades ClientException: Bad file descriptor (DEV-5M/5B)', () {
      final event = SentryEvent(
        throwable: http.ClientException(
          'Bad file descriptor',
          Uri.parse(
            'https://vlmtsdzpnjnavdgytcmi.supabase.co/auth/v1/token?grant_type=refresh_token',
          ),
        ),
      );
      expect(isDowngraded(event), isTrue);
    });

    // --- 2026-07-11 audit: DEV-5N ---
    // HttpException phrases a body-phase connection drop differently than the
    // header-phase "Connection closed before full header" needle.
    test(
      'downgrades HttpException: Connection closed while receiving data (DEV-5N)',
      () {
        final event = SentryEvent(
          throwable: const HttpException(
            'Connection closed while receiving data, uri = https://vlmtsdzpnjnavdgytcmi.supabase.co/storage/v1/object/public/recipe-images/foo.jpg',
          ),
        );
        expect(isDowngraded(event), isTrue);
      },
    );

    test(
      'still drops the original "Connection closed before full header" phrasing',
      () {
        final event = SentryEvent(
          throwable: Exception(
            'Connection closed before full header was received',
          ),
        );
        expect(isDowngraded(event), isTrue);
      },
    );

    // --- 2026-07-11 audit: DEV-5Q ---
    // A mistyped password is a user mistake, not an app bug.
    test('downgrades AuthApiException: Invalid login credentials (DEV-5Q)', () {
      final event = SentryEvent(
        throwable: Exception(
          'AuthApiException(message: Invalid login credentials, statusCode: 400, code: invalid_credentials)',
        ),
      );
      expect(isDowngraded(event), isTrue);
    });

    // --- User-cancelled sign-in ---
    test(
      'downgrades Google Sign-In cancellation (linkGoogleAccount phrasing)',
      () {
        final event = SentryEvent(
          throwable: Exception('Google Sign-In was cancelled'),
        );
        expect(isDowngraded(event), isTrue);
      },
    );

    test(
      'downgrades Google Sign-In cancellation (signInWithGoogle phrasing)',
      () {
        final event = SentryEvent(
          throwable: Exception('Google Sign-In cancelled'),
        );
        expect(isDowngraded(event), isTrue);
      },
    );

    test('downgrades SignInWithAppleAuthorizationException error 1000', () {
      final event = SentryEvent(
        exceptions: [
          SentryException(
            type: 'SignInWithAppleAuthorizationException',
            value:
                "SignInWithAppleAuthorizationException(AuthorizationErrorCode.unknown, The operation couldn't be completed. (com.apple.AuthenticationServices.AuthorizationError error 1000.))",
          ),
        ],
      );
      expect(isDowngraded(event), isTrue);
    });

    // --- Debug-only Flutter assertions / web DOM races / test-runner leakage ---
    test('downgrades ink splashes debug assertion', () {
      final event = SentryEvent(
        message: SentryMessage(
          "Debug mode: 'ink splashes may be invisible' assertion",
        ),
      );
      expect(isDowngraded(event), isTrue);
    });

    test('DROPS TestFailure leakage from Patrol runs', () {
      final event = SentryEvent(
        throwable: Exception(
          'TestFailure: Expected: exactly one matching candidate',
        ),
      );
      expect(filterSentryEvent(event, debugBuild: true), isNull);
    });

    test('tags the downgrade reason and a degraded severity', () {
      final event = SentryEvent(
        throwable: const SocketException('Failed host lookup'),
        level: SentryLevel.error,
      );
      final out = filterSentryEvent(event, debugBuild: true)!;
      expect(out.level, SentryLevel.warning);
      expect(out.tags, containsPair('expected_failure', 'offline'));
      expect(out.tags, containsPair('severity', 'degraded'));
    });

    test('a downgrade overrides a severity Report had set', () {
      final event = SentryEvent(
        throwable: const SocketException('Failed host lookup'),
        level: SentryLevel.error,
        tags: const {'severity': 'fault'},
      );
      final out = filterSentryEvent(event, debugBuild: true)!;
      expect(out.tags, containsPair('severity', 'degraded'));
    });

    test('downgrades info and debug events in release builds', () {
      expect(
        filterSentryEvent(
          SentryEvent(level: SentryLevel.info, message: SentryMessage('x')),
          debugBuild: false,
        ),
        isNull,
      );
      expect(
        filterSentryEvent(
          SentryEvent(level: SentryLevel.info, message: SentryMessage('x')),
          debugBuild: true,
        ),
        isNotNull,
      );
    });

    test('keeps MetricKit diagnostics at info level in release builds', () {
      final out = filterSentryEvent(
        SentryEvent(level: SentryLevel.info, tags: const {'metrickit': 'hang'}),
        debugBuild: false,
      );
      expect(out, isNotNull);
    });

    // --- Negative cases: real, actionable errors must NOT be filtered ---
    test(
      'does NOT downgrade a PostgrestException FK-constraint violation (23503)',
      () {
        final event = SentryEvent(
          throwable: const PostgrestException(
            message:
                'insert or update on table "logged_meals" violates foreign key constraint "logged_meals_user_id_fkey"',
            code: '23503',
            details: 'Key (user_id)=(...) is not present in table "users".',
          ),
        );
        expect(isDowngraded(event), isFalse);
      },
    );

    test(
      'does NOT downgrade an unrelated ClientException (e.g. 500 from an edge function)',
      () {
        final event = SentryEvent(
          throwable: http.ClientException(
            'Internal Server Error',
            Uri.parse(
              'https://vlmtsdzpnjnavdgytcmi.supabase.co/functions/v1/generate-nutrition-plan-v3',
            ),
          ),
        );
        expect(isDowngraded(event), isFalse);
      },
    );

    test('does NOT downgrade a generic unrelated exception', () {
      final event = SentryEvent(
        throwable: StateError(
          'Nutrition plan solver produced a negative carb target',
        ),
      );
      expect(isDowngraded(event), isFalse);
    });

    // --- Ticket 19: SDK-reported gateway failures, per endpoint ---
    group('SDK-reported HTTP failures (ticket 19)', () {
      /// The event `FailedRequestClient` builds, after the SDK's exception
      /// factory has filled `exceptions` (which happens before beforeSend).
      /// URLs and statuses are copied from the real Sentry events.
      SentryEvent sdkHttpFailure(String url, int status) {
        final event = SentryEvent(
          request: SentryRequest(url: url, method: 'POST'),
          exceptions: [
            SentryException(
              type: 'SentryHttpClientError',
              value: 'Exception: HTTP Client Error with status code: $status',
              mechanism: Mechanism(type: 'SentryHttpClient'),
            ),
          ],
        );
        event.contexts.response = SentryResponse(statusCode: status);
        return event;
      }

      String? tag(SentryEvent event, String key) =>
          filterSentryEvent(event, debugBuild: true)!.tags?[key];

      test('garmin-backfill 502 is upstream_unavailable, named (AA/AB)', () {
        final event = sdkHttpFailure(
          'https://wvmvsodrvbkxfydabqed.supabase.co/functions/v1/garmin-backfill',
          502,
        );
        expect(isDowngraded(event), isTrue);
        expect(tag(event, 'expected_failure'), 'upstream_unavailable');
        expect(tag(event, 'http_endpoint'), 'garmin-backfill');
      });

      test('kroger 502 is upstream_unavailable (DEV-8H)', () {
        final event = sdkHttpFailure(
          'https://vlmtsdzpnjnavdgytcmi.supabase.co/functions/v1/kroger',
          502,
        );
        expect(tag(event, 'expected_failure'), 'upstream_unavailable');
      });

      test('a 504 from PostgREST or GoTrue is gateway_timeout (B5/C1/BM)', () {
        for (final url in [
          'https://wvmvsodrvbkxfydabqed.supabase.co/rest/v1/users',
          'https://wvmvsodrvbkxfydabqed.supabase.co/auth/v1/token',
        ]) {
          final event = sdkHttpFailure(url, 504);
          expect(
            tag(event, 'expected_failure'),
            'gateway_timeout',
            reason: url,
          );
        }
      });

      test('a 504 from an edge function stays a Fault (our handler ran past '
          'the platform limit)', () {
        final event = sdkHttpFailure(
          'https://wvmvsodrvbkxfydabqed.supabase.co/functions/v1/search-catalog',
          504,
        );
        expect(isDowngraded(event), isFalse);
      });

      test('reads the status from the message when no response context', () {
        final event = SentryEvent(
          request: SentryRequest(
            url:
                'https://wvmvsodrvbkxfydabqed.supabase.co/rest/v1/template_foods',
          ),
          exceptions: [
            SentryException(
              type: 'SentryHttpClientError',
              value: 'Exception: HTTP Client Error with status code: 504',
            ),
          ],
        );
        expect(isDowngraded(event), isTrue);
      });

      test('does NOT downgrade a 500 from an edge function', () {
        final event = sdkHttpFailure(
          'https://wvmvsodrvbkxfydabqed.supabase.co/functions/v1/garmin-backfill',
          500,
        );
        expect(isDowngraded(event), isFalse);
      });

      test('does NOT downgrade a 502 from a function with no upstream rule', () {
        final event = sdkHttpFailure(
          'https://wvmvsodrvbkxfydabqed.supabase.co/functions/v1/generate-nutrition-plan-v3',
          502,
        );
        expect(isDowngraded(event), isFalse);
      });

      test('does NOT downgrade a 504 from a non-Supabase host', () {
        final event = sdkHttpFailure('https://api.example.org/v1/thing', 504);
        expect(isDowngraded(event), isFalse);
      });

      test('still downgrades weather failures as handled_fallback', () {
        final event = sdkHttpFailure(
          'https://wvmvsodrvbkxfydabqed.supabase.co/functions/v1/get-weather-forecast',
          546,
        );
        expect(tag(event, 'expected_failure'), 'handled_fallback');
      });
    });

    test(
      'returns false for an event with no throwable, message, or exceptions',
      () {
        final event = SentryEvent();
        expect(isDowngraded(event), isFalse);
      },
    );
  });
}
