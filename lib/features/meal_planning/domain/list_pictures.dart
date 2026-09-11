import 'meal_image.dart';
import 'meal_ref.dart';

/// The picture each card in one list draws, in list order.
///
/// Two Meals in one list never show the same photograph, or the list reads as
/// though it is repeating itself. The first Meal to wear a photograph keeps
/// it; a later one falls back to its Mosaic if it carries one, otherwise to
/// its icon. Only a photograph standing for the whole Meal counts — a Dish
/// photo or a one-thing Meal's Tile. Mosaic cells are ingredients, shared
/// across the library by design, and a grid reads as a Meal's parts.
///
/// Nothing is stored: the same list always resolves the same way, and another
/// list, or the detail screen, is unaffected. A list that pages keeps what its
/// earlier cards drew, because the first Meal to wear a photograph keeps it.
List<MealPicture> picturesForList(List<MealRef> meals) {
  final shown = <String>{};
  final out = <MealPicture>[];
  for (final meal in meals) {
    final picture = meal.picture;
    if (picture.mode == MealImageMode.mosaic || picture.tiles.isEmpty) {
      out.add(picture);
      continue;
    }
    final photograph = _identity(picture.tiles.first);
    if (photograph.any(shown.contains)) {
      out.add(
        meal.imageTiles.length >= 2
            ? MealPicture(MealImageMode.mosaic, meal.imageTiles)
            : MealPicture.none,
      );
    } else {
      shown.addAll(photograph);
      out.add(picture);
    }
  }
  return out;
}

/// What makes two photographs the same one. A mirrored photograph is stored
/// once per Meal, so the page it came from is what says so; a stock CDN's
/// resize parameters are not part of the picture. Keep in step with
/// `pictureIdentity` in `scripts/meal-images/lib/ladder.mjs` and pass 10's
/// "already in use" check, which key a photograph the same way.
Set<String> _identity(MealImageTile t) => {
  t.url.split('?').first,
  if (t.sourceUrl?.trim() case final page? when page.isNotEmpty) page,
};
