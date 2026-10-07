/// Every screen that takes an emailed code submits it on the sixth digit
/// (testing-wave 94 item 3, Finding 32-007): the athlete never has to reach
/// for Verify after typing, pasting or autofilling the code.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/auth/application/email_auth_service.dart';
import 'package:mealvana_endurance/features/auth/domain/auth_exceptions.dart';
import 'package:mealvana_endurance/features/auth/presentation/providers/password_recovery_controller.dart';
import 'package:mealvana_endurance/features/auth/presentation/screens/verify_email_screen.dart';
import 'package:mealvana_endurance/features/auth/presentation/screens/verify_reset_code_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../helpers/widget_test_harness.dart';

/// Records the codes it is asked to verify and refuses each one, so the
/// screen stays put (a success pops the route) and shows the refusal.
class _FakeEmailAuthService extends EmailAuthService {
  final tokens = <String>[];

  @override
  FutureOr<void> build() {}

  @override
  Future<void> verifyEmailOtp({
    required String email,
    required String token,
    OtpType type = OtpType.signup,
    String? pendingPassword,
  }) async {
    tokens.add(token);
    throw const InvalidVerificationCodeException('That code is not right.');
  }
}

class _FakePasswordRecoveryController extends PasswordRecoveryController {
  final codes = <String>[];

  @override
  FutureOr<void> build() {}

  @override
  Future<bool> verifyResetCode(String email, String code) async {
    codes.add(code);
    return false;
  }
}

void main() {
  testWidgets('Verify your email: the sixth digit submits the code', (
    tester,
  ) async {
    final auth = _FakeEmailAuthService();
    await smokeScreen(
      tester,
      const VerifyEmailScreen(email: 'test@example.com'),
      overrides: [emailAuthServiceProvider.overrideWith(() => auth)],
    );

    await tester.enterText(find.byType(TextField), '12345');
    await tester.pump();
    expect(auth.tokens, isEmpty, reason: 'five digits are not a code');

    await tester.enterText(find.byType(TextField), '123456');
    await tester.pumpAndSettle();

    expect(auth.tokens, ['123456']);
    expect(find.text('That code is not right.'), findsOneWidget);
  });

  testWidgets('Enter Reset Code: the sixth digit submits the code', (
    tester,
  ) async {
    final recovery = _FakePasswordRecoveryController();
    await smokeScreen(
      tester,
      const VerifyResetCodeScreen(email: 'test@example.com'),
      overrides: [
        passwordRecoveryControllerProvider.overrideWith(() => recovery),
      ],
    );

    await tester.enterText(find.byType(TextField), '65432');
    await tester.pump();
    expect(recovery.codes, isEmpty, reason: 'five digits are not a code');

    await tester.enterText(find.byType(TextField), '654321');
    await tester.pumpAndSettle();

    expect(recovery.codes, ['654321']);
  });
}
