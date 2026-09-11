// meal-image-mosaic.md v1 (PROPOSED) — MIM-6, attribution travels with the
// image:
//   * each credit names the photographer and the platform, in the wording the
//     provider asks for, and opens the source when tapped
//   * a picture credits every distinct photograph it shows, once each
//   * Unsplash links carry the referral parameters its API terms require
//
// Mutation check: drop "on Unsplash", link the photographer to nothing, or
// credit a photograph twice → the matching test fails.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/data/meal_image_mosaic.dart';

/// The span of [credit] that reads [text], so a test can ask where it goes.
KyleCreditSpan _span(KyleImageCredit credit, String text) =>
    credit.spans.singleWhere((s) => s.text == text);

void main() {
  group('wording and links per provider', () {
    test('Unsplash names the photographer and Unsplash, both linked', () {
      const tile = KyleMealImageTile(
        url: 'https://images.unsplash.com/photo-1.jpg',
        creator: 'Annie Spratt',
        license: 'Unsplash',
        sourceUrl: 'https://unsplash.com/photos/oats-abc123',
        provider: 'unsplash',
      );
      final credit = tile.credit!;

      expect(credit.text, 'Photo by Annie Spratt on Unsplash');
      final who = _span(credit, 'Annie Spratt').link!;
      expect(who.host, 'unsplash.com');
      expect(who.path, '/photos/oats-abc123');
      expect(who.queryParameters['utm_medium'], 'referral');
      expect(who.queryParameters['utm_source'], isNotEmpty);
      final platform = _span(credit, 'Unsplash').link!;
      expect(platform.host, 'unsplash.com');
      expect(platform.queryParameters['utm_medium'], 'referral');
    });

    test('Pexels names the photographer and links back to Pexels', () {
      const tile = KyleMealImageTile(
        url: 'https://images.pexels.com/1346342.jpeg',
        creator: 'Alisha Mishra',
        license: 'Pexels',
        sourceUrl: 'https://www.pexels.com/photo/vegetable-shake-1346342/',
        provider: 'pexels',
      );
      final credit = tile.credit!;

      expect(credit.text, 'Photo by Alisha Mishra on Pexels');
      expect(
        _span(credit, 'Alisha Mishra').link,
        Uri.parse('https://www.pexels.com/photo/vegetable-shake-1346342/'),
      );
      expect(_span(credit, 'Pexels').link?.host, 'www.pexels.com');
    });

    test('a stock photo with no photographer still names the platform', () {
      const tile = KyleMealImageTile(
        url: 'u',
        sourceUrl: 'https://unsplash.com/photos/x',
        provider: 'unsplash',
      );
      expect(tile.credit!.text, 'Photo on Unsplash');
    });

    test('Wikimedia Commons names creator, platform and licence', () {
      const tile = KyleMealImageTile(
        url: 'https://upload.wikimedia.org/avocado.jpg',
        creator: 'Jami430',
        license: 'cc-by-sa-4.0',
        sourceUrl:
            'https://commons.wikimedia.org/wiki/File:Avocado_toast_with_sesame_seeds.jpg',
        provider: 'wikimedia',
      );
      final credit = tile.credit!;

      expect(
        credit.text,
        'Photo by Jami430 on Wikimedia Commons (CC BY-SA 4.0)',
      );
      expect(
        _span(credit, 'Jami430').link?.path,
        '/wiki/File:Avocado_toast_with_sesame_seeds.jpg',
      );
    });

    test('licence strings are shown one way whatever way they were stored', () {
      String? licence(String raw) => KyleMealImageTile(
        url: 'u',
        creator: 'A',
        license: raw,
        provider: 'wikimedia',
      ).credit!.text.split('(').last.replaceAll(')', '');

      expect(licence('CC BY-SA 4.0'), 'CC BY-SA 4.0');
      expect(licence('cc-by-sa-3.0'), 'CC BY-SA 3.0');
      expect(licence('CC by 2.0'), 'CC BY 2.0');
      expect(licence('cc0'), 'CC0');
      expect(licence('cc0-or-pd'), 'public domain');
    });

    test('Openverse credits the site the photograph lives on', () {
      const tile = KyleMealImageTile(
        url: 'u',
        creator: 'Sebastiaan ter Burg',
        license: 'CC by 2.0',
        sourceUrl: 'https://www.flickr.com/photos/31013861@N00/35654289166',
        provider: 'openverse',
      );
      expect(
        tile.credit!.text,
        'Photo by Sebastiaan ter Burg on Flickr (CC BY 2.0)',
      );
    });

    test('a photograph from a recipe page names and links that site', () {
      const tile = KyleMealImageTile(
        url: 'https://thishealthykitchen.com/wp/sweet-potatoes.jpg',
        creditLine: 'thishealthykitchen.com',
        sourceUrl: 'https://www.thishealthykitchen.com/loaded-sweet-potatoes/',
      );
      final credit = tile.credit!;

      expect(credit.text, 'Photo on thishealthykitchen.com');
      expect(
        _span(credit, 'thishealthykitchen.com').link?.path,
        '/loaded-sweet-potatoes/',
      );
    });

    test(
      'a stored credit line is used when nothing structured came with it',
      () {
        // `search_meals` sends a dish photo's url and its credit line only.
        const tile = KyleMealImageTile(
          url: 'https://upload.wikimedia.org/oats.jpg',
          creditLine: 'Vegan Feast Catering · CC-BY-2.0 · Wikimedia Commons',
        );
        expect(
          tile.credit!.text,
          'Vegan Feast Catering · CC-BY-2.0 · Wikimedia Commons',
        );
      },
    );

    test('nothing to credit is null, never an empty line', () {
      const tile = KyleMealImageTile(url: 'u');
      expect(tile.credit, isNull);
    });
  });

  group('a picture credits every distinct photograph once', () {
    KyleMealImageTile pexels(String id, String who) => KyleMealImageTile(
      url: 'https://images.pexels.com/$id.jpeg',
      creator: who,
      sourceUrl: 'https://www.pexels.com/photo/$id/',
      provider: 'pexels',
    );

    test('a mosaic credits each of its photographers', () {
      final credits = KyleImageCredit.forPicture(KyleMealImageMode.mosaic, [
        pexels('1', 'Ella Olsson'),
        pexels('2', 'Alisha Mishra'),
        pexels('3', 'Jane Doe'),
      ]);
      expect(credits.map((c) => c.text), [
        'Photo by Ella Olsson on Pexels',
        'Photo by Alisha Mishra on Pexels',
        'Photo by Jane Doe on Pexels',
      ]);
    });

    test('one photograph behind two cells is credited once', () {
      final credits = KyleImageCredit.forPicture(KyleMealImageMode.mosaic, [
        pexels('1', 'Ella Olsson'),
        pexels('1', 'Ella Olsson'),
        pexels('2', 'Alisha Mishra'),
      ]);
      expect(credits, hasLength(2));
    });

    test('two photographs by one photographer are two credits', () {
      // Each links to its own photograph, so neither can stand for the other.
      final credits = KyleImageCredit.forPicture(KyleMealImageMode.mosaic, [
        pexels('1', 'Ella Olsson'),
        pexels('2', 'Ella Olsson'),
      ]);
      expect(credits.map((c) => c.spans[1].link?.path), [
        '/photo/1/',
        '/photo/2/',
      ]);
    });

    test('only the photographs shown are credited', () {
      expect(
        KyleImageCredit.forPicture(KyleMealImageMode.dish, [
          pexels('1', 'A'),
          pexels('2', 'B'),
        ]).map((c) => c.text),
        ['Photo by A on Pexels'],
      );
      expect(
        KyleImageCredit.forPicture(KyleMealImageMode.mosaic, [
          for (var i = 1; i <= 5; i++) pexels('$i', 'P$i'),
        ]),
        hasLength(4),
      );
      expect(
        KyleImageCredit.forPicture(KyleMealImageMode.none, [pexels('1', 'A')]),
        isEmpty,
      );
    });

    test('a photograph with nothing to credit is skipped', () {
      final credits = KyleImageCredit.forPicture(KyleMealImageMode.mosaic, [
        const KyleMealImageTile(url: 'bare'),
        pexels('2', 'Alisha Mishra'),
      ]);
      expect(credits.map((c) => c.text), ['Photo by Alisha Mishra on Pexels']);
    });
  });

  group('MealImageCredits', () {
    Future<List<Uri>> pump(
      WidgetTester tester,
      List<KyleMealImageTile> tiles, {
      KyleMealImageMode mode = KyleMealImageMode.mosaic,
    }) async {
      final opened = <Uri>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: MealImageCredits(
                mode: mode,
                tiles: tiles,
                onOpen: opened.add,
              ),
            ),
          ),
        ),
      );
      return opened;
    }

    const annie = KyleMealImageTile(
      url: 'https://images.unsplash.com/1.jpg',
      creator: 'Annie Spratt',
      sourceUrl: 'https://unsplash.com/photos/oats-abc123',
      provider: 'unsplash',
    );
    const jami = KyleMealImageTile(
      url: 'https://upload.wikimedia.org/avocado.jpg',
      creator: 'Jami430',
      license: 'CC BY-SA 4.0',
      sourceUrl: 'https://commons.wikimedia.org/wiki/File:Avocado.jpg',
      provider: 'wikimedia',
    );

    testWidgets('shows every credit behind the picture', (tester) async {
      await pump(tester, [annie, jami]);
      expect(
        find.textContaining(
          'Photo by Annie Spratt on Unsplash · '
          'Photo by Jami430 on Wikimedia Commons (CC BY-SA 4.0)',
          findRichText: true,
        ),
        findsOneWidget,
      );
    });

    testWidgets('tapping a photographer opens that photograph', (tester) async {
      final opened = await pump(tester, [annie, jami]);

      await tester.tapOnText(find.textRange.ofSubstring('Jami430'));
      expect(opened.single.path, '/wiki/File:Avocado.jpg');

      await tester.tapOnText(find.textRange.ofSubstring('Annie Spratt'));
      expect(opened.last.path, '/photos/oats-abc123');
    });

    testWidgets('tapping Unsplash opens Unsplash', (tester) async {
      final opened = await pump(tester, [annie]);

      await tester.tapOnText(find.textRange.ofSubstring('Unsplash'));
      expect(opened.single.host, 'unsplash.com');
      expect(opened.single.path, anyOf('', '/'));
    });

    testWidgets('nothing creditable renders nothing', (tester) async {
      await pump(tester, [const KyleMealImageTile(url: 'bare')]);
      expect(find.byType(RichText), findsNothing);
    });
  });
}
