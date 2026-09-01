// Widget tests for the personal info step (onboarding step 4, 2026-08
// redesign).
//
// Pins the phase-5 contract: Continue is gated on gender + birth year (the
// RMR inputs), names/email stay optional, and every answer mirrors into the
// controller draft immediately.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/auth/domain/user_preferences.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/providers/onboarding_controller.dart';
import 'package:mealvana_endurance/features/onboarding/presentation/screens/personal_info_screen.dart';

import '../../helpers/widget_test_harness.dart';

void main() {
  Future<ProviderContainer> pumpScreen(
    WidgetTester tester, {
    VoidCallback? onContinue,
  }) async {
    tester.view.physicalSize = standardPhoneSize;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [mockAppExternalDeps(), mockSharedPreferences()],
        child: wrapForTest(
          PersonalInfoScreen(onContinue: onContinue, stepIndex: 4),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return ProviderScope.containerOf(
      tester.element(find.byType(PersonalInfoScreen)),
    );
  }

  testWidgets('Continue is gated on gender + birth year', (tester) async {
    var continued = 0;
    final container = await pumpScreen(tester, onContinue: () => continued++);
    final controller = container.read(onboardingControllerProvider.notifier);

    // Nothing selected — Continue is disabled.
    await tester.tap(
      find.byKey(const ValueKey('personal_info.continue_button')),
    );
    await tester.pumpAndSettle();
    expect(continued, 0);

    // Gender alone is not enough.
    // The spec's inline wheel always carries a value — the default year is
    // written to the draft on first frame, so gender is the only gate.
    expect(controller.draft.birthYear, 1994);

    await tester.tap(find.byKey(const ValueKey('personal_info.gender_male')));
    await tester.pumpAndSettle();
    expect(controller.draft.gender, Gender.male);

    // Gate satisfied — Continue advances.
    await tester.tap(
      find.byKey(const ValueKey('personal_info.continue_button')),
    );
    await tester.pumpAndSettle();
    expect(continued, 1);
    expectNoRenderOverflow(tester);
  });

  testWidgets('non-binary card maps to Gender.other', (tester) async {
    final container = await pumpScreen(tester);
    final controller = container.read(onboardingControllerProvider.notifier);

    await tester.tap(
      find.byKey(const ValueKey('personal_info.gender_non_binary')),
    );
    await tester.pumpAndSettle();
    expect(controller.draft.gender, Gender.other);
  });

  testWidgets('names and email are optional and mirror into the draft', (
    tester,
  ) async {
    final container = await pumpScreen(tester);
    final controller = container.read(onboardingControllerProvider.notifier);

    // Optional fields start empty in the draft.
    expect(controller.draft.firstName, isNull);
    expect(controller.draft.lastName, isNull);
    expect(controller.draft.email, isNull);

    await tester.enterText(
      find.byKey(const ValueKey('personal_info.first_name_field')),
      'Ada',
    );
    await tester.enterText(
      find.byKey(const ValueKey('personal_info.last_name_field')),
      'Lovelace',
    );
    await tester.enterText(
      find.byKey(const ValueKey('personal_info.email_field')),
      'ada@example.com',
    );
    await tester.pumpAndSettle();

    expect(controller.draft.firstName, 'Ada');
    expect(controller.draft.lastName, 'Lovelace');
    expect(controller.draft.email, 'ada@example.com');
  });
}
