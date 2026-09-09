// meal-image-mosaic.md v1 (PROPOSED) — the L2 widget vectors:
//   MIM-1  the mode decides the form (dish/tile → one image, mosaic → a grid)
//   MIM-2  `none` renders nothing at all — no icon, no placeholder, no box
//   MIM-3  tile count drives the grid; never more than four
//   MIM-4  every cell is BoxFit.cover
//   MIM-6  attribution names photographer AND source per provider
//   both themes build without exception
//
// Mutation check: let `none` paint a placeholder, let a 5th tile through, or
// drop "on Unsplash" from the credit → the matching test fails.

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
          tiles: [
            _tile('a'),
            _tile('b'),
            _tile('c'),
            _tile('d'),
            _tile('e'),
          ],
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

  group('MIM-6 — attribution per provider', () {
    test('Unsplash names the photographer and Unsplash', () {
      const t = KyleMealImageTile(
        url: 'u',
        creator: 'Annie Spratt',
        provider: 'unsplash',
      );
      expect(t.attribution, 'Photo by Annie Spratt on Unsplash');
    });

    test('Pexels names the photographer and Pexels', () {
      const t = KyleMealImageTile(
        url: 'u',
        creator: 'Ella Olsson',
        provider: 'pexels',
      );
      expect(t.attribution, 'Photo by Ella Olsson on Pexels');
    });

    test('Unsplash still credits the source with no photographer', () {
      const t = KyleMealImageTile(url: 'u', provider: 'unsplash');
      expect(t.attribution, 'Photo on Unsplash');
    });

    test('Creative Commons pairs creator with licence', () {
      const t = KyleMealImageTile(
        url: 'u',
        creator: 'Fructibus',
        license: 'CC0',
        provider: 'wikimedia',
      );
      expect(t.attribution, 'Fructibus · CC0');
    });

    test('licence alone is enough', () {
      const t = KyleMealImageTile(
        url: 'u',
        license: 'CC BY-SA 4.0',
        provider: 'wikimedia',
      );
      expect(t.attribution, 'CC BY-SA 4.0');
    });

    test('nothing to credit returns null, never an empty line', () {
      const t = KyleMealImageTile(url: 'u', provider: 'wikimedia');
      expect(t.attribution, isNull);
    });
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
