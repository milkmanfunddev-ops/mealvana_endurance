/// Log a Meal's Describe tab with the keyboard up (testing-wave 23-001,
/// fix ticket 52): Analyze stays in reach above the keys while the athlete
/// types, instead of hiding behind the keyboard with only a sliver showing.
///
/// Through the real screen: the keyboard is the view's bottom inset, the way
/// the platform reports it, and the Scaffold resizes the page above it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_logging/presentation/screens/log_meal_screen.dart';

import '../../helpers/widget_test_harness.dart';

/// An iPhone keyboard with its suggestion bar, in logical pixels.
const _keyboardHeight = 336.0;

Future<void> _openDescribe(WidgetTester tester) async {
  await smokeScreen(
    tester,
    const LogMealScreen(logDate: '2026-09-25', source: 'test'),
    settle: false,
  );
  addTearDown(tester.view.reset);
  await tester.tap(find.text('Describe'));
  await tester.pump();
}

Future<void> _keyboardUp(WidgetTester tester) async {
  tester.view.viewInsets = const FakeViewPadding(bottom: _keyboardHeight);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('with the keyboard up, Analyze can be tapped above it', (
    tester,
  ) async {
    await _openDescribe(tester);

    await tester.tap(find.byType(TextFormField));
    await tester.pump();
    await tester.enterText(
      find.byType(TextFormField),
      'Two eggs on toast\nA banana\nA large coffee with oat milk',
    );
    await _keyboardUp(tester);

    final analyze = find.text('Analyze').hitTestable();
    expect(analyze, findsOneWidget);
    // Above the keys, not under them.
    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(
      tester.getRect(find.text('Analyze')).bottom,
      lessThanOrEqualTo(screenHeight - _keyboardHeight),
    );
  });

  testWidgets('with the keyboard up, the field being typed in stays in view', (
    tester,
  ) async {
    await _openDescribe(tester);

    await tester.tap(find.byType(TextFormField));
    await tester.pump();
    await tester.enterText(find.byType(TextFormField), 'Porridge');
    await _keyboardUp(tester);

    expect(find.byType(TextFormField).hitTestable(), findsOneWidget);
  });

  testWidgets('Analyze sends from above the keyboard in one tap', (
    tester,
  ) async {
    await _openDescribe(tester);

    await tester.tap(find.byType(TextFormField));
    await tester.pump();
    // Too short to send: the validator answers, which proves the tap landed
    // on Analyze and was not swallowed by the keyboard closing under it.
    await tester.enterText(find.byType(TextFormField), 'egg');
    await _keyboardUp(tester);

    await tester.tap(find.text('Analyze').hitTestable());
    await tester.pump();

    expect(find.text('Please describe your meal'), findsOneWidget);
  });
}
