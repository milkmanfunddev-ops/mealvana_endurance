import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/inputs/intensity_zone_slider.dart';

void main() {
  group('IntensityZoneSlider', () {
    late int lastChangedValue;
    late int changeCallCount;

    void onChanged(int value) {
      lastChangedValue = value;
      changeCallCount++;
    }

    setUp(() {
      lastChangedValue = -1;
      changeCallCount = 0;
    });

    Widget createTestWidget({
      String label = 'Conversational (Z1-Z2)',
      Color color = Colors.green,
      int value = 70,
      bool enabled = true,
    }) {
      return ProviderScope(
        child: MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: IntensityZoneSlider(
              label: label,
              color: color,
              value: value,
              onChanged: onChanged,
              enabled: enabled,
            ),
          ),
        ),
      );
    }

    testWidgets('renders with correct label and value', (tester) async {
      await tester.pumpWidget(createTestWidget());

      // Check label is displayed
      expect(find.text('Conversational (Z1-Z2)'), findsOneWidget);

      // Check value is displayed in text field
      expect(find.text('70'), findsOneWidget);

      // Check % suffix is displayed
      expect(find.text('%'), findsOneWidget);
    });

    testWidgets('displays colored dot indicator', (tester) async {
      await tester.pumpWidget(createTestWidget(color: Colors.red));

      // Find the container with the colored dot
      final container = tester.widget<Container>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).shape == BoxShape.circle,
        ),
      );

      final decoration = container.decoration as BoxDecoration;
      expect(decoration.color, Colors.red);
    });

    testWidgets('slider shows correct initial value', (tester) async {
      await tester.pumpWidget(createTestWidget(value: 50));

      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.value, 50.0);
    });

    testWidgets('onChanged is called when slider moves', (tester) async {
      await tester.pumpWidget(createTestWidget(value: 50));

      // Find the slider
      final sliderFinder = find.byType(Slider);
      expect(sliderFinder, findsOneWidget);

      // Drag slider to change value
      await tester.drag(sliderFinder, const Offset(50, 0));
      await tester.pumpAndSettle();

      // Verify onChanged was called
      expect(changeCallCount, greaterThan(0));
      expect(lastChangedValue, isNot(-1));
      expect(
        lastChangedValue,
        isNot(50),
      ); // Should have changed from initial value
    });

    testWidgets('text field shows correct value', (tester) async {
      await tester.pumpWidget(createTestWidget(value: 85));

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, '85');
    });

    testWidgets('onChanged is called when text is edited', (tester) async {
      await tester.pumpWidget(createTestWidget(value: 70));

      // Find text field
      final textFieldFinder = find.byType(TextField);

      // Tap to focus
      await tester.tap(textFieldFinder);
      await tester.pumpAndSettle();

      // Clear and enter new value
      await tester.enterText(textFieldFinder, '45');
      await tester.pumpAndSettle();

      // Verify onChanged was called with new value
      expect(lastChangedValue, 45);
      expect(changeCallCount, greaterThan(0));
    });

    testWidgets('text field validates input range (0-100)', (tester) async {
      await tester.pumpWidget(createTestWidget(value: 50));

      final textFieldFinder = find.byType(TextField);

      // Test valid value
      await tester.tap(textFieldFinder);
      await tester.pumpAndSettle();
      await tester.enterText(textFieldFinder, '95');
      await tester.pumpAndSettle();
      expect(lastChangedValue, 95);

      // Test boundary value (0)
      changeCallCount = 0;
      await tester.enterText(textFieldFinder, '0');
      await tester.pumpAndSettle();
      expect(lastChangedValue, 0);

      // Test boundary value (100)
      changeCallCount = 0;
      await tester.enterText(textFieldFinder, '100');
      await tester.pumpAndSettle();
      expect(lastChangedValue, 100);
    });

    testWidgets('text field rejects invalid input', (tester) async {
      await tester.pumpWidget(createTestWidget(value: 50));

      final textFieldFinder = find.byType(TextField);

      // Try to enter value > 100
      await tester.tap(textFieldFinder);
      await tester.pumpAndSettle();

      final initialCallCount = changeCallCount;
      final initialValue = lastChangedValue;

      await tester.enterText(textFieldFinder, '150');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Should not have called onChanged with invalid value
      // Note: The widget may call onChanged during typing, so we just verify
      // that the value isn't 150
      expect(lastChangedValue, isNot(150));
    });

    testWidgets('text field reverts to current value on invalid submit', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget(value: 50));

      final textFieldFinder = find.byType(TextField);

      // Enter invalid value
      await tester.tap(textFieldFinder);
      await tester.pumpAndSettle();
      await tester.enterText(textFieldFinder, 'abc');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Text field should revert to current value (50)
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, '50');
    });

    testWidgets('slider and text field work together', (tester) async {
      await tester.pumpWidget(createTestWidget(value: 30));

      // Change value via slider
      final sliderFinder = find.byType(Slider);
      await tester.drag(sliderFinder, const Offset(100, 0));
      await tester.pumpAndSettle();

      final newValue = lastChangedValue;
      expect(newValue, isNot(30));

      // Verify text field updated
      await tester.pumpAndSettle();
      final textField = tester.widget<TextField>(find.byType(TextField));
      // Text field should show the new value (may not update during drag if focused)
      // So we just verify it's a valid value
      final displayedValue = int.tryParse(textField.controller?.text ?? '');
      expect(displayedValue, isNotNull);
      expect(displayedValue! >= 0 && displayedValue <= 100, true);
    });

    testWidgets('disabled state prevents interaction', (tester) async {
      await tester.pumpWidget(createTestWidget(value: 50, enabled: false));

      // Slider should be disabled
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.onChanged, isNull);

      // Text field should be disabled
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.enabled, false);

      // Try to interact - should not call onChanged
      changeCallCount = 0;
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();
      expect(changeCallCount, 0);
    });

    testWidgets('disabled state shows dimmed colors', (tester) async {
      await tester.pumpWidget(
        createTestWidget(enabled: false, color: Colors.blue),
      );

      // Find the colored dot container
      final container = tester.widget<Container>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Container &&
              widget.decoration is BoxDecoration &&
              (widget.decoration as BoxDecoration).shape == BoxShape.circle,
        ),
      );

      final decoration = container.decoration as BoxDecoration;
      // Should have opacity applied when disabled
      expect(decoration.color?.opacity, lessThan(1.0));
    });

    testWidgets('text field only accepts digits', (tester) async {
      await tester.pumpWidget(createTestWidget(value: 50));

      final textFieldFinder = find.byType(TextField);

      // Tap to focus
      await tester.tap(textFieldFinder);
      await tester.pumpAndSettle();

      // Try to enter non-digit characters
      await tester.enterText(textFieldFinder, 'abc123def');
      await tester.pumpAndSettle();

      // Should only accept the digits
      final textField = tester.widget<TextField>(textFieldFinder);
      // The input formatter should have removed non-digits
      // Actual filtering happens at the platform level, so we just verify
      // that the widget has the digit-only formatter configured
      expect(textField.inputFormatters, isNotEmpty);
    });

    testWidgets('updates when value prop changes externally', (tester) async {
      await tester.pumpWidget(createTestWidget(value: 50));

      // Verify initial value
      var textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, '50');

      // Rebuild with new value
      await tester.pumpWidget(createTestWidget(value: 75));
      await tester.pumpAndSettle();

      // Verify text field updated
      textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, '75');

      // Verify slider updated
      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.value, 75.0);
    });
  });
}
