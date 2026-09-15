/// Where a `hand_off` part takes the athlete (mp-265 clause 4): the app's own
/// screen for what they were trying to do in the chat.
library;

import '../../domain/vana_part.dart';

/// A router location, and the `extra` the route reads.
typedef VanaHandOffDestination = ({String location, Object? extra});

/// The screen for [part]:
/// * `meal_plan` → the meal-planning page (`/food`);
/// * `new_activity` → the new-activity screen, filled from the workout when
///   [VanaHandOffPart.entityId] names one;
/// * `event` → that event's screen, or the new-event form when there is none;
/// * `carb_loading` → the event's screen, where its carb-loading picks are
///   started (the picks screen itself needs the loaded event), or the events
///   list when no event is named.
VanaHandOffDestination vanaHandOffDestination(VanaHandOffPart part) {
  final id = part.entityId;
  return switch (part.target) {
    VanaHandOffTarget.mealPlan => (location: '/food', extra: null),
    VanaHandOffTarget.newActivity => (
      location: '/distancepacegut',
      extra: id == null ? null : <String, dynamic>{'activityId': id},
    ),
    VanaHandOffTarget.event => (
      location: id == null ? '/events/create' : '/events/$id',
      extra: null,
    ),
    VanaHandOffTarget.carbLoading => (
      location: id == null ? '/events' : '/events/$id',
      extra: null,
    ),
  };
}
