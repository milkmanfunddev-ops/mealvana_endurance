/// Every screen that takes an emailed code offers the phone's one-time-code
/// autofill and a number keyboard (testing-wave 81, 32-007): iOS and Android
/// then surface the code from Mail above the keyboard.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/auth/presentation/providers/password_recovery_controller.dart';
import 'package:mealvana_endurance/features/auth/presentation/screens/verify_email_screen.dart';
import 'package:mealvana_endurance/features/auth/presentation/screens/verify_reset_code_screen.dart';

import '../../../helpers/widget_test_harness.dart';

class _FakePasswordRecoveryController extends PasswordRecoveryController {
  @override
  FutureOr<void> build() {}
}

/// The one editable field on [screen], whatever widget wraps it.
Future<TextField> _codeField(
  WidgetTester tester,
  Widget screen, {
  List<Override> overrides = const [],
}) async {
  await smokeScreen(tester, screen, overrides: overrides);
  return tester.widget<TextField>(find.byType(TextField));
}

void main() {
  testWidgets('Verify your email: one-time-code autofill, number keyboard', (
    tester,
  ) async {
    final field = await _codeField(
      tester,
      const VerifyEmailScreen(email: 'test@example.com'),
    );
    expect(field.autofillHints, contains(AutofillHints.oneTimeCode));
    expect(field.keyboardType, TextInputType.number);
  });

  testWidgets('Enter Reset Code: one-time-code autofill, number keyboard', (
    tester,
  ) async {
    final field = await _codeField(
      tester,
      const VerifyResetCodeScreen(email: 'test@example.com'),
      overrides: [
        passwordRecoveryControllerProvider.overrideWith(
          _FakePasswordRecoveryController.new,
        ),
      ],
    );
    expect(field.autofillHints, contains(AutofillHints.oneTimeCode));
    expect(field.keyboardType, TextInputType.number);
  });
}
