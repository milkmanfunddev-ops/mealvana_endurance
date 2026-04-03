import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/nutrition_plan/presentation/widgets/stale_plan_warning.dart';

void main() {
  testWidgets('renders custom stale-settings banner copy', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StalePlanWarning(
            title: 'Nutrition Settings Changed',
            message:
                'Nutrition settings changed. Regenerate plan to apply new targets.',
            onRegeneratePlan: () {},
          ),
        ),
      ),
    );

    expect(find.text('Nutrition Settings Changed'), findsOneWidget);
    expect(
      find.text(
        'Nutrition settings changed. Regenerate plan to apply new targets.',
      ),
      findsOneWidget,
    );
    expect(find.text('Regenerate Plan'), findsOneWidget);
  });
}
