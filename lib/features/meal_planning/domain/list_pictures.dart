import 'meal_photo.dart';
import 'meal_ref.dart';

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
List<MealPhotoSlot> photosForList(List<MealRef> meals) {
  final shown = <String>{};
  final out = <MealPhotoSlot>[];
  for (final meal in meals) {
    final photo = meal.photo;
    if (photo == null || photo.identity.any(shown.contains)) {
      out.add(MealPhotoSlot.empty);
      continue;
    }
    shown.addAll(photo.identity);
    out.add(MealPhotoSlot(photo));
  }
  return out;
}
