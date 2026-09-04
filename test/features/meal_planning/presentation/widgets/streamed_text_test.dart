import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/streamed_text.dart';

void main() {
  const style = TextStyle(color: Colors.black, fontSize: 14);

  Future<void> pump(WidgetTester tester, String text, {bool animate = true}) =>
      tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StreamedText(text: text, style: style, animate: animate),
          ),
        ),
      );

  /// The alpha of the last span — the streamed tail.
  double tailAlpha(WidgetTester tester) {
    final selectable = tester.widget<SelectableText>(
      find.byType(SelectableText),
    );
    final span = selectable.textSpan;
    if (span == null) return 1;
    final last = span.children!.last as TextSpan;
    return last.style?.color?.a ?? 1;
  }

  testWidgets('a new chunk fades in while the earlier text stays put', (
    tester,
  ) async {
    await pump(tester, 'Race week, ');
    await pump(tester, 'Race week, so carbs come first.');
    await tester.pump();
    expect(find.text('Race week, so carbs come first.'), findsOneWidget);
    expect(tailAlpha(tester), lessThan(0.5));
    await tester.pump(const Duration(milliseconds: 80));
    final mid = tailAlpha(tester);
    expect(mid, greaterThan(0));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tailAlpha(tester), 1);
  });

  testWidgets('a rewrite that is not an extension commits at once', (
    tester,
  ) async {
    await pump(tester, 'Race week, so carbs.');
    await pump(tester, 'Something else entirely.');
    await tester.pump();
    expect(find.text('Something else entirely.'), findsOneWidget);
    expect(tailAlpha(tester), 1);
  });

  testWidgets('animate false renders every update immediately', (
    tester,
  ) async {
    await pump(tester, 'Race week, ', animate: false);
    await pump(tester, 'Race week, so carbs.', animate: false);
    await tester.pump();
    expect(tailAlpha(tester), 1);
  });
}
