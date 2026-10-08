/// Verify your email's lines and Resend (develop-2026-10 ticket 21: 01-002,
/// 01-003). A wrong code and an expired one each say so, from the content
/// system; Resend waits as long as the server does, counts down a 429's N,
/// says when it failed, and a code that went out restarts the code's age.
/// A resumed code (ticket 42) counts Resend down from when it was sent.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/auth/application/email_auth_service.dart';
import 'package:mealvana_endurance/features/auth/domain/auth_exceptions.dart';
import 'package:mealvana_endurance/features/auth/presentation/screens/verify_email_screen.dart';
import 'package:mealvana_endurance/features/content/application/content_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../helpers/test_content.dart';
import '../../../helpers/widget_test_harness.dart';

/// What the fake saw and how it answers. Kept outside the notifier: the
/// auto-dispose provider is re-created between reads.
class _Spy {
  VerificationCodeRejection refusal = VerificationCodeRejection.wrong;
  Object? resendError;
  final codeSentAts = <DateTime?>[];
  final lastSentAts = <DateTime?>[];
}

class _FakeEmailAuthService extends EmailAuthService {
  _FakeEmailAuthService(this.spy);

  final _Spy spy;

  @override
  FutureOr<void> build() {}

  @override
  Future<void> verifyEmailOtp({
    required String email,
    required String token,
    OtpType type = OtpType.signup,
    String? pendingPassword,
    DateTime? codeSentAt,
  }) async {
    spy.codeSentAts.add(codeSentAt);
    throw InvalidVerificationCodeException(spy.refusal);
  }

  @override
  Future<void> resendVerificationCode({
    required String email,
    OtpType type = OtpType.signup,
    DateTime? lastSentAt,
  }) async {
    spy.lastSentAts.add(lastSentAt);
    if (spy.resendError != null) throw spy.resendError!;
  }

  @override
  Future<void> discardSignup({
    required String userId,
    required String email,
  }) async {}

  @override
  Future<void> abandonPendingSignup({required String reason}) async {}
}

final _content = loadDefaultContent();
final _resend = find.byKey(const ValueKey('auth.verify_resend'));

Future<void> _pump(WidgetTester tester, _Spy spy, {DateTime? codeSentAt}) =>
    smokeScreen(
      tester,
      VerifyEmailScreen(email: 'a@b.com', codeSentAt: codeSentAt),
      overrides: [
        contentServiceProvider.overrideWith(testContentService),
        emailAuthServiceProvider.overrideWith(() => _FakeEmailAuthService(spy)),
      ],
    );

Future<void> _enterCode(WidgetTester tester, String code) async {
  await tester.enterText(find.byType(TextField), code);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a wrong code says it is not right, from its content key', (
    tester,
  ) async {
    final spy = _Spy();
    await _pump(tester, spy);

    await _enterCode(tester, '111111');

    expect(
      find.text(_content['auth.verify_email.error_wrong_code']!),
      findsOneWidget,
    );
    expect(find.textContaining('expired'), findsNothing);
    expect(spy.codeSentAts.single, isNotNull);
  });

  testWidgets('an expired code says it expired, from its content key', (
    tester,
  ) async {
    final spy = _Spy()..refusal = VerificationCodeRejection.expired;
    await _pump(tester, spy);

    await _enterCode(tester, '111111');

    expect(
      find.text(_content['auth.verify_email.error_expired']!),
      findsOneWidget,
    );
  });

  testWidgets('Resend stays disabled for the server interval', (tester) async {
    await _pump(tester, _Spy());

    expect(tester.widget<TextButton>(_resend).onPressed, isNull);
    await tester.pump(const Duration(seconds: 59));
    expect(tester.widget<TextButton>(_resend).onPressed, isNull);
    await tester.pump(const Duration(seconds: 1));
    expect(tester.widget<TextButton>(_resend).onPressed, isNotNull);
  });

  testWidgets('a 429 restarts the countdown at the N GoTrue named', (
    tester,
  ) async {
    final spy = _Spy()..resendError = const ResendRateLimitedException(47);
    await _pump(tester, spy);
    await tester.pump(const Duration(seconds: 60));

    await tester.tap(_resend);
    await tester.pump();

    expect(find.text('Resend code in 47s'), findsOneWidget);
    expect(tester.widget<TextButton>(_resend).onPressed, isNull);
  });

  testWidgets('a failed Resend says so, from its content key', (tester) async {
    final spy = _Spy()
      ..resendError = VerificationResendFailedException(
        Exception('SocketException: Network is down'),
      );
    await _pump(tester, spy);
    await tester.pump(const Duration(seconds: 60));

    await tester.tap(_resend);
    await tester.pump();

    expect(
      find.text(_content['auth.verify_email.error_resend_failed']!),
      findsOneWidget,
    );
  });

  testWidgets('a Resend that went out shows the snackbar and restarts the '
      'code age', (tester) async {
    final spy = _Spy();
    await _pump(tester, spy);

    await _enterCode(tester, '111111');
    final firstSentAt = spy.codeSentAts.single!;

    await tester.pump(const Duration(seconds: 60));
    final beforeResend = DateTime.now();
    await tester.ensureVisible(_resend);
    await tester.tap(_resend);
    await tester.pump();

    expect(find.text('New code sent to a@b.com'), findsOneWidget);
    expect(spy.lastSentAts.single, firstSentAt);
    expect(find.text('Resend code in 60s'), findsOneWidget);

    await tester.pump(const Duration(seconds: 4));
    await _enterCode(tester, '222222');
    final secondSentAt = spy.codeSentAts.last!;
    expect(secondSentAt.isBefore(beforeResend), isFalse);
    expect(secondSentAt.isAfter(firstSentAt), isTrue);
  });

  group('a resumed code (ticket 42)', () {
    testWidgets('sent 20 s ago: Resend counts down from 40', (tester) async {
      await _pump(
        tester,
        _Spy(),
        codeSentAt: DateTime.now().subtract(const Duration(seconds: 20)),
      );

      expect(find.text('Resend code in 40s'), findsOneWidget);
      expect(tester.widget<TextButton>(_resend).onPressed, isNull);

      // The countdown's timer goes with the screen, inside the test body.
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('sent 70 s ago: Resend is enabled', (tester) async {
      final spy = _Spy();
      final sentAt = DateTime.now().subtract(const Duration(seconds: 70));
      await _pump(tester, spy, codeSentAt: sentAt);

      expect(find.text('Resend code'), findsOneWidget);
      expect(tester.widget<TextButton>(_resend).onPressed, isNotNull);

      // The code's age runs from the stored send time, not the screen's.
      await _enterCode(tester, '111111');
      expect(spy.codeSentAts.single, sentAt);
    });
  });
}
