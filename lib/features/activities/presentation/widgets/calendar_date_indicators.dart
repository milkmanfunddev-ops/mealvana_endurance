import 'package:flutter/material.dart';
import '../../domain/activity.dart';
import '../../../events/domain/event.dart';
import '../../../../shared/database/app_database.dart' as db;

/// Widget that displays indicator dots for events, activities, and carb loading days.
class CalendarDateIndicators extends StatelessWidget {
  const CalendarDateIndicators({
    super.key,
    required this.date,
    required this.activities,
    required this.events,
    required this.carbLoadingDays,
  });

  final DateTime date;
  final List<Activity> activities;
  final List<Event> events;
  final List<db.CarbLoadingDay> carbLoadingDays;

  static const Color _eventColor = Color(0xFFE91E63); // Pink for events
  static const Color _activityColor = Color(0xFF2196F3); // Blue for activities
  static const Color _carbDayColor = Color(0xFFFF9800); // Orange for carb loading

  @override
  Widget build(BuildContext context) {
    final hasEvent = _hasEventOnDate();
    final hasActivity = _hasActivityOnDate();
    final hasCarbDay = _hasCarbDayOnDate();

    if (!hasEvent && !hasActivity && !hasCarbDay) {
      return const SizedBox(height: 4);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (hasEvent) _buildIndicatorDot(_eventColor),
        if (hasActivity) _buildIndicatorDot(_activityColor),
        if (hasCarbDay) _buildIndicatorDot(_carbDayColor),
      ],
    );
  }

  bool _hasEventOnDate() {
    return events.any((event) {
      if (event.startTime != null) {
        try {
          final eventDate = DateTime.parse(event.startTime!);
          return _isSameDay(eventDate, date);
        } catch (e) {
          return false;
        }
      }
      return false;
    });
  }

  bool _hasActivityOnDate() {
    return activities.any((activity) => _isSameDay(activity.scheduledDateTime, date));
  }

  bool _hasCarbDayOnDate() {
    return carbLoadingDays.any((carbDay) => _isSameDay(carbDay.planDate, date));
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildIndicatorDot(Color color) {
    return Container(
      width: 5,
      height: 5,
      margin: const EdgeInsets.symmetric(horizontal: 1),
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
