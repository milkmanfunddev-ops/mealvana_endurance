/// The code screens wait as long as the server does (testing-wave 121-001,
/// 124-004): Resend counts down 60 s (the server allows one email per address
/// per 60 s), and a 429 counts down the wait GoTrue named instead of saying
/// the resend failed. Verify your email always hints that the address may be
/// an account (124-002), and after a Resend a refused code points at the
/// newest email (121-002).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/auth/application/email_auth_service.dart';
import 'package:mealvana_endurance/features/auth/domain/auth_exceptions.dart';
import 'package:mealvana_endurance/features/auth/presentation/providers/password_recovery_controller.dart';
import 'package:mealvana_endurance/features/auth/presentation/screens/verify_email_screen.dart';
import 'package:mealvana_endurance/features/auth/presentation/screens/verify_reset_code_screen.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../helpers/widget_test_harness.dart';
import '../../meal_planning/presentation/helpers/test_content.dart';

/// What the fake service saw and how it answers. Kept outside the notifier:
/// the auto-dispose provider is re-created between reads, and Riverpod
/// refuses to reuse one notifier instance.
class _AuthSpy {
  Object? resendError;
  int resends = 0;
  final discarded = <String>[];
}

/// Resend answers with the spy's [_AuthSpy.resendError] (or succeeds); every
/// code is refused with GoTrue's one answer.
class _FakeEmailAuthService extends EmailAuthService {
  _FakeEmailAuthService(this.spy);

  final _AuthSpy spy;

  @override
  FutureOr<void> build() {}

  @override
  Future<void> resendVerificationCode({
    required String email,
    OtpType type = OtpType.signup,
  }) async {
    spy.resends++;
    if (spy.resendError != null) throw spy.resendError!;
  }

  @override
  Future<void> verifyEmailOtp({
    required String email,
    required String token,
    OtpType type = OtpType.signup,
    String? pendingPassword,
  }) async {
    throw InvalidVerificationCodeException.fromGoTrue(
      code: 'otp_expired',
      statusCode: '403',
      message: 'Token has expired or is invalid',
    );
  }

  @override
  Future<void> discardSignup({
    required String userId,
    required String email,
  }) async {
    spy.discarded.add(userId);
  }
}

class _RecoverySpy {
  bool sendSucceeds = true;
  int? wait;
  int sends = 0;
}

class _FakeRecovery extends PasswordRecoveryController {
  _FakeRecovery(this.spy);

  final _RecoverySpy spy;

  @override
  FutureOr<void> build() {}

  @override
  Future<bool> sendResetCode(String email) async {
    spy.sends++;
    lastRetryAfterSeconds = spy.sendSucceeds ? null : spy.wait;
    return spy.sendSucceeds;
  }
}

final _content = loadDefaultContent();

Future<void> _pump(WidgetTester tester, Widget screen, List overrides) =>
    smokeScreen(
      tester,
      screen,
      overrides: [
        contentServiceProvider.overrideWith(testContentService),
        ...overrides.cast(),
      ],
    );

