import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../widgets/calendar_view_toggle.dart';

part 'calendar_view_provider.g.dart';

/// Calendar view mode state provider
///
/// Manages the state of the calendar view mode (week vs month).
/// Used by both the FloatingActionButtonsBar (to toggle view) and
/// the ActivitiesListScreen (to render the appropriate calendar).
///
/// Example usage:
/// ```dart
/// // In FloatingActionButtonsBar:
/// onCalendarTap: () {
///   ref.read(calendarViewNotifierProvider.notifier).toggleView();
/// }
///
/// // In ActivitiesListScreen:
/// final calendarMode = ref.watch(calendarViewNotifierProvider);
/// if (calendarMode == CalendarViewMode.week) {
///   return CalendarWeekViewKyle(...);
/// } else {
///   return CalendarMonthViewKyle(...);
/// }
/// ```
@riverpod
class CalendarViewNotifier extends _$CalendarViewNotifier {
  @override
  CalendarViewMode build() => CalendarViewMode.week;

  /// Toggle between week and month views (week ↔ month)
  void toggleView() {
    state = state == CalendarViewMode.week
        ? CalendarViewMode.month
        : CalendarViewMode.week;
  }

  /// Set a specific view mode
  void setView(CalendarViewMode mode) {
    state = mode;
  }
}
