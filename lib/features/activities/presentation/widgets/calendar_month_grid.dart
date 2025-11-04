import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mealvana_endurance/theme/app_theme.dart';
import '../../domain/activity.dart';
import '../../../events/domain/event.dart';
import '../../../../shared/database/app_database.dart' as db;
import 'calendar_date_indicators.dart';

/// Calendar month grid view widget.
class CalendarMonthGrid extends StatelessWidget {
  const CalendarMonthGrid({
    super.key,
    required this.visibleMonthDate,
    required this.selectedDate,
    required this.onDateSelected,
    required this.activitiesState,
    required this.eventsState,
    required this.carbLoadingState,
  });

  final DateTime visibleMonthDate;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final AsyncValue<List<Activity>> activitiesState;
  final AsyncValue<List<Event>> eventsState;
  final AsyncValue<List<dynamic>> carbLoadingState;

  @override
  Widget build(BuildContext context) {
    return activitiesState.when(
      data: (activities) {
        final events = eventsState.maybeWhen(
          data: (e) => e,
          orElse: () => <Event>[],
        );
        final carbLoadingDays = carbLoadingState.maybeWhen(
          data: (days) => days.cast<db.CarbLoadingDay>(),
          orElse: () => <db.CarbLoadingDay>[],
        );

        final firstDayOfMonth = DateTime(visibleMonthDate.year, visibleMonthDate.month, 1);
        final lastDayOfMonth = DateTime(visibleMonthDate.year, visibleMonthDate.month + 1, 0);

        final startDate = firstDayOfMonth.subtract(Duration(days: (firstDayOfMonth.weekday - 1) % 7));
        final endDate = lastDayOfMonth.add(Duration(days: (7 - lastDayOfMonth.weekday) % 7));

        final totalDays = endDate.difference(startDate).inDays + 1;
        final weekCount = (totalDays / 7).ceil();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            children: [
              _buildWeekdayHeaders(context),
              const SizedBox(height: 8),
              ...List.generate(weekCount, (weekIndex) {
                return _buildWeekRow(
                  context,
                  startDate,
                  weekIndex,
                  activities,
                  events,
                  carbLoadingDays,
                );
              }),
            ],
          ),
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (_, __) => const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text('Error loading calendar'),
        ),
      ),
    );
  }

  Widget _buildWeekdayHeaders(BuildContext context) {
    return Row(
      children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
          .map((day) => Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildWeekRow(
    BuildContext context,
    DateTime startDate,
    int weekIndex,
    List<Activity> activities,
    List<Event> events,
    List<db.CarbLoadingDay> carbLoadingDays,
  ) {
    return Row(
      children: List.generate(7, (dayIndex) {
        final date = startDate.add(Duration(days: weekIndex * 7 + dayIndex));
        final isCurrentMonth = date.month == visibleMonthDate.month;
        final isSelected = _isSameDay(date, selectedDate);
        final isToday = _isSameDay(date, DateTime.now());

        return Expanded(
          child: GestureDetector(
            onTap: () => onDateSelected(date),
            child: Container(
              height: 50,
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: isSelected
                    ? Theme.of(context).primaryColor
                    : isToday
                        ? const Color(0xFFFFC107).withValues(alpha: 0.2)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isToday
                      ? const Color(0xFFFFC107)
                      : isSelected
                          ? Theme.of(context).primaryColor
                          : Colors.transparent,
                  width: isToday || isSelected ? 2 : 0,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${date.day}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isCurrentMonth ? FontWeight.w600 : FontWeight.normal,
                      color: isSelected
                          ? AppTheme.baseCream
                          : isCurrentMonth
                              ? Colors.black
                              : Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 2),
                  CalendarDateIndicators(
                    date: date,
                    activities: activities,
                    events: events,
                    carbLoadingDays: carbLoadingDays,
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
