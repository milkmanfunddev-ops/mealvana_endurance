/// Where a `hand_off` part takes the athlete (mp-265 clause 4): the app's own
/// screen for what they were trying to do in the chat.
library;

import '../../domain/vana_part.dart';
import '../screens/food_screen.dart';

/// A router location, the `extra` the route reads, and whether it replaces the
/// stack (a tab of the shell) instead of being pushed over it.
typedef VanaHandOffDestination = ({
  String location,
  Object? extra,
  bool replace,
});

/// The screen for [part]:
/// * `meal_plan` → the Food tab on Plan, inside the tab shell;
/// * `new_activity` → the new-activity screen, filled from the workout when
///   [VanaHandOffPart.entityId] names one;
/// * `event` → that event's screen, or the new-event form when there is none;
/// * `carb_loading` → the event's screen, where its carb-loading picks are
///   started (the picks screen itself needs the loaded event), or the events
///   list when no event is named.
VanaHandOffDestination vanaHandOffDestination(VanaHandOffPart part) {
  final id = part.entityId;
  return switch (part.target) {
    VanaHandOffTarget.mealPlan => (
      location: foodTabLocation(FoodTab.plan),
      extra: foodTabRequest(),
      replace: true,
    ),
    VanaHandOffTarget.newActivity => (
      location: '/distancepacegut',
      extra: id == null ? null : <String, dynamic>{'activityId': id},
      replace: false,
    ),
    VanaHandOffTarget.event => (
      location: id == null ? '/events/create' : '/events/$id',
      extra: null,
      replace: false,
    ),
    VanaHandOffTarget.carbLoading => (
      location: id == null ? '/events' : '/events/$id',
      extra: null,
      replace: false,
    ),
  };
}
