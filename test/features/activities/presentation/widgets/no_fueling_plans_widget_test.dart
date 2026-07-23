import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/activities/presentation/widgets/no_fueling_plans_widget.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';

void main() {
  group('NoFuelingPlansWidget', () {
    testWidgets('displays calendar icon', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: NoFuelingPlansWidget())),
      );

      // Should show calendar icon
      expect(find.byIcon(Icons.calendar_today), findsOneWidget);

      // Icon should be 64px
      final iconWidget = tester.widget<Icon>(find.byIcon(Icons.calendar_today));
      expect(iconWidget.size, 64);
    });

    testWidgets('displays correct text content', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: NoFuelingPlansWidget())),
      );

      // Should show main title
      expect(find.text('No fueling plans yet'), findsOneWidget);

      // Should show orange subtitle
      expect(find.text('Tap + to fuel your next workout'), findsOneWidget);
    });

    testWidgets('orange subtitle uses AppColors.orange', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: NoFuelingPlansWidget())),
      );

      // Find the orange text widget
      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      final orangeText = textWidgets.firstWhere(
        (widget) => widget.data == 'Tap + to fuel your next workout',
      );

      // Verify it uses AppColors.orange
      expect(orangeText.style?.color, AppColors.orange);
    });

    testWidgets('uses Apercu font for title', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: NoFuelingPlansWidget())),
      );

      // Find the title text widget
      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      final titleText = textWidgets.firstWhere(
        (widget) => widget.data == 'No fueling plans yet',
      );

      // Verify it uses Apercu font
      expect(titleText.style?.fontFamily, 'Apercu');
    });

    testWidgets('subtitle is bold with larger font', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: NoFuelingPlansWidget())),
      );

      // Find the subtitle text widget
      final textWidgets = tester.widgetList<Text>(find.byType(Text));
      final subtitleText = textWidgets.firstWhere(
        (widget) => widget.data == 'Tap + to fuel your next workout',
      );

      // Verify it uses Apercu font with bold weight
      expect(subtitleText.style?.fontFamily, 'Apercu');
      expect(subtitleText.style?.fontWeight, FontWeight.w600);
      expect(subtitleText.style?.fontSize, 16);
    });

    testWidgets('layout is centered', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: NoFuelingPlansWidget())),
      );

      // Should have a Column with centered alignment
      final column = tester.widget<Column>(find.byType(Column));
      expect(column.crossAxisAlignment, CrossAxisAlignment.center);
    });
  });
}
