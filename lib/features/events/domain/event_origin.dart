import 'event.dart';

/// D-2c (integrations-data-display.md, RATIFIED 2026-09-11): a local edit
/// *to a provider-sourced field* flips the row `manual` and exempts it from
/// re-sync overwrite. An edit that touches only fields the athlete owns
/// (location, bib, race distance, registration URL…) keeps the provider
/// origin (ticket 80, round develop-2026-10).
///
/// The provider-sourced fields are the ones the import writes
/// (`ProviderEventImportService`):
///  * TrainingPeaks: event type, name, date, start time, goal time.
///  * Final Surge: those plus goal pace and the linked activity.
///
/// Returns the origin [after] should be stored with. Rows that are not
/// provider rows (`manual`, legacy null) keep their origin.
String? originAfterEdit({required Event before, required Event after}) {
  final origin = before.origin;
  if (origin != 'training_peaks' && origin != 'final_surge') return origin;
  return syncOwnedFieldChanged(before: before, after: after) ? 'manual' : origin;
}

/// Whether [after] differs from [before] in a field the provider sync owns
/// for [before]'s origin. Comparisons survive the edit form's round trip:
/// names are trimmed, start times compare as parsed instants, dates as
/// calendar days, and goal pace to the whole second the form can express.
bool syncOwnedFieldChanged({required Event before, required Event after}) {
  if ((before.eventName?.trim() ?? '') != (after.eventName?.trim() ?? '')) {
    return true;
  }
  if (before.eventType != after.eventType) return true;
  if (before.goalTimeMinutes != after.goalTimeMinutes) return true;
  if (!_sameInstant(before.startTime, after.startTime)) return true;
  final beforeDate = Event.dateFromStartTime(before.startTime) ?? before.eventDate;
  final afterDate = Event.dateFromStartTime(after.startTime) ?? after.eventDate;
  if (!_sameDay(beforeDate, afterDate)) return true;

  if (before.origin == 'final_surge') {
    if (!_samePace(before.goalPaceMinutesPerMile, after.goalPaceMinutesPerMile)) {
      return true;
    }
    if (before.activityId != after.activityId) return true;
  }
  return false;
}

bool _sameInstant(String? a, String? b) {
  final emptyA = a == null || a.isEmpty;
  final emptyB = b == null || b.isEmpty;
  if (emptyA || emptyB) return emptyA == emptyB;
  final pa = DateTime.tryParse(a);
  final pb = DateTime.tryParse(b);
  if (pa == null || pb == null) return a == b;
  return pa.isAtSameMomentAs(pb);
}

bool _sameDay(DateTime? a, DateTime? b) {
  if (a == null || b == null) return a == b;
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

/// The form stores pace as `minutes + seconds / 60` (or `60 / mph` to one
/// decimal for cycling), so an untouched pace can come back a fraction of a
/// second off the stored float. Under a second apart counts as the same.
bool _samePace(double? a, double? b) {
  if (a == null || b == null) return a == b;
  return ((a - b) * 60).abs() < 1.0;
}
