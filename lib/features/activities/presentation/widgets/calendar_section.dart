import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../calendar/presentation/providers/calendar_view_provider.dart';
import '../../../calendar/presentation/widgets/calendar_view_toggle.dart';
import '../../../calendar/presentation/widgets/calendar_week_view_kyle.dart';
import '../../../calendar/presentation/widgets/calendar_month_view_kyle.dart';
import '../../../calendar/domain/calendar_day_indicators.dart';
import '../../../calendar/presentation/providers/calendar_selected_date_provider.dart';
import '../../../../shared/services/logging_service.dart';

class CalendarSection extends ConsumerWidget {
  const CalendarSection({
    super.key,
    required this.selectedDate,
    required this.dayIndicators,
  });

  final DateTime selectedDate;
  final Map<DateTime, Set<DayIndicatorType>> dayIndicators;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only this widget will rebuild when view mode changes
    final calendarMode = ref.watch(calendarViewProvider);
    
    return Column(
      children: [
        // Calendar view toggle
        CalendarViewToggle(
          selectedMode: calendarMode,
          onModeChanged: (mode) {
            final logger = ref.read(appLoggerProvider);
            logger.info('[CalendarSection] Requesting mode change to: $mode');
            // Use microtask to ensure state update doesn't conflict with build
            Future.microtask(() {
              ref.read(calendarViewProvider.notifier).setView(mode);
            });
          },
        ),
        const SizedBox(height: 8),
        // Calendar (week or month view)
        if (calendarMode == CalendarViewMode.week)
          CalendarWeekViewKyle(
            key: const ValueKey('week_view'),
            selectedDate: selectedDate,
            onDateSelected: (date) {
              ref.read(calendarSelectedDateProvider.notifier).setDate(date);
            },
            dayIndicators: dayIndicators,
          )
        else
          CalendarMonthViewKyle(
            key: const ValueKey('month_view'),
            selectedDate: selectedDate,
            onDateSelected: (date) {
              ref.read(calendarSelectedDateProvider.notifier).setDate(date);
            },
            dayIndicators: dayIndicators,
          ),
      ],
    );
  }
}



