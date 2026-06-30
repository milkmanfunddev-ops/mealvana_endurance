import 'timeline_node.dart';

/// The segmented filter on the Fuel Timeline screen: `All · Workout · Meals`.
///
/// Gates which [TimelineNode]s appear in the day list and which Add buttons are
/// shown (Meals hides "Add Activity"; Workout hides "Add Food").
enum FuelTimelineFilter {
  all,
  workout,
  meals;

  /// Whether [node] should be visible under this filter.
  bool matches(TimelineNode node) {
    switch (this) {
      case FuelTimelineFilter.all:
        return true;
      case FuelTimelineFilter.workout:
        return node is WorkoutNode;
      case FuelTimelineFilter.meals:
        return node is MealNode;
    }
  }

  /// Whether the "Add Food" affordance is shown under this filter.
  bool get showsAddFood => this != FuelTimelineFilter.workout;

  /// Whether the "Add Activity" affordance is shown under this filter.
  bool get showsAddActivity => this != FuelTimelineFilter.meals;
}
