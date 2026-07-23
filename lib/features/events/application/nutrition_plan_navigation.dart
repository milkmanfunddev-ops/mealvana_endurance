import '../../../shared/domain/activity_type.dart';
import '../../activities/domain/activity.dart';
import '../../calendar/domain/event_subtype.dart';
import '../domain/event.dart';

/// Builds the `extra` map passed to the `/distance-pace-gut-entry` route
/// when creating (or continuing to create) a nutrition plan for an [event].
///
/// This is shared by every "Create Nutrition Plan" entry point (event detail
/// action buttons, race day checklist empty state, etc.) so the navigation
/// payload — initial date, distance, pace, activity type, brick leg
/// distances — stays in sync across call sites instead of drifting.
Map<String, dynamic> buildNutritionPlanExtras({
  required Event event,
  Activity? activity,
  String? forUserId,
}) {
  final scheduledDateTime =
      activity?.scheduledDateTime ??
      (event.startTime != null
          ? DateTime.parse(event.startTime!)
          : DateTime.now());

  final activityType = _getActivityTypeForNavigation(event);
  final distanceMiles =
      activity?.distanceMiles ?? _getEventDistanceMiles(event);
  final eventSubtype = _getEventSubtype(event);

  final extras = <String, dynamic>{
    'initialDate': scheduledDateTime,
    'distance': distanceMiles,
    'goalPace': event.goalPaceMinutesPerMile,
    'activityId': activity?.id, // Pass existing activity ID if any
    'eventId': event.id, // Pass event ID to link back after creation
    'activityType': activityType,
    'initialTitle': event.eventName,
    'eventName': event.eventName, // Pass event name for activity title
    if (forUserId != null) 'forUserId': forUserId,
  };

  // For brick events, pass individual leg distances from EventSubtype
  if (activityType == 'brick' && eventSubtype != null) {
    if (eventSubtype.swimDistanceMeters != null) {
      extras['brickSwimDistanceMeters'] = eventSubtype.swimDistanceMeters;
    }
    if (eventSubtype.bikeDistanceMiles != null) {
      extras['brickBikeDistanceMiles'] = eventSubtype.bikeDistanceMiles;
    }
    if (eventSubtype.runDistanceMiles != null) {
      extras['brickRunDistanceMiles'] = eventSubtype.runDistanceMiles;
    }
  }

  return extras;
}

double? _getEventDistanceMiles(Event event) {
  if (event.eventSubtype == null) return null;

  // Look up the EventSubtype to get distance information
  final eventSubtype = EventSubtype.findByName(
    event.eventType.dbValue,
    event.eventSubtype!,
  );

  return eventSubtype?.totalDistanceMiles;
}

/// Map event type to the correct NewActivityScreen tab.
///
/// Single-sport events map directly; multi-sport events (triathlon,
/// duathlon, multisport) map to the brick tab.
String _getActivityTypeForNavigation(Event event) {
  switch (event.eventType) {
    case ActivityType.running:
      return 'running';
    case ActivityType.cycling:
      return 'cycling';
    case ActivityType.swimming:
      return 'swimming';
    case ActivityType.triathlon:
    case ActivityType.duathlon:
    case ActivityType.multisport:
    case ActivityType.brick:
      return 'brick';
    case ActivityType.other:
      // NewActivityScreen has no "other" tab (import-only activities are
      // never manually created here); fall back to the running tab.
      return 'running';
  }
}

/// Look up the EventSubtype for this event (if available).
EventSubtype? _getEventSubtype(Event event) {
  if (event.eventSubtype == null) return null;
  return EventSubtype.findByName(event.eventType.dbValue, event.eventSubtype!);
}
