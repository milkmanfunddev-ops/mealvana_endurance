/// How far off an event is, in words, for every countdown surface (Event
/// Details' badge, the Timeline's upcoming-event card and the Kyle card).
///
/// One function so the three never drift again: each used to floor whole
/// months, so an event 58 days out read "1 month away" (testing-wave
/// 117-007). Days are compared at day level, ignoring the time of day.
///
/// Bands: under a week in days; up to about nine weeks in weeks, rounded to
/// the nearest week (58 days reads "8 weeks away"); beyond that in months,
/// rounded to the nearest average month (30.44 days), so 63 days is
/// "2 months away" and 45 days stays "6 weeks away".
String eventCountdownText(
  DateTime eventDate, {
  required DateTime today,
  String pastLabel = 'Event passed',
  String oneDayLabel = 'Tomorrow',
}) {
  final todayDateOnly = DateTime(today.year, today.month, today.day);
  final eventDateOnly = DateTime(
    eventDate.year,
    eventDate.month,
    eventDate.day,
  );
  final days = eventDateOnly.difference(todayDateOnly).inDays;

  if (days < 0) return pastLabel;
  if (days == 0) return 'Today!';
  if (days == 1) return oneDayLabel;
  if (days < 7) return '$days days away';
  if (days < _weeksCeilingDays) {
    final weeks = (days / 7).round();
    return '$weeks ${weeks == 1 ? 'week' : 'weeks'} away';
  }
  final months = (days / _averageMonthDays).round();
  return '$months ${months == 1 ? 'month' : 'months'} away';
}

/// Nine weeks: from here on the count is in months.
const int _weeksCeilingDays = 63;

/// The Gregorian mean month.
const double _averageMonthDays = 30.44;
