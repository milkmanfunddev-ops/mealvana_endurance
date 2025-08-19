// Basic widget test for Mealvana Endurance app
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mealvana_endurance/shared/widgets/root_app_widget.dart';

void main() {
  testWidgets('App starts with welcome screen', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: RootAppWidget()));

    // Verify that our app starts with the welcome screen
    expect(find.text('Mealvana Endurance'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
  });
}
