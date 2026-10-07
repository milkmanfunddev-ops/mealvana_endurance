/// Verify your email through the real [EmailAuthService] notifier
/// (develop-2026-10 ticket 21: 01-002, 01-003, 01-005).
///
/// Seam: GoTrue's own answers, as gotrue throws them (403 `otp_expired`
/// "Token has expired or is invalid"; 429 `over_email_send_rate_limit`
/// "...after 47 seconds."; a socket failure), never the service's own types
/// fed back in. The container carries the real Riverpod net
/// ([SentryProviderObserver]) so what a notifier writes into its state is
/// judged the way the app judges it.
library;

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    hide AuthUser, AuthException;

import 'package:mealvana_endurance/features/auth/application/email_auth_service.dart';
import 'package:mealvana_endurance/features/auth/domain/auth_exceptions.dart';
import 'package:mealvana_endurance/shared/services/analytics/analytics_tracker.dart';
import 'package:mealvana_endurance/shared/services/app_external_deps.dart';
import 'package:mealvana_endurance/shared/services/report/report.dart';
import 'package:mealvana_endurance/shared/services/sentry/sentry_provider_observer.dart';

import '../../../helpers/fakes/recording_report.dart';
import '../../../helpers/widget_test_harness.dart';

class _MockUser extends Mock implements User {}

/// A [RecordingReport] with `SentryReport`'s identity rule: an error object
/// already captured is not captured again (`report.dart`, `_capture`). Which
/// capture comes first therefore decides which tags the one event carries.
class _DedupingReport extends RecordingReport {
  final _seen = Expando<bool>('captured');

  bool _firstTime(Object error) {
    if (_seen[error] == true) return false;
    _seen[error] = true;
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
}

/// GoTrue's one refusal for a wrong, superseded or stale code.
final _refused = AuthApiException(
  'Token has expired or is invalid',
  statusCode: '403',
  code: 'otp_expired',
);

({ProviderContainer container, MockGoTrueClient goTrue, _DedupingReport report})
_wired() {
  final goTrue = fakeGoTrueClient() as MockGoTrueClient;
  final analytics = MockAnalyticsTracker();
  when(
    () => analytics.track(any(), properties: any(named: 'properties')),
  ).thenAnswer((_) async {});
  final report = _DedupingReport();
  final prefs = MockSharedPreferences();
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
  // Auto-dispose: keep the notifier alive across the awaits.
  container.listen(emailAuthServiceProvider, (_, _) {});
  return (container: container, goTrue: goTrue, report: report);
}

void _verifyAnswers(MockGoTrueClient goTrue, Object error) {
  when(
    () => goTrue.verifyOTP(
      email: any(named: 'email'),
      token: any(named: 'token'),
      type: any(named: 'type'),
    ),
  ).thenThrow(error);
}

void _resendAnswers(MockGoTrueClient goTrue, Object error) {
  when(
    () => goTrue.resend(
      type: any(named: 'type'),
      email: any(named: 'email'),
    ),
  ).thenThrow(error);
}

Matcher _rejected(VerificationCodeRejection reason) => throwsA(
  isA<InvalidVerificationCodeException>().having(
    (e) => e.reason,
    'reason',
    reason,
  ),
);

void main() {
  setUpAll(() => registerFallbackValue(OtpType.signup));

  group('a refused code: wrong or expired by its age (01-002)', () {
    test('44 s after the send it is wrong', () async {
      final w = _wired();
      _verifyAnswers(w.goTrue, _refused);

      await expectLater(
        w.container
            .read(emailAuthServiceProvider.notifier)
            .verifyEmailOtp(
              email: 'a@b.com',
              token: '123456',
              codeSentAt: DateTime.now().subtract(const Duration(seconds: 44)),
            ),
        _rejected(VerificationCodeRejection.wrong),
      );
    });

    test('61 min after the send it is expired', () async {
      final w = _wired();
      _verifyAnswers(w.goTrue, _refused);

      await expectLater(
        w.container
            .read(emailAuthServiceProvider.notifier)
            .verifyEmailOtp(
              email: 'a@b.com',
              token: '123456',
              codeSentAt: DateTime.now().subtract(const Duration(minutes: 61)),
            ),
        _rejected(VerificationCodeRejection.expired),
      );
    });

    test('five digits are malformed and never reach GoTrue', () async {
      final w = _wired();

      await expectLater(
        w.container
            .read(emailAuthServiceProvider.notifier)
            .verifyEmailOtp(email: 'a@b.com', token: '12345'),
        _rejected(VerificationCodeRejection.malformed),
      );
      verifyNever(
        () => w.goTrue.verifyOTP(
          email: any(named: 'email'),
          token: any(named: 'token'),
          type: any(named: 'type'),
        ),
      );
    });
  });

  group('Resend sends or says why not (01-003)', () {
    test('a 429 is rate limited at the 47 s GoTrue named', () async {
      final w = _wired();
      _resendAnswers(
        w.goTrue,
        AuthApiException(
          'For security purposes, you can only request this after 47 '
          'seconds.',
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
            47,
          ),
        ),
      );
    });

    test('a SocketException is failed, typed, and does not escape', () async {
      final w = _wired();
      _resendAnswers(w.goTrue, const SocketException('Network is down'));

      await expectLater(
        w.container
            .read(emailAuthServiceProvider.notifier)
            .resendVerificationCode(email: 'a@b.com'),
        throwsA(isA<VerificationResendFailedException>()),
      );
      expect(w.report.faults, isEmpty);
      expect(
        w.report.notes.map((n) => n.message),
        contains('Verification code resend failed'),
      );
    });

    test(
      'a resend that went out is noted with its gap since the last send',
      () async {
        final w = _wired();
        when(
          () => w.goTrue.resend(
            type: any(named: 'type'),
            email: any(named: 'email'),
          ),
        ).thenAnswer((_) async => ResendResponse());

        await w.container
            .read(emailAuthServiceProvider.notifier)
            .resendVerificationCode(
              email: 'a@b.com',
              lastSentAt: DateTime.now().subtract(const Duration(seconds: 75)),
            );

        final note = w.report.notes.singleWhere(
          (n) => n.message == 'Verification code resent',
        );
        expect(note.area, 'auth');
        expect(note.data!['otp_type'], 'signup');
        expect(note.data!['seconds_since_last_send'], inInclusiveRange(75, 76));
      },
    );
  });

