// Meal icon glyphs — every MealIcon parses and paints, the SVG-path parser
// handles the real 23 path strings, and one golden of the full set in both
// tile tones.
//
//   flutter test test/features/meal_planning/presentation/meal_icon_glyphs_test.dart \
//     --update-goldens
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mealvana_endurance/features/meal_planning/domain/meal_icon.dart';
import 'package:mealvana_endurance/features/meal_planning/domain/meal_type.dart';
import 'package:mealvana_endurance/features/meal_planning/presentation/widgets/meal_icon_glyphs.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';

void main() {
  group('parseSvgPath', () {
    test('every MealIcon has path data', () {
      for (final icon in MealIcon.values) {
        expect(mealIconPathData[icon], isNotNull, reason: icon.wire);
        expect(mealIconPathData[icon], isNotEmpty, reason: icon.wire);
      }
    });

    test(
      'all 23 glyph path strings parse with finite bounds inside the grid',
      () {
        for (final icon in MealIcon.values) {
          for (final d in mealIconPathData[icon]!) {
            final path = parseSvgPath(d);
            final b = path.getBounds();
            for (final v in [b.left, b.top, b.right, b.bottom]) {
              expect(v.isNaN, isFalse, reason: '${icon.wire}: "$d" → NaN');
              expect(v.isFinite, isTrue, reason: '${icon.wire}: "$d" → inf');
            }
            // A lone straight segment (e.g. bread's "M9 14h6") has a zero-height
            // rect, so check for *some* extent rather than Rect.isEmpty.
            expect(
              b.width > 0 || b.height > 0,
              isTrue,
              reason: '${icon.wire}: "$d" is degenerate',
            );
            expect(b.left, greaterThanOrEqualTo(0), reason: '${icon.wire}: $b');
            expect(b.top, greaterThanOrEqualTo(0), reason: '${icon.wire}: $b');
            expect(
              b.right,
              lessThanOrEqualTo(mealIconGridSize),
              reason: '${icon.wire}: $b',
            );
            expect(
              b.bottom,
              lessThanOrEqualTo(mealIconGridSize),
              reason: '${icon.wire}: $b',
            );
          }
        }
      },
    );

    test('combined per-icon path is cached and non-empty', () {
      for (final icon in MealIcon.values) {
        final a = mealIconPath(icon);
        expect(identical(a, mealIconPath(icon)), isTrue);
        expect(a.getBounds().isEmpty, isFalse, reason: icon.wire);
      }
    });

    test(
      'supports absolute + relative M L H V C S Q T A Z and implicit repeats',
      () {
        // Relative lineto repeats (l x y x y), H/V, S reflection, Q/T, arcs.
        final p = parseSvgPath(
          'M2 2l4 0 0 4H2V2z m8 0c1 0 2 1 2 2s-1 2-2 2 '
          'M14 10q2 -2 4 0t4 0 A2 2 0 0 1 22 14 a2 2 0 1 0-4 0Z',
        );
        final b = p.getBounds();
        expect(b.left, closeTo(2, 0.01));
        expect(b.top, closeTo(2, 0.01));
        expect(b.right, greaterThan(20));
        expect(b.bottom, greaterThan(12));
      },
    );

    test(
      'arc flags glued to the following number tokenise (a9 9 0 0 1-18 0)',
      () {
        final b = parseSvgPath('M3 12h18a9 9 0 0 1-18 0z').getBounds();
        expect(b.left, closeTo(3, 0.01));
        expect(b.right, closeTo(21, 0.01));
        expect(b.top, closeTo(12, 0.01));
        expect(b.bottom, closeTo(21, 0.01));
      },
    );

    test('point-size dots (h.01) parse without error', () {
      expect(
        parseSvgPath('M9 9h.01M11 13h.01').getBounds().width,
        closeTo(2.01, 0.001),
      );
    });

    test('unknown command throws FormatException', () {
      expect(() => parseSvgPath('M0 0 X1 1'), throwsFormatException);
      expect(() => parseSvgPath('M0 0 a1 1 0 2 0 1 1'), throwsFormatException);
      expect(() => parseSvgPath('M0 0 l1 1 z 2 2'), throwsFormatException);
    });
  });

  group('MealIconGlyph', () {
    testWidgets('every icon renders without throwing', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Wrap(
              children: [
                for (final icon in MealIcon.values)
                  MealIconGlyph(icon: icon, color: AppColors.electrolyte),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(MealIconGlyph), findsNWidgets(MealIcon.values.length));
    });

    testWidgets('falls back to the ambient IconTheme colour', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: IconTheme(
            data: IconThemeData(color: AppColors.dragonfruit),
            child: MealIconGlyph(icon: MealIcon.fish),
          ),
        ),
      );
      final paint = tester.widget<CustomPaint>(find.byType(CustomPaint).last);
      expect(
        (paint.painter as MealIconGlyphPainter).color,
        AppColors.dragonfruit,
      );
    });
  });

  group('MealIconTile', () {
    testWidgets('both tones render every icon without throwing', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Wrap(
              children: [
                for (final tone in MealIconTone.values)
                  for (final icon in MealIcon.values)
                    MealIconTile(icon: icon, tone: tone),
              ],
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        find.byType(MealIconTile),
        findsNWidgets(MealIcon.values.length * 2),
      );
    });

    testWidgets('default is 36px, soft tone, electrolyte tint', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Center(child: MealIconTile(icon: MealIcon.bowl)),
        ),
      );
      final box = tester.getSize(find.byType(MealIconTile));
      expect(box, const Size(36, 36));
      final container = tester.widget<Container>(find.byType(Container));
      final deco = container.decoration! as BoxDecoration;
      expect(deco.shape, BoxShape.circle);
      expect(
        deco.color,
        AppColors.electrolyte.withValues(alpha: MealIconTile.softTintAlpha),
      );
      final painter =
          tester.widget<CustomPaint>(find.byType(CustomPaint).last).painter!
              as MealIconGlyphPainter;
      expect(painter.color, AppColors.electrolyte);
      expect(painter.strokeWidth, MealIconTile.tileStroke);
    });

    testWidgets('solid tone picks a contrasting glyph colour', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Row(
            children: [
              MealIconTile(
                icon: MealIcon.bowl,
                tone: MealIconTone.solid,
                color: AppColors.electrolyte,
              ),
              MealIconTile(
                icon: MealIcon.bowl,
                tone: MealIconTone.solid,
                color: AppColors.dragonfruit,
              ),
            ],
          ),
        ),
      );
      final painters = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((w) => w.painter)
          .whereType<MealIconGlyphPainter>()
          .toList();
      expect(painters, hasLength(2));
      expect(painters[0].color, AppColors.blackberry); // light accent
      expect(painters[1].color, AppColors.cream); // dark accent
    });

    test('mealTypeColor maps every MealType onto the slot palette', () {
      for (final t in MealType.values) {
        expect(mealTypeColor(t), isA<Color>(), reason: t.wire);
      }
      expect(mealTypeColor(MealType.breakfast), AppColors.orange);
      expect(mealTypeColor(MealType.snack), AppColors.dragonfruit);
    });

    testWidgets('golden: all 23 icons in both tones', (tester) async {
      tester.view.physicalSize = const Size(600, 300);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            key: const Key('grid'),
            child: ColoredBox(
              color: AppColors.blackberry,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final tone in MealIconTone.values) ...[
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final icon in MealIcon.values)
                            MealIconTile(icon: icon, tone: tone),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    // Slot colours, solid, to show the contrast rule.
                    Wrap(
                      spacing: 12,
                      children: [
                        for (final t in MealType.values)
                          MealIconTile(
                            icon: MealIcon.utensils,
                            tone: MealIconTone.solid,
                            mealType: t,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final image = await captureImage(tester, find.byKey(const Key('grid')));
      expect(image, isNotNull);
      await expectLater(
        find.byKey(const Key('grid')),
        matchesGoldenFile('goldens/meal_icon_glyphs_grid.png'),
      );
    });
  });
}

/// Sanity-capture so a broken paint surfaces as an exception, not a blank PNG.
Future<ui.Image> captureImage(WidgetTester tester, Finder finder) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(finder);
  return boundary.toImage();
}