void main() {
  group('Verify your email', () {
    final resend = find.byKey(const ValueKey('auth.verify_resend'));

    testWidgets('Resend counts down 60 s, as the server does', (tester) async {
      final auth = _AuthSpy();
      await _pump(tester, const VerifyEmailScreen(email: 'a@b.com'), [
        emailAuthServiceProvider.overrideWith(
          () => _FakeEmailAuthService(auth),
        ),
      ]);

      expect(find.text('Resend code in 60s'), findsOneWidget);
      expect(tester.widget<TextButton>(resend).onPressed, isNull);

      await tester.pump(const Duration(seconds: 30));
      expect(find.text('Resend code in 30s'), findsOneWidget);
      expect(tester.widget<TextButton>(resend).onPressed, isNull);

      await tester.pump(const Duration(seconds: 30));
      expect(find.text('Resend code'), findsOneWidget);
      expect(tester.widget<TextButton>(resend).onPressed, isNotNull);
    });

    testWidgets('a 429 counts down the N GoTrue named, never a failure line', (
      tester,
    ) async {
      final auth = _AuthSpy()
        ..resendError = const ResendRateLimitedException(37);
      await _pump(tester, const VerifyEmailScreen(email: 'a@b.com'), [
        emailAuthServiceProvider.overrideWith(
          () => _FakeEmailAuthService(auth),
        ),
      ]);
      await tester.pump(const Duration(seconds: 60));

      await tester.tap(resend);
      await tester.pump();

      expect(auth.resends, 1);
      expect(find.text('Resend code in 37s'), findsOneWidget);
      expect(find.textContaining('Could not resend'), findsNothing);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('after a Resend, a refused code points at the newest email', (
      tester,
    ) async {
      final auth = _AuthSpy();
      await _pump(tester, const VerifyEmailScreen(email: 'a@b.com'), [
        emailAuthServiceProvider.overrideWith(
          () => _FakeEmailAuthService(auth),
        ),
      ]);

      // Before any Resend: GoTrue's answer as it stands (32-001).
      await tester.enterText(find.byType(TextField), '111111');
      await tester.pumpAndSettle();
      expect(
        find.text(InvalidVerificationCodeException.wrongOrExpiredText),
        findsOneWidget,
      );

      await tester.pump(const Duration(seconds: 60));
      await tester.ensureVisible(resend);
      await tester.tap(resend);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(auth.resends, 1, reason: 'the Resend went out');

      await tester.enterText(find.byType(TextField), '222222');
      await tester.pumpAndSettle();
      expect(
        find.text(_content['auth.verify_email.code_superseded']!),
        findsOneWidget,
      );
      expect(find.textContaining('tap Resend'), findsNothing);
    });

    testWidgets('always hints the address may be an account, with Log in', (
      tester,
    ) async {
      await _pump(tester, const VerifyEmailScreen(email: 'a@b.com'), [
        emailAuthServiceProvider.overrideWith(
          () => _FakeEmailAuthService(_AuthSpy()),
        ),
      ]);

      expect(
        find.text(_content['auth.verify_email.maybe_account_hint']!),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('auth.verify_log_in')), findsOneWidget);
      // Never a verdict.
      expect(find.textContaining('already exists'), findsNothing);
    });

    testWidgets('Use a different email on a fresh signup discards it', (
      tester,
    ) async {
      final auth = _AuthSpy();
      await _pump(
        tester,
        const VerifyEmailScreen(
          email: 'a@b.com',
          pendingUserId: 'a1a1a1a1-0000-4000-8000-000000000001',
        ),
        [
          emailAuthServiceProvider.overrideWith(
            () => _FakeEmailAuthService(auth),
          ),
        ],
      );

      await tester.tap(find.byKey(const ValueKey('auth.verify_change_email')));
      await tester.pump();

      expect(auth.discarded, ['a1a1a1a1-0000-4000-8000-000000000001']);
    });

    testWidgets('an upgrade (no pending user) discards nothing', (
      tester,
    ) async {
      final auth = _AuthSpy();
      await _pump(
        tester,
        const VerifyEmailScreen(
          email: 'a@b.com',
          otpType: OtpType.emailChange,
          pendingPassword: 'password1',
        ),
        [
          emailAuthServiceProvider.overrideWith(
            () => _FakeEmailAuthService(auth),
          ),
        ],
      );

      await tester.tap(find.byKey(const ValueKey('auth.verify_change_email')));
      await tester.pump();

      expect(auth.discarded, isEmpty);
    });
  });

  group('Enter Reset Code', () {
    final resend = find.byKey(const ValueKey('auth.reset_resend'));

    testWidgets('Resend counts down 60 s from the code just sent', (
      tester,
    ) async {
      final recovery = _RecoverySpy();
      await _pump(tester, const VerifyResetCodeScreen(email: 'a@b.com'), [
        passwordRecoveryControllerProvider.overrideWith(
          () => _FakeRecovery(recovery),
        ),
      ]);

      expect(find.text('Resend code in 60s'), findsOneWidget);
      await tester.tap(resend);
      await tester.pump();
      expect(recovery.sends, 0, reason: 'disabled while counting down');

      await tester.pump(const Duration(seconds: 60));
      expect(find.textContaining('Resend'), findsOneWidget);
      expect(find.text('Resend code in 0s'), findsNothing);

      await tester.tap(resend);
      await tester.pump();
      expect(recovery.sends, 1);
      // A new code went out: the countdown starts again.
      expect(find.text('Resend code in 60s'), findsOneWidget);
    });

    testWidgets('a 429 counts down its N and shows no failure', (tester) async {
      final recovery = _RecoverySpy()
        ..sendSucceeds = false
        ..wait = 37;
      await _pump(tester, const VerifyResetCodeScreen(email: 'a@b.com'), [
        passwordRecoveryControllerProvider.overrideWith(
          () => _FakeRecovery(recovery),
        ),
      ]);
      await tester.pump(const Duration(seconds: 60));

      await tester.tap(resend);
      await tester.pump();

      expect(find.text('Resend code in 37s'), findsOneWidget);
      expect(find.textContaining('Failed to resend'), findsNothing);
    });

    testWidgets('another failure still says so', (tester) async {
      final recovery = _RecoverySpy()..sendSucceeds = false;
      await _pump(tester, const VerifyResetCodeScreen(email: 'a@b.com'), [
        passwordRecoveryControllerProvider.overrideWith(
          () => _FakeRecovery(recovery),
        ),
      ]);
      await tester.pump(const Duration(seconds: 60));

      await tester.tap(resend);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text(_content['auth.verify_code.resend_failed']!),
        findsOneWidget,
      );
    });
  });
}
