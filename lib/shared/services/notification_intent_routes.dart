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

    // Night-before long-workout nudge: tomorrow's workout.
    // The screen is the default, not a ruling — it reroutes by editing this
    // line once the chat surface exists.
    case 'plan_workout':
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
