/// Where a notification lands, decided in exactly one place.
///
/// RULED 2026-09-30: a notification payload carries the INTENT, not the
/// screen — `plan_workout:<activityId>`, not `/plan`. The intent and its copy
/// get ratified once; the screen behind it stays swappable. When the chat
/// surface ships, rerouting an intent is one line in this table, with no
/// payload change, no edge-function redeploy, and nothing to migrate on
/// devices already carrying scheduled notifications.
///
/// That last part is why the indirection is worth a file: a local notification
/// scheduled today fires days later carrying whatever payload it was built
/// with. A payload that names a screen is a decision frozen on the device
/// until it fires.
library;

/// A resolved destination: the route, plus whatever `extra` that route expects.
class NotificationDestination {
  const NotificationDestination(this.location, {this.extra});

  final String location;
  final Object? extra;

  @override
  String toString() => 'NotificationDestination($location, extra: $extra)';

  @override
  bool operator ==(Object other) =>
      other is NotificationDestination &&
      other.location == location &&
      '${other.extra}' == '$extra';

  @override
  int get hashCode => Object.hash(location, '$extra');
}

/// Maps a payload intent to the screen that serves it.
///
/// [intent] is the payload prefix (`carb_event`, `plan_workout`, `reminder`,
/// `activity`), or null for a legacy bare-id payload. [id] is the entity the
/// intent names.
///
/// Unknown and legacy intents fall through to the activity detail screen,
/// which is where every typed payload landed before intents existed — an
/// unrecognised intent from a newer build must still land somewhere sensible
/// rather than dropping the tap on the floor.
NotificationDestination destinationForIntent(String? intent, String id) {
  switch (intent) {
    // G27 carb-load nudge: the Set Up Carb Loading row lives on event details.
    case 'carb_event':
      return NotificationDestination('/events/$id');

    // Night-before long-workout nudge → the CREATE-PLAN flow for that
    // workout, pre-filled (ruled 2026-09-30, IMG_9137). Not activity detail:
    // the nudge only fires when no plan exists, so the landing has to be the
    // interface that makes one.
    //
    // The caller is expected to HYDRATE this extra with the workout's
    // sport/date/name/duration/distance before navigating — see
    // `hydratePlanWorkoutExtra`. This function stays pure, so the id alone is
    // the floor: a blank-but-linked form, never a wrong screen.
    case 'plan_workout':
      return NotificationDestination(
        '/distancepacegut',
        extra: {'activityId': id},
      );

    // Rehearse variant (ruled 2026-09-30): the plan already exists, so this
    // lands on the plan itself rather than the flow that creates one. This is
    // where plan_workout pointed before the create-plan ruling moved it.
    case 'rehearse_plan':
      return NotificationDestination('/plan', extra: {'activityId': id});

    // `recover:<activityId>` goes here — one line, when it is ruled.

    case 'reminder':
    case 'activity':
    default:
      // ActivityDetailScreen owns the conditional redirect into the fuel-log
      // surface, so this deliberately does not push /fuel-log itself.
      return NotificationDestination('/plan', extra: {'activityId': id});
  }
}

/// Fills a `plan_workout` destination's extra with the workout's own data, so
/// the create-plan screen opens PRE-FILLED rather than blank-but-linked.
///
/// WHY THIS IS NOT IN THE TABLE. `NewActivityScreen` does not hydrate itself
/// from an activityId (it self-loads for BRICK only); every pre-filled field
/// comes from the extras its caller passes. That needs an activity lookup,
/// which is async and belongs at the dispatch site — the table stays a pure
/// (intent, id) -> screen decision.
///
/// WHY SO FEW FIELDS, DELIBERATELY. The keys are NOT interchangeable across
/// sports, and a wrong one is worse than a missing one — a missing field is
/// blank and the athlete fills it; a wrong field is a lie they may not notice:
///   - `initialDistance` is read by RUNNING (miles) and SWIMMING (miles, then
///     converted to metres). Cycling's initializer does not read it.
///   - `initialPace` is min/mile and is read by RUNNING — but CYCLING
///     reinterprets it as `60.0 / pace` to get mph. Passing one activity's
///     pace blindly would quietly turn a ride's pace into a speed. So pace is
///     NOT passed at all; the athlete sets it on the screen.
///   - date, title, duration and the sport tab are safe for every sport.
Map<String, dynamic> hydratePlanWorkoutExtra({
  required String activityId,
  required String activityTypeName,
  required DateTime scheduledDateTime,
  required String title,
  int? durationMinutes,
  double? distanceMiles,
}) {
  final sport = _sportTabName(activityTypeName);
  return {
    'activityId': activityId,
    if (sport != null) 'activityType': sport,
    'initialDate': scheduledDateTime,
    'initialTitle': title,
    if (durationMinutes != null && durationMinutes > 0)
      'initialDurationMinutes': durationMinutes,
    // Only where the target sport's initializer actually reads it.
    if (distanceMiles != null &&
        distanceMiles > 0 &&
        (sport == 'running' || sport == 'swimming'))
      'distance': distanceMiles,
  };
}

/// The four strings `NewActivityScreen._getSportTabFromActivityType` accepts.
/// Anything else returns null and the screen keeps its default tab rather than
/// being sent to a sport the workout is not.
String? _sportTabName(String activityTypeName) {
  switch (activityTypeName) {
    case 'running':
    case 'cycling':
    case 'swimming':
    case 'brick':
      return activityTypeName;
    default:
      return null;
  }
}
