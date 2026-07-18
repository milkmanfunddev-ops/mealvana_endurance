import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/app_startup/presentation/screens/force_upgrade_screen.dart';
import 'package:mealvana_endurance/shared/services/app_config.dart';

void main() {
  group('ForceUpgradeScreen', () {
    const currentVersion = '1.11.0';
    const requiredVersion = '1.12.0';

    // ForceUpgradeScreen is a ConsumerWidget that reads `appConfigProvider`
    // at build time (to pick the store/flavor URL), so it must be pumped inside
    // a ProviderScope with that provider overridden.
    Future<void> pumpScreen(WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appConfigProvider.overrideWithValue(AppConfig.forTesting()),
          ],
          child: const MaterialApp(
            home: ForceUpgradeScreen(
              currentVersion: currentVersion,
              requiredVersion: requiredVersion,
            ),
          ),
        ),
      );
    }

    testWidgets('displays current version', (WidgetTester tester) async {
      await pumpScreen(tester);

      expect(find.text('Your current version: $currentVersion'), findsOneWidget);
    });

    testWidgets('displays required version', (WidgetTester tester) async {
      await pumpScreen(tester);

      expect(
        find.textContaining('update to version $requiredVersion or later'),
        findsOneWidget,
      );
    });

    testWidgets('displays Update Now button', (WidgetTester tester) async {
      await pumpScreen(tester);

      expect(find.text('Update Now'), findsOneWidget);
    });

    testWidgets('displays Update Required title', (WidgetTester tester) async {
      await pumpScreen(tester);

      expect(find.text('Update Required'), findsOneWidget);
    });

    testWidgets('displays system update icon', (WidgetTester tester) async {
      await pumpScreen(tester);

      expect(find.byIcon(Icons.system_update), findsOneWidget);
    });

    testWidgets('blocks back navigation with PopScope', (WidgetTester tester) async {
      await pumpScreen(tester);

      // Find the PopScope widget and verify canPop is false
      final popScopeFinder = find.byType(PopScope);
      expect(popScopeFinder, findsOneWidget);

      final popScope = tester.widget<PopScope>(popScopeFinder);
      expect(popScope.canPop, isFalse);
    });
  });
}
