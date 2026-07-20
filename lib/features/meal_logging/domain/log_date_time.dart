/// Seeds an `eatenAt` instant on [logDate]'s calendar day at the current
/// clock time.
///
/// Meal logs are fetched for a day by their `logDate` string, but the fuel
/// timeline sorts them by the full `eatenAt` DateTime. Seeding `eatenAt` from
/// `DateTime.now()` therefore stamps a back-dated log with *today's* date, so
/// it sinks below every activity on the day being viewed instead of landing in
/// its correct chronological slot.
///
/// [logDate] is a `yyyy-MM-dd` string. A malformed value (these can arrive as
/// router `extra` on deep-linkable screens) falls back to [now] rather than
/// throwing, since the throw would surface as a dead screen.
DateTime eatenAtForLogDate(String logDate, {DateTime? now}) {
  final clock = now ?? DateTime.now();
  final parsed = DateTime.tryParse(logDate);
  if (parsed == null) return clock;
  return DateTime(
    parsed.year,
    parsed.month,
    parsed.day,
    clock.hour,
    clock.minute,
  );
}
