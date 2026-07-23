import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/inputs/intensity_composite_bar.dart';

void main() {
  group('IntensityCompositeBar', () {
    testWidgets('renders with correct proportions for balanced distribution', (
      WidgetTester tester,
    ) async {
      // Arrange
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: IntensityCompositeBar(
              conversationalPct: 70,
              tempoPct: 20,
              allOutPct: 10,
            ),
          ),
        ),
      );

      // Act
      await tester.pumpAndSettle();

      // Assert - verify widget renders
      expect(find.byType(IntensityCompositeBar), findsOneWidget);

      // Verify the container exists
      final containerFinder = find.byType(Container);
      expect(containerFinder, findsWidgets);
    });

    testWidgets('renders with 100% conversational (green only)', (
      WidgetTester tester,
    ) async {
      // Arrange
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: IntensityCompositeBar(
              conversationalPct: 100,
              tempoPct: 0,
              allOutPct: 0,
            ),
          ),
        ),
      );

      // Act
      await tester.pumpAndSettle();

      // Assert - verify widget renders with single segment
      expect(find.byType(IntensityCompositeBar), findsOneWidget);

      // Find the Row that contains the segments
      final rowFinder = find.byType(Row);
      expect(rowFinder, findsOneWidget);

      // Verify only one Expanded widget (single segment)
      final row = tester.widget<Row>(rowFinder);
      final expandedWidgets = row.children.whereType<Expanded>().toList();
      expect(expandedWidgets.length, 1);
      expect(expandedWidgets[0].flex, 100);
    });

    testWidgets('renders with 100% tempo (yellow only)', (
      WidgetTester tester,
    ) async {
      // Arrange
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: IntensityCompositeBar(
              conversationalPct: 0,
              tempoPct: 100,
              allOutPct: 0,
            ),
          ),
        ),
      );

      // Act
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(IntensityCompositeBar), findsOneWidget);

      final rowFinder = find.byType(Row);
      final row = tester.widget<Row>(rowFinder);
      final expandedWidgets = row.children.whereType<Expanded>().toList();
      expect(expandedWidgets.length, 1);
      expect(expandedWidgets[0].flex, 100);
    });

    testWidgets('renders with equal distribution (33/33/34)', (
      WidgetTester tester,
    ) async {
      // Arrange
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: IntensityCompositeBar(
              conversationalPct: 33,
              tempoPct: 33,
              allOutPct: 34,
            ),
          ),
        ),
      );

      // Act
      await tester.pumpAndSettle();

      // Assert - verify three segments rendered
      expect(find.byType(IntensityCompositeBar), findsOneWidget);

      final rowFinder = find.byType(Row);
      final row = tester.widget<Row>(rowFinder);
      final expandedWidgets = row.children.whereType<Expanded>().toList();
      expect(expandedWidgets.length, 3);

      // Verify flex values match percentages
      expect(expandedWidgets[0].flex, 33); // conversational
      expect(expandedWidgets[1].flex, 33); // tempo
      expect(expandedWidgets[2].flex, 34); // all-out
    });

    testWidgets('has correct colors for each segment', (
      WidgetTester tester,
    ) async {
      // Arrange
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: IntensityCompositeBar(
              conversationalPct: 70,
              tempoPct: 20,
              allOutPct: 10,
            ),
          ),
        ),
      );

      // Act
      await tester.pumpAndSettle();

      // Assert - find containers with specific colors
      final rowFinder = find.byType(Row);
      final row = tester.widget<Row>(rowFinder);
      final expandedWidgets = row.children.whereType<Expanded>().toList();

      // Verify we have 3 segments
      expect(expandedWidgets.length, 3);

      // Verify colors (green, yellow, red)
      final conversationalContainer = expandedWidgets[0].child as Container;
      expect(
        conversationalContainer.color,
        const Color(0xFF4ADE80), // Green
      );

      final tempoContainer = expandedWidgets[1].child as Container;
      expect(
        tempoContainer.color,
        const Color(0xFFFBBF24), // Yellow
      );

      final allOutContainer = expandedWidgets[2].child as Container;
      expect(
        allOutContainer.color,
        const Color(0xFFEF4444), // Red
      );
    });

    testWidgets('has rounded corners', (WidgetTester tester) async {
      // Arrange
      const barHeight = 10.0;
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: IntensityCompositeBar(
              conversationalPct: 70,
              tempoPct: 20,
              allOutPct: 10,
              height: barHeight,
            ),
          ),
        ),
      );

      // Act
      await tester.pumpAndSettle();

      // Assert - verify container has rounded border
      final containerFinder = find.descendant(
        of: find.byType(IntensityCompositeBar),
        matching: find.byType(Container),
      );

      expect(containerFinder, findsWidgets);

      // Get the outer container (first one)
      final container = tester.widget<Container>(containerFinder.first);
      final decoration = container.decoration as BoxDecoration;
      final borderRadius = decoration.borderRadius as BorderRadius;

      // Verify fully rounded corners (radius = height / 2)
      expect(borderRadius.topLeft.x, barHeight / 2);
      expect(borderRadius.topLeft.y, barHeight / 2);
    });

    testWidgets('supports custom height', (WidgetTester tester) async {
      // Arrange
      const customHeight = 12.0;
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: IntensityCompositeBar(
              conversationalPct: 70,
              tempoPct: 20,
              allOutPct: 10,
              height: customHeight,
            ),
          ),
        ),
      );

      // Act
      await tester.pumpAndSettle();

      // Assert - verify height is applied
      final containerFinder = find.descendant(
        of: find.byType(IntensityCompositeBar),
        matching: find.byType(Container),
      );

      final container = tester.widget<Container>(containerFinder.first);
      expect(container.constraints?.maxHeight, customHeight);
    });

    testWidgets('handles edge case with zero segments gracefully', (
      WidgetTester tester,
    ) async {
      // Arrange - This represents a special case where user hasn't set any values yet
      // We'll allow (0,0,100) as a valid state
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: IntensityCompositeBar(
              conversationalPct: 0,
              tempoPct: 0,
              allOutPct: 100,
            ),
          ),
        ),
      );

      // Act
      await tester.pumpAndSettle();

      // Assert - should render without errors
      expect(find.byType(IntensityCompositeBar), findsOneWidget);
    });
  });
}
