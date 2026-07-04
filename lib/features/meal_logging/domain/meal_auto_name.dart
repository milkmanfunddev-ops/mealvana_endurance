import 'meal_component.dart';

/// Derives a human-readable meal name from its components.
///
/// - 0 components → `''` (caller decides the fallback/placeholder).
/// - 1 → the item's name, e.g. "Banana".
/// - 2 → "A and B", e.g. "Banana and peanut butter".
/// - 3 → "A, B and C".
/// - 4+ → "A, B +N", where `N` is the count of additional components beyond
///   the first two shown (e.g. 5 components → "A, B +3").
///
/// Used by `DraftMealController` to keep the draft's name in sync with its
/// component list unless the user has manually edited the name
/// (`DraftMealState.nameManuallySet`) — mirrors the activity-title auto-name
/// pattern used elsewhere in the app (`activityTitleManuallySet` /
/// `ActivityNameField`).
///
/// Also used directly by quick-log flows (a single quick-logged food's name
/// is just [deriveMealName] applied to its one-item component list, which
/// collapses to the item's own name).
String deriveMealName(List<MealComponent> components) {
  if (components.isEmpty) return '';
  final names = components.map((c) => c.name).toList();
  switch (names.length) {
    case 1:
      return names[0];
    case 2:
      return '${names[0]} and ${names[1]}';
    case 3:
      return '${names[0]}, ${names[1]} and ${names[2]}';
    default:
      final extra = names.length - 2;
      return '${names[0]}, ${names[1]} +$extra';
  }
}