  group('expected outcomes are breadcrumbs, real failures one fault '
      '(01-005)', () {
    test('a plain signup that needs its code: no fault, no degraded, one '
        'auth.flow breadcrumb', () async {
      final w = _wired();
      final user = _MockUser();
      when(() => user.id).thenReturn('b2b2b2b2-0000-4000-8000-000000000002');
      when(
        () => w.goTrue.signUp(
          email: any(named: 'email'),
          password: any(named: 'password'),
        ),
      ).thenAnswer((_) async => AuthResponse(user: user));

      await expectLater(
        w.container
            .read(emailAuthServiceProvider.notifier)
            .signUpWithEmail(email: 'a@b.com', password: 'password1'),
        throwsA(isA<EmailVerificationRequiredException>()),
      );
      await Future<void>.delayed(Duration.zero);

      expect(w.report.faults, isEmpty);
      expect(w.report.degradeds, isEmpty);
      expect(w.report.authFlow, hasLength(1));
      expect(
        w.report.authFlow.single.data!['type'],
        'EmailVerificationRequiredException',
      );
    });

    test(
      'a wrong code: no fault, no degraded, one auth.flow breadcrumb',
      () async {
        final w = _wired();
        _verifyAnswers(w.goTrue, _refused);

        await expectLater(
          w.container
              .read(emailAuthServiceProvider.notifier)
              .verifyEmailOtp(
                email: 'a@b.com',
                token: '123456',
                codeSentAt: DateTime.now(),
              ),
          throwsA(isA<InvalidVerificationCodeException>()),
        );
        await Future<void>.delayed(Duration.zero);

        expect(w.report.faults, isEmpty);
        expect(w.report.degradeds, isEmpty);
        expect(w.report.authFlow, hasLength(1));
      },
    );

    test(
      'a GoTrue 500 on verify is exactly one fault, with area auth',
      () async {
        final w = _wired();
        _verifyAnswers(
          w.goTrue,
          AuthApiException(
            'Internal server error',
            statusCode: '500',
            code: 'unexpected_failure',
          ),
        );

        await expectLater(
          w.container
              .read(emailAuthServiceProvider.notifier)
              .verifyEmailOtp(
                email: 'a@b.com',
                token: '123456',
                codeSentAt: DateTime.now(),
              ),
          throwsA(isA<AuthApiException>()),
        );
        await Future<void>.delayed(Duration.zero);

        expect(w.report.faults, hasLength(1));
        expect(w.report.faults.single.area, 'auth');
        expect(w.report.authFlow, isEmpty);
      },
    );
  });
}
