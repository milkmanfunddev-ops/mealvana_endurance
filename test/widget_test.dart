// Basic widget test for Mealvana Endurance app
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/main.dart';

void main() {
  testWidgets('App starts with welcome screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MealvanaEnduranceApp());

    // Verify that our app starts with the welcome screen
    expect(find.text('Mealvana Endurance'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
  });
}
