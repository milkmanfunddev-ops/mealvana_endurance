import '../../../../shared/widgets/kyle_design/data/meal_image_mosaic.dart'
    show KyleImageCredit, KyleMealImageMode, KyleMealImageTile;
import '../../domain/meal_image.dart';

/// The domain picture as the Meal Image Mosaic component takes it. The shared
/// widget keeps its own types so it stays independent of this feature; the
/// card and the detail screen both cross over here.
KyleMealImageMode kyleImageMode(MealImageMode mode) => switch (mode) {
  MealImageMode.dish => KyleMealImageMode.dish,
  MealImageMode.mosaic => KyleMealImageMode.mosaic,
  MealImageMode.tile => KyleMealImageMode.tile,
  MealImageMode.none => KyleMealImageMode.none,
};

List<KyleMealImageTile> kyleImageTiles(List<MealImageTile> tiles) => [
  for (final t in tiles)
    KyleMealImageTile(
      url: t.url,
      name: t.name,
      license: t.license,
      creator: t.creator,
      sourceUrl: t.sourceUrl,
      provider: t.provider,
      creditLine: t.credit,
    ),
];

/// Every distinct photograph credit behind a picture, as one line for screen
/// readers. Null when nothing is creditable.
String? mealPictureCredit(MealImageMode mode, List<MealImageTile> tiles) {
  final credits = KyleImageCredit.forPicture(
    kyleImageMode(mode),
    kyleImageTiles(tiles),
  );
  return credits.isEmpty ? null : credits.map((c) => c.text).join(' · ');
}
