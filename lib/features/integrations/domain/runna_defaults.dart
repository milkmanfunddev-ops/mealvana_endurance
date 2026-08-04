/// Constants for the Runna calendar-feed integration.
///
/// Runna exposes no OAuth or JSON API. The athlete copies a personal
/// iCalendar subscription URL out of the Runna app and pastes it into
/// Mealvana; that URL is itself the credential.
///
/// The in-app navigation below is the flow Runna documents at
/// https://support.runna.com/en/articles/8601606-syncing-runna-to-your-calendar-scheduling-your-workouts
/// (verified 2026-08-03). Runna surfaces the raw feed URL only behind the
/// "Other" calendar option — the Apple / Google / Outlook options complete
/// their own connection and never show a link to copy, which is why athletes
/// who go looking for a generic "calendar sync" setting come up empty.
library;

/// Copy shown to the athlete when connecting Runna.
class RunnaDefaults {
  RunnaDefaults._(); // Private constructor - static only

  /// Runna's public help article for calendar syncing.
  ///
  /// Surfaced in the connect dialog so the instructions stay useful even if
  /// Runna renames a screen — this is the canonical source, our copy is not.
  static const supportArticleUrl =
      'https://support.runna.com/en/articles/8601606-syncing-runna-to-your-calendar-scheduling-your-workouts';

  /// Where the feed URL lives in the Runna app, as one sentence.
  ///
  /// Single source of truth: the connect dialog and both failure messages
  /// (bad URL shape, and a 200 that isn't a calendar) all read from here so
  /// they can never drift apart or point at a screen that no longer exists.
  static const feedUrlInstructions =
      'In the Runna app, tap your profile picture (top left) → '
      'Connected Apps & Devices → Connect Calendar → Other, then copy the '
      'calendar URL shown at the top of the screen.';
}
