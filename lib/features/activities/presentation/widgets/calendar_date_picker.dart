import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mealvana_endurance/theme/app_theme.dart';
import '../../domain/activity.dart';
import '../../../events/domain/event.dart';
import '../providers/activities_controller.dart';
import '../../../events/presentation/providers/events_controller.dart';
import '../../../carb_loading/presentation/providers/carb_loading_controller.dart';
import '../../../../shared/database/app_database.dart' as db;
import 'calendar_date_indicators.dart';
import 'calendar_month_grid.dart';

enum CalendarViewMode { week, month }

/// Reusable calendar date picker widget for selecting dates and viewing activities.
///
/// Features:
/// - Week view with horizontal scrollable dates
/// - Month grid view with calendar layout
/// - Event/Activity/Carb Loading day indicators
/// - Today button when scrolled away from current date
/// - Month navigation and date picker
class CalendarDatePicker extends ConsumerStatefulWidget {
  const CalendarDatePicker({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  @override
  ConsumerState<CalendarDatePicker> createState() => _CalendarDatePickerState();
}

class _CalendarDatePickerState extends ConsumerState<CalendarDatePicker> {
  late DateTime _visibleMonthDate;
  late ScrollController _dateScrollController;
  late DateTime _referenceDate; // Cache the reference date to prevent drift
  bool _showTodayButton = false;
  CalendarViewMode _viewMode = CalendarViewMode.week;

  // Cache the date range to avoid creating new provider instances on every rebuild
  late final DateTime _queryStartDate = DateTime.now().subtract(const Duration(days: 365));
  late final DateTime _queryEndDate = DateTime.now().add(const Duration(days: 730));

  static const int _totalDays = 730;
  static const int _centerIndex = 365;
  static const double _dateItemWidth = 68.0; // 60 (container) + 4*2 (horizontal margin)

  @override
  void initState() {
    super.initState();
    // Cache today's date (normalized to midnight) to use as reference point
    final now = DateTime.now();
    _referenceDate = DateTime(now.year, now.month, now.day);
    _visibleMonthDate = widget.selectedDate;
    _dateScrollController = ScrollController(
      initialScrollOffset: _centerIndex * _dateItemWidth,
    );
    _dateScrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _dateScrollController.removeListener(_onScroll);
    _dateScrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final currentOffset = _dateScrollController.offset;
    final centerOffset = _centerIndex * _dateItemWidth;
    final distanceFromCenter = (currentOffset - centerOffset).abs();
    final shouldShow = distanceFromCenter > (_dateItemWidth * 3);

    final visibleCenterIndex = (currentOffset / _dateItemWidth).round();
    final visibleCenterDate = _getScrollableDate(visibleCenterIndex);

    if (!_isSameMonth(visibleCenterDate, _visibleMonthDate) || shouldShow != _showTodayButton) {
      setState(() {
        _visibleMonthDate = visibleCenterDate;
        _showTodayButton = shouldShow;
      });
    }
  }

  bool _isSameMonth(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _scrollToToday() {
    if (_viewMode == CalendarViewMode.week) {
      _dateScrollController.animateTo(
        _centerIndex * _dateItemWidth,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
    setState(() {
      _visibleMonthDate = _referenceDate;
    });
    widget.onDateSelected(_referenceDate);
  }

  Future<void> _showMonthYearPicker() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _visibleMonthDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );

    if (picked != null) {
      setState(() {
        _visibleMonthDate = picked;
        if (_viewMode == CalendarViewMode.week) {
          final daysFromToday = picked.difference(_referenceDate).inDays;
          _dateScrollController.animateTo(
            (_centerIndex + daysFromToday) * _dateItemWidth,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
      widget.onDateSelected(picked);
    }
  }

  void _navigateToPreviousMonth() {
    setState(() {
      final newMonth = DateTime(_visibleMonthDate.year, _visibleMonthDate.month - 1, 1);
      _visibleMonthDate = newMonth;
      if (_viewMode == CalendarViewMode.week) {
        final daysFromToday = newMonth.difference(_referenceDate).inDays;
        _dateScrollController.animateTo(
          (_centerIndex + daysFromToday) * _dateItemWidth,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
    widget.onDateSelected(_visibleMonthDate);
  }

  void _navigateToNextMonth() {
    setState(() {
      final newMonth = DateTime(_visibleMonthDate.year, _visibleMonthDate.month + 1, 1);
      _visibleMonthDate = newMonth;
      if (_viewMode == CalendarViewMode.week) {
        final daysFromToday = newMonth.difference(_referenceDate).inDays;
        _dateScrollController.animateTo(
          (_centerIndex + daysFromToday) * _dateItemWidth,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    });
    widget.onDateSelected(_visibleMonthDate);
  }

  DateTime _getScrollableDate(int index) {
    // Calculate days offset from center
    final daysOffset = index - _centerIndex;
    // Add offset to reference date
    // Using DateTime.utc to avoid any timezone issues
    final year = _referenceDate.year;
    final month = _referenceDate.month;
    final day = _referenceDate.day;
    return DateTime(year, month, day + daysOffset);
  }

  @override
  Widget build(BuildContext context) {
    final activitiesState = ref.watch(activitiesControllerProvider);
    final eventsState = ref.watch(eventsControllerProvider);
    final carbLoadingState = ref.watch(carbLoadingDaysForRangeProvider(
      _queryStartDate,
      _queryEndDate,
    ));

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.baseCream,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(),
          if (_viewMode == CalendarViewMode.week)
            _buildWeekView(activitiesState, eventsState, carbLoadingState)
          else
            CalendarMonthGrid(
              visibleMonthDate: _visibleMonthDate,
              selectedDate: widget.selectedDate,
              onDateSelected: widget.onDateSelected,
              activitiesState: activitiesState,
              eventsState: eventsState,
              carbLoadingState: carbLoadingState,
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _navigateToPreviousMonth,
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                InkWell(
                  onTap: _showMonthYearPicker,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Text(
                      DateFormat('MMMM yyyy').format(_visibleMonthDate),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    setState(() {
                      _viewMode = _viewMode == CalendarViewMode.week
                          ? CalendarViewMode.month
                          : CalendarViewMode.week;
                    });
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _viewMode == CalendarViewMode.week
                          ? Icons.calendar_month
                          : Icons.view_week,
                      size: 18,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
                if (_showTodayButton) ...[
                  const SizedBox(width: 12),
                  Material(
                    elevation: 2,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: _scrollToToday,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.today,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Today',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _navigateToNextMonth,
          ),
        ],
      ),
    );
  }

  Widget _buildWeekView(
    AsyncValue<List<Activity>> activitiesState,
    AsyncValue<List<Event>> eventsState,
    AsyncValue<List<dynamic>> carbLoadingState,
  ) {
    return SizedBox(
      height: 90,
      child: activitiesState.when(
        data: (activities) {
          final events = eventsState.maybeWhen(
            data: (e) => e,
            orElse: () => <Event>[],
          );
          final carbLoadingDays = carbLoadingState.maybeWhen(
            data: (days) => days.cast<db.CarbLoadingDay>(),
            orElse: () => <db.CarbLoadingDay>[],
          );

          return ListView.builder(
            controller: _dateScrollController,
            scrollDirection: Axis.horizontal,
            itemCount: _totalDays,
            cacheExtent: _dateItemWidth * 10, // Cache 10 items ahead/behind
            itemBuilder: (context, index) {
              final date = _getScrollableDate(index);
              final isSelected = _isSameDay(date, widget.selectedDate);
              final isToday = _isSameDay(date, _referenceDate);

              return GestureDetector(
                key: ValueKey('date_${date.year}_${date.month}_${date.day}'),
                onTap: () => widget.onDateSelected(date),
                child: Container(
                  width: 60,
                  margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : isToday
                            ? const Color(0xFFFFC107).withValues(alpha: 0.2)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isToday ? const Color(0xFFFFC107) : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('EEE').format(date),
                        style: TextStyle(
                          fontSize: 12,
                          color: isSelected ? AppTheme.baseCream : Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('d').format(date),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? AppTheme.baseCream : Colors.black,
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
              );
            },
          );
        },
        loading: () => _buildLoadingWeekView(),
        error: (_, __) => _buildLoadingWeekView(),
      ),
    );
  }

  Widget _buildLoadingWeekView() {
    return ListView.builder(
      controller: _dateScrollController,
      scrollDirection: Axis.horizontal,
      itemCount: _totalDays,
      itemBuilder: (context, index) {
        final date = _getScrollableDate(index);
        final isSelected = _isSameDay(date, widget.selectedDate);
        final isToday = _isSameDay(date, _referenceDate);

        return Container(
          key: ValueKey('date_loading_${date.year}_${date.month}_${date.day}'),
          width: 60,
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).primaryColor
                : isToday
                    ? const Color(0xFFFFC107).withValues(alpha: 0.2)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                DateFormat('EEE').format(date),
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected ? AppTheme.baseCream : Colors.grey[600],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('d').format(date),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? AppTheme.baseCream : Colors.black,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
