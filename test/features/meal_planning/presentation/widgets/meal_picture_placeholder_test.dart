import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/meal_picture_placeholder.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';

/// mp-145 — a meal with no photo shows a plain placeholder, not an icon: a
/// flat tint of the host's own ink at the picture's footprint, and nothing
/// drawn inside it.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    Brightness brightness = Brightness.light,
    double size = 36,
    BorderRadius? borderRadius,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: Scaffold(
          body: Center(
            child: MealPicturePlaceholder(
              size: size,
              borderRadius: borderRadius,
            ),
          ),
        ),
      ),
    );
    // A theme change on re-pump animates through AnimatedTheme.
    await tester.pumpAndSettle();
  }

  BoxDecoration decorationOf(WidgetTester tester) =>
      tester
              .widget<Container>(
                find.descendant(
                  of: find.byType(MealPicturePlaceholder),
                  matching: find.byType(Container),
                ),
              )
              .decoration!
          as BoxDecoration;

  testWidgets('takes the picture footprint and draws nothing inside', (
    tester,
  ) async {
    await pump(tester);

    expect(
      tester.getSize(find.byType(MealPicturePlaceholder)),
      const Size(36, 36),
    );
    expect(
      find.descendant(
        of: find.byType(MealPicturePlaceholder),
        matching: find.byType(Icon),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(MealPicturePlaceholder),
        matching: find.byType(Text),
      ),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(MealPicturePlaceholder),
        matching: find.byType(CustomPaint),
      ),
      findsNothing,
    );
  });

  testWidgets('is a flat tint of the host ink, no border', (tester) async {
    await pump(tester);
    final light = decorationOf(tester);
    expect(
      light.color,
      AppColors.blackberry.withValues(alpha: MealPicturePlaceholder.tintAlpha),
    );
    expect(light.border, isNull);

    await pump(tester, brightness: Brightness.dark);
    final dark = decorationOf(tester);
    expect(
      dark.color,
      AppColors.cream.withValues(alpha: MealPicturePlaceholder.tintAlpha),
    );
  });

  testWidgets('corners follow the picture: size/4 by default, or the host\'s', (
    tester,
  ) async {
    await pump(tester, size: 36);
    expect(decorationOf(tester).borderRadius, BorderRadius.circular(9));

    await pump(tester, size: 28, borderRadius: BorderRadius.circular(4));
    expect(decorationOf(tester).borderRadius, BorderRadius.circular(4));
    expect(
      tester.getSize(find.byType(MealPicturePlaceholder)),
      const Size(28, 28),
    );
  });
}
