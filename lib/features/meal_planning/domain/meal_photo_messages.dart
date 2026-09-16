import '../../content/domain/content_keys.dart';

/// What the Meal photos page says when the `meal-photo` function refuses.
///
/// Keyed by the function's own error codes, the way `krogerMessageKey` is: a
/// code with no line of its own is not guessed at, and the caller falls back to
/// the generic server error. Nothing here is user-facing copy — the strings
/// live in the content system.
String? mealPhotoMessageKey(String code) => switch (code) {
  'not_an_image' => ContentKeys.mpPhotosNotAnImage,
  'invalid_input' => ContentKeys.mpPhotosInvalidInput,
  'not_tester' => ContentKeys.mpPhotosNotTester,
  'meal_not_found' => ContentKeys.mpPhotosMealNotFound,
  _ => null,
};
