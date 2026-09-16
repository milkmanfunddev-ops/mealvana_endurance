import 'meal_photo.dart';
import 'meal_ref.dart';
import 'plan_meal.dart';

/// The picture slot each card in one list draws, in list order. An empty slot
/// is a card that draws no picture at all.
///
/// Two Meals in one list never show the same photograph, or the list reads as
/// though it is repeating itself. The first Meal to wear a photograph keeps
/// it; a later one shows nothing, which is what a Meal without a photo shows
/// anyway (ADR 0003).
///
/// Nothing is stored: the same list always resolves the same way, and another
/// list, or the recipe screen, is unaffected. A list that pages keeps what its
/// earlier cards drew, because the first Meal to wear a photograph keeps it.
List<MealPhotoSlot> photosForList(List<MealRef> meals) =>
    _slots(meals.map((m) => m.photo)).toList(growable: false);

/// What each row of one plan draws where a picture goes, keyed by plan-meal
/// id — the plan tile, the plan bar's tile and the review sheet's row all
/// read the same answer, so one meal looks the same on all three.
///
/// A plan meal carries no picture of its own: it stores its name, slot and
/// icon key. The photograph is the *library* Meal's current one, looked up
/// here from [photosByMealId] by `library_meal_id`, so a photo added to a
/// Meal later reaches plans already made and nothing is ever copied onto the
/// plan row (ADR 0003, spec `Reads`).
///
/// A row with nothing to look up draws nothing: a saved-only meal with no
/// library link, a Meal that has left the library, or one that simply has no
/// photo. A saved row that *is* matched to the library shows that Meal's
/// photo, the same rule `search_meals` applies to a saved Meal (story 11), so
/// it looks like the library row beside it.
///
/// **A plan does not suppress a repeated photograph, the way a list of cards
/// does.** Every row shows its own Meal's photo: a Meal shows the same picture
/// wherever it is met (story 10), and a plan holding one Meal twice is
/// ordinary — that is what batch cooking is — so blanking the second row would
/// hide a photograph the Meal really has.
Map<String, MealPhotoSlot> planPhotoSlotsFor(
  List<PlanMeal> meals,
  Map<String, MealPhoto> photosByMealId,
) => {
  for (final meal in meals)
    meal.id: MealPhotoSlot(photosByMealId[meal.libraryMealId]),
};

/// The one no-repeat rule, over photographs already resolved in list order.
Iterable<MealPhotoSlot> _slots(Iterable<MealPhoto?> photos) {
  final shown = <String>{};
  final out = <MealPhotoSlot>[];
  for (final photo in photos) {
    if (photo == null || photo.identity.any(shown.contains)) {
      out.add(MealPhotoSlot.empty);
      continue;
    }
    shown.addAll(photo.identity);
    out.add(MealPhotoSlot(photo));
  }
  return out;
}
