// meal-image-mosaic.md v1.1 (PROPOSED) — the L2 widget vectors:
//   MIM-1  the mode decides the form (dish/tile → one image, mosaic → a grid)
//   MIM-2  `none` draws nothing of its own — no placeholder, no box
//   MIM-9  the icon state: a host's fallback fills the picture's own box, for
//          `none` and for a picture whose every photograph failed
//   MIM-3  tile count drives the grid; never more than four
//   MIM-4  every cell is BoxFit.cover
//   MIM-6  lives in meal_image_credits_test.dart
//   both themes build without exception
//
// Mutation check: let `none` paint a placeholder, let a 5th tile through, or
// size the fallback by anything but the picture's box → the matching test
// fails.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/data/meal_image_mosaic.dart';

KyleMealImageTile _tile(String n) =>
    KyleMealImageTile(url: 'https://example.test/$n.jpg', name: n);

Future<void> _pump(
  WidgetTester tester,
  MealImageMosaic mosaic, {
  Brightness brightness = Brightness.light,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(body: SizedBox(width: 300, height: 200, child: mosaic)),
    ),
  );
}

void main() {
  group('MIM-2 — none shows nothing', () {
    testWidgets('mode none takes no image and no space', (t) async {
      // Unconstrained, so "renders nothing" is observable as a zero size — a
      // placeholder panel or icon would give it width and height.
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: MealImageMosaic(
                mode: KyleMealImageMode.none,
                tiles: [_tile('oats')],
              ),
            ),
          ),
        ),
      );
      expect(find.byType(Image), findsNothing);
      expect(t.getSize(find.byType(MealImageMosaic)), Size.zero);
    });

    testWidgets('an empty tile list renders nothing', (t) async {
      await _pump(
        t,
        const MealImageMosaic(mode: KyleMealImageMode.mosaic, tiles: []),
      );
      expect(find.byType(Image), findsNothing);
    });
  });

  group('MIM-9 — the icon state takes the picture\'s place', () {
    const fallback = ColoredBox(
      key: ValueKey('fallback'),
      color: Color(0xFF000000),
    );
    final radius = BorderRadius.circular(9);

    Future<void> pumpIn(WidgetTester t, Size box, MealImageMosaic mosaic) =>
        t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: box.width,
                  height: box.height,
                  child: mosaic,
                ),
              ),
            ),
          ),
        );

    testWidgets('none draws the fallback at the size a picture would take', (
      t,
    ) async {
      await pumpIn(
        t,
        const Size(36, 36),
        MealImageMosaic(
          mode: KyleMealImageMode.none,
          tiles: const [],
          borderRadius: radius,
          fallback: fallback,
        ),
      );
      expect(find.byType(Image), findsNothing);
      expect(
        t.getSize(find.byKey(const ValueKey('fallback'))),
        const Size(36, 36),
      );
      // Same corners as a picture in the same box.
      final clip = t.widget<ClipRRect>(
        find.ancestor(
          of: find.byKey(const ValueKey('fallback')),
          matching: find.byType(ClipRRect),
        ),
      );
      expect(clip.borderRadius, radius);
    });

    testWidgets('a picture whose every photograph fails shows the fallback, '
        'not an empty box', (t) async {
      // flutter_test answers every request with HTTP 400, so each tile fails.
      await pumpIn(
        t,
        const Size(36, 36),
        MealImageMosaic(
          mode: KyleMealImageMode.mosaic,
          tiles: [_tile('a'), _tile('b')],
          borderRadius: radius,
          fallback: fallback,
        ),
      );
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await t.pump();
      await t.pump();

      expect(find.byType(Image), findsNothing);
      expect(
        t.getSize(find.byKey(const ValueKey('fallback'))),
        const Size(36, 36),
      );
    });

    testWidgets('with no fallback, none still takes no space', (t) async {
      await t.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: MealImageMosaic(mode: KyleMealImageMode.none, tiles: []),
            ),
          ),
        ),
      );
      expect(t.getSize(find.byType(MealImageMosaic)), Size.zero);
    });
  });

  group('MIM-1/MIM-3 — the grid follows the tile count', () {
    testWidgets('dish uses only the first tile', (t) async {
      await _pump(
        t,
        MealImageMosaic(
          mode: KyleMealImageMode.dish,
          tiles: [_tile('a'), _tile('b'), _tile('c')],
        ),
      );
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('two tiles render two cells', (t) async {
      await _pump(
        t,
        MealImageMosaic(
          mode: KyleMealImageMode.mosaic,
          tiles: [_tile('a'), _tile('b')],
        ),
      );
      expect(find.byType(Image), findsNWidgets(2));
    });

    testWidgets('three tiles render three cells', (t) async {
      await _pump(
        t,
        MealImageMosaic(
          mode: KyleMealImageMode.mosaic,
          tiles: [_tile('a'), _tile('b'), _tile('c')],
        ),
      );
      expect(find.byType(Image), findsNWidgets(3));
    });

    testWidgets('four tiles render a 2x2', (t) async {
      await _pump(
        t,
        MealImageMosaic(
          mode: KyleMealImageMode.mosaic,
          tiles: [_tile('a'), _tile('b'), _tile('c'), _tile('d')],
        ),
      );
      expect(find.byType(Image), findsNWidgets(4));
    });

    testWidgets('a fifth tile is never rendered', (t) async {
      await _pump(
        t,
        MealImageMosaic(
          mode: KyleMealImageMode.mosaic,
          tiles: [_tile('a'), _tile('b'), _tile('c'), _tile('d'), _tile('e')],
        ),
      );
      expect(find.byType(Image), findsNWidgets(4));
    });
  });

  testWidgets('MIM-4 — every cell covers, never distorts', (t) async {
    await _pump(
      t,
      MealImageMosaic(
        mode: KyleMealImageMode.mosaic,
        tiles: [_tile('a'), _tile('b')],
      ),
    );
    for (final img in t.widgetList<Image>(find.byType(Image))) {
      expect(img.fit, BoxFit.cover);
    }
  });

  testWidgets('builds in dark theme', (t) async {
    await _pump(
      t,
      MealImageMosaic(
        mode: KyleMealImageMode.mosaic,
        tiles: [_tile('a'), _tile('b'), _tile('c')],
      ),
      brightness: Brightness.dark,
    );
    expect(t.takeException(), isNull);
    expect(find.byType(Image), findsNWidgets(3));
  });

  group('mode wire parsing', () {
    test('known modes round-trip', () {
      expect(KyleMealImageMode.fromWire('dish'), KyleMealImageMode.dish);
      expect(KyleMealImageMode.fromWire('mosaic'), KyleMealImageMode.mosaic);
      expect(KyleMealImageMode.fromWire('tile'), KyleMealImageMode.tile);
    });

    test('null or unknown falls back to none, never to a placeholder', () {
      expect(KyleMealImageMode.fromWire(null), KyleMealImageMode.none);
      expect(KyleMealImageMode.fromWire('wat'), KyleMealImageMode.none);
    });
  });
}
