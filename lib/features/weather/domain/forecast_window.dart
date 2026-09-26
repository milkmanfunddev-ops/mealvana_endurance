/// The days a forecast exists for: today through [daysAhead] days out, the
/// range `get-weather-forecast` serves as a forecast
/// (supabase/functions/get-weather-forecast/index.ts; earlier days come from
/// the historical archive).
///
/// Location is asked for only when the forecast can matter (Lee, 2026-09-26,
/// Finding 100-004): opening a finished workout used to raise the iOS
/// location prompt, spending it on a screen where no forecast applies.
abstract final class ForecastWindow {
  static const int daysAhead = 16;

  /// True when [activityDate]'s day is today or within [daysAhead] days.
  static bool covers(DateTime activityDate, {DateTime? now}) {
    final today = _day(now ?? DateTime.now());
    final diff = _day(activityDate).difference(today).inDays;
    return diff >= 0 && diff <= daysAhead;
  }

  static DateTime _day(DateTime t) => DateTime(t.year, t.month, t.day);
}
