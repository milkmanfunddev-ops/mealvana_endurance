import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../activities/presentation/providers/activities_controller.dart';
import '../../../carb_loading/presentation/providers/carb_loading_controller.dart';
import '../../../events/presentation/providers/events_controller.dart';
import '../../../../shared/database/app_database.dart' as db;
import '../../domain/calendar_day_indicators.dart';

part 'calendar_day_indicators_provider.g.dart';

/// Per-day calendar dots: which days have an activity, an event, and/or a
/// carb-loading day.
///
/// This is the aggregation that the old `ActivitiesListScreen` computed inline
/// in `_buildDayIndicatorsMap`. When the home tab was swapped to
/// `FuelTimelineScreen`, that screen was left passing `dayIndicators: const {}`
/// to its month view — so events, activities, and carb-loading days stopped
/// showing dots entirely. Extracted here as a single provider so every calendar
/// surface reads the same source of truth rather than re-deriving it (or, as it
/// happened, not deriving it at all).
///
/// Keyed by date-only (year/month/day). Errors in any one source are skipped
/// via `whenData` so a single failing provider doesn't blank all the dots.
@riverpod
Map<DateTime, Set<DayIndicatorType>> calendarDayIndicators(Ref ref) {
  final activitiesState = ref.watch(activitiesControllerProvider);
  final allEventsState = ref.watch(allEventsProvider);
  // Wide window: the calendar can page months in either direction, and this is
  // a cheap local Drift range query. Matches the old screen's ±2-year span.
  final now = DateTime.now();
  final carbLoadingState = ref.watch(
    carbLoadingDaysForRangeProvider(
      now.subtract(const Duration(days: 730)),
      now.add(const Duration(days: 730)),
    ),
  );

  final map = <DateTime, Set<DayIndicatorType>>{};
  void mark(DateTime d, DayIndicatorType type) {
    final key = DateTime(d.year, d.month, d.day);
    map.putIfAbsent(key, () => <DayIndicatorType>{}).add(type);
  }

  activitiesState.whenData((activities) {
    for (final activity in activities) {
      mark(activity.scheduledDateTime, DayIndicatorType.activity);
    }
  });

  allEventsState.whenData((events) {
    for (final event in events) {
      // eventDate is the dedicated date field; it is null for events created
      // without a parseable start time (those don't get a dot).
      final date = event.eventDate;
      if (date != null) mark(date, DayIndicatorType.event);
    }
  });

  carbLoadingState.whenData((carbDays) {
    for (final carbDay in carbDays.cast<db.CarbLoadingDay>()) {
      mark(carbDay.planDate, DayIndicatorType.carbLoading);
    }
  });

  return map;
}
