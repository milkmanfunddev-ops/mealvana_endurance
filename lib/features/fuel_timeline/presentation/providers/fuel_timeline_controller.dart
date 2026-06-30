import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../activities/presentation/providers/activities_controller.dart';
import '../../../calendar/presentation/providers/calendar_selected_date_provider.dart';
import '../../../daily_macros/presentation/providers/daily_macros_controller.dart';
import '../../../meal_logging/presentation/providers/meal_log_providers.dart';
import '../../application/day_timeline_assembler.dart';

part 'fuel_timeline_controller.g.dart';

/// Assembles the Fuel Timeline day view from existing data sources.
///
/// Composes (does not refetch) the calendar's selected date, the day's macro
/// targets, the day's meal logs + consumed totals, and the day's activities,
/// then runs the pure [DayTimelineAssembler]. Produces the full (unfiltered)
/// node list + energy summary; the screen applies the active filter for
/// display, so toggling the filter never re-runs this provider.
///
/// Per-activity burn (`burnByActivityId`) is wired in a later phase from the
/// per-activity macro targets; until then the energy summary's workout burn is
/// zero and only resting + daily-activity energy is shown.
@riverpod
Future<DayTimelineResult> fuelTimelineDay(Ref ref) async {
  final selectedDate = ref.watch(calendarSelectedDateProvider);
  final dateStr = _ymd(selectedDate);

  final macrosState = await ref.watch(dailyMacrosControllerProvider.future);
  final meals = await ref.watch(mealLogsForDateProvider(dateStr).future);
  final consumed = await ref.watch(
    consumedTotalsForDateProvider(dateStr).future,
  );
  final allActivities = await ref.watch(activitiesControllerProvider.future);

  final dayActivities = allActivities
      .where((a) {
        final d = a.scheduledDateTime;
        return d.year == selectedDate.year &&
            d.month == selectedDate.month &&
            d.day == selectedDate.day;
      })
      .toList(growable: false);

  const assembler = DayTimelineAssembler();
  return assembler.assemble(
    selectedDate: selectedDate,
    now: DateTime.now(),
    meals: meals,
    activities: dayActivities,
    targets: macrosState.dailyMacros,
    consumed: consumed,
  );
}

/// Format a [DateTime] as `'yyyy-MM-dd'` (matches the meal-log date key).
String _ymd(DateTime d) {
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}-$m-$day';
}
