import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/app_startup/presentation/screens/force_upgrade_screen.dart';

void main() {
  group('ForceUpgradeScreen', () {
    testWidgets('displays current version', (WidgetTester tester) async {
      // Arrange
      const currentVersion = '1.11.0';
      const requiredVersion = '1.12.0';

      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: ForceUpgradeScreen(
            currentVersion: currentVersion,
            requiredVersion: requiredVersion,
          ),
        ),
      );

      // Assert
      expect(find.text('Your current version: $currentVersion'), findsOneWidget);
    });

    testWidgets('displays required version', (WidgetTester tester) async {
      // Arrange
      const currentVersion = '1.11.0';
      const requiredVersion = '1.12.0';

      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: ForceUpgradeScreen(
            currentVersion: currentVersion,
            requiredVersion: requiredVersion,
          ),
        ),
      );

      // Assert
      expect(
        find.textContaining('update to version $requiredVersion or later'),
        findsOneWidget,
      );
    });

    testWidgets('displays Update Now button', (WidgetTester tester) async {
      // Arrange
      const currentVersion = '1.11.0';
      const requiredVersion = '1.12.0';

      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: ForceUpgradeScreen(
            currentVersion: currentVersion,
            requiredVersion: requiredVersion,
          ),
        ),
      );

      // Assert
      expect(find.text('Update Now'), findsOneWidget);
    });

    testWidgets('displays Update Required title', (WidgetTester tester) async {
      // Arrange
      const currentVersion = '1.11.0';
      const requiredVersion = '1.12.0';

      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: ForceUpgradeScreen(
            currentVersion: currentVersion,
            requiredVersion: requiredVersion,
          ),
        ),
      );

      // Assert
      expect(find.text('Update Required'), findsOneWidget);
    });

    testWidgets('displays system update icon', (WidgetTester tester) async {
      // Arrange
      const currentVersion = '1.11.0';
      const requiredVersion = '1.12.0';

      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: ForceUpgradeScreen(
            currentVersion: currentVersion,
            requiredVersion: requiredVersion,
          ),
        ),
      );

      // Assert
      expect(find.byIcon(Icons.system_update), findsOneWidget);
    });

    testWidgets('blocks back navigation with PopScope', (WidgetTester tester) async {
      // Arrange
      const currentVersion = '1.11.0';
      const requiredVersion = '1.12.0';

      // Act
      await tester.pumpWidget(
        const MaterialApp(
          home: ForceUpgradeScreen(
            currentVersion: currentVersion,
            requiredVersion: requiredVersion,
          ),
        ),
      );

      // Assert - Find the PopScope widget and verify canPop is false
      final popScopeFinder = find.byType(PopScope);
      expect(popScopeFinder, findsOneWidget);

      final popScope = tester.widget<PopScope>(popScopeFinder);
      expect(popScope.canPop, isFalse);
    });
  });
}
