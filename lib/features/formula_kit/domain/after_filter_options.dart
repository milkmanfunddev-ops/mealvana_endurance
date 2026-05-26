/// Where an after-phase formula can be consumed — the primary PR 3 filter
/// axis for the After tab. Values mirror the strings stored in
/// `post_workout_templates.travel_friendliness`.
///
/// Filter semantics (see `FormulaFilterState.afterTravelFriendliness`):
///   - `null` → no filter (everything passes)
///   - A value → only post templates whose `travel_friendliness` matches
///     are shown (templates with null travel_friendliness still pass)
enum TravelFriendliness {
  inBag,
  coolerFriendly,
  homeOnly;

  String get storageValue => switch (this) {
        TravelFriendliness.inBag => 'in_bag',
        TravelFriendliness.coolerFriendly => 'cooler_friendly',
        TravelFriendliness.homeOnly => 'home_only',
      };

  String get displayLabel => switch (this) {
        TravelFriendliness.inBag => 'In bag',
        TravelFriendliness.coolerFriendly => 'Cooler-friendly',
        TravelFriendliness.homeOnly => 'Home only',
      };

  static TravelFriendliness? fromStorageValue(String? value) {
    if (value == null) return null;
    for (final v in TravelFriendliness.values) {
      if (v.storageValue == value) return v;
    }
    return null;
  }
}
