import 'package:flutter/material.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../shared/widgets/app_date_picker.dart';
import '../../domain/calendar_day_indicators.dart';

/// Month calendar view matching Kyle's design
///
/// Displays a full month grid (7 columns × ~5 rows) with:
/// - S M T W T F S header row
/// - Day numbers for entire month
/// - Days from previous/next month shown in lighter color
/// - Selected day highlighted with circle
/// - Activity indicators (6px cyan dots below days with activities)
/// - Month/year title
///
/// Specifications:
/// - Day abbreviations: Apercu Mono, 12px
/// - Day numbers: Compadre Regular, 18px
/// - Selected day: Circle with Cream/Blackberry background
/// - Activity dots: 6px diameter, Electrolyte color
/// - Grid spacing: Even distribution
///
/// Example:
/// ```dart
/// CalendarMonthViewKyle(
///   selectedDate: DateTime.now(),
///   onDateSelected: (date) => setState(() => _selectedDate = date),
///   datesWithActivities: {
///     DateTime(2025, 11, 13): true,
///     DateTime(2025, 11, 15): true,
///   },
/// )
/// ```
class CalendarMonthViewKyle extends StatefulWidget {
  const CalendarMonthViewKyle({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    this.dayIndicators = const {},
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final Map<DateTime, Set<DayIndicatorType>> dayIndicators;

  @override
  State<CalendarMonthViewKyle> createState() => _CalendarMonthViewKyleState();
}

class _CalendarMonthViewKyleState extends State<CalendarMonthViewKyle> {
  late PageController _pageController;
  late DateTime _currentMonth;
  late DateTime _baseMonth; // Fixed reference point that never changes
  static const int _initialPage = 500; // Start at middle page
  late DateTime _todayMonth; // Month containing today (for "Today" button logic)

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(widget.selectedDate.year, widget.selectedDate.month, 1);
    _baseMonth = _currentMonth; // Store the base reference
    final now = DateTime.now();
    _todayMonth = DateTime(now.year, now.month, 1); // Store today's month
    _pageController = PageController(initialPage: _initialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isCurrentMonth = _currentMonth.year == _todayMonth.year &&
                           _currentMonth.month == _todayMonth.month;

    return Column(
      children: [
        // Month/Year title with optional Today button
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Month/Year title (tappable for date picker)
              GestureDetector(
                onTap: () => _showDatePicker(context),
                child: Text(
                  _formatMonthYear(widget.selectedDate),
                  style: const TextStyle(
                    fontFamily: 'Sansita',
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              // Today button - only shown when not on current month
              if (!isCurrentMonth) ...[
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _goToToday,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.cream.withValues(alpha: 0.15)
                          : AppColors.blackberry.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      'Today',
                      style: TextStyle(
                        fontFamily: 'Apercu',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.cream : AppColors.blackberry,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Day abbreviations header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(7, (i) {
            return Expanded(
              child: Text(
                _getDayAbbreviation(i),
                style: TextStyle(
                  fontFamily: 'Apercu',
                  fontSize: 12,
                  color: isDark ? AppColors.cream : AppColors.blackberry,
                ),
                textAlign: TextAlign.center,
              ),
            );
          }),
        ),

        const SizedBox(height: 8),

        // Horizontally scrollable month grid - dynamic height based on weeks
        SizedBox(
          height: _calculateMonthGridHeight(_currentMonth),
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              final monthOffset = index - _initialPage;
              final newMonth = DateTime(
                _baseMonth.year,
                _baseMonth.month + monthOffset,
                1,
              );
              setState(() {
                _currentMonth = newMonth;
              });
              // Auto-select first day of new month if current selection not in this month
              if (widget.selectedDate.month != newMonth.month ||
                  widget.selectedDate.year != newMonth.year) {
                widget.onDateSelected(newMonth);
              }
            },
            itemBuilder: (context, index) {
              final monthOffset = index - _initialPage;
              final displayMonth = DateTime(
                _baseMonth.year,
                _baseMonth.month + monthOffset,
                1,
              );

              // Get all days to display (including overflow from prev/next month)
              final monthStart = displayMonth;
              final monthEnd = DateTime(displayMonth.year, displayMonth.month + 1, 0);

              // Start from the Sunday before the 1st of the month
              final displayStart = monthStart.subtract(
                Duration(days: monthStart.weekday % 7),
              );

              // Calculate number of weeks to show
              final daysToShow = ((monthEnd.day + monthStart.weekday) / 7).ceil() * 7;
              final allDays = List.generate(
                daysToShow,
                (i) => displayStart.add(Duration(days: i)),
              );

              return Column(
                children: List.generate(
                  (allDays.length / 7).ceil(),
                  (weekIndex) {
                    final weekStart = weekIndex * 7;
                    final weekDays = allDays.sublist(
                      weekStart,
                      (weekStart + 7).clamp(0, allDays.length),
                    );

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: weekDays.map((date) {
                          final isSelected = _isSameDay(date, widget.selectedDate);
                          final indicators = widget.dayIndicators[_dateKey(date)] ?? {};
                          final isCurrentMonth = date.month == displayMonth.month;

                          return Expanded(
                            child: GestureDetector(
                              onTap: () => widget.onDateSelected(date),
                              child: Container(
                                height: 44,
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? (isDark ? AppColors.cream : AppColors.blackberry)
                                      : Colors.transparent,
                                  shape: BoxShape.circle,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '${date.day}',
                                      style: TextStyle(
                                        fontFamily: 'Compadre',
                                        fontSize: 16,
                                        color: isSelected
                                            ? (isDark ? AppColors.blackberry : AppColors.cream)
                                            : isCurrentMonth
                                                ? (isDark ? AppColors.cream : AppColors.blackberry)
                                                : (isDark ? AppColors.cream : AppColors.blackberry)
                                                    .withValues(alpha: 0.3),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    // Show indicator dots
                                    if (indicators.isNotEmpty && isCurrentMonth)
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: CalendarDayIndicators.buildDots(
                                          indicators: indicators,
                                          dotSize: 4.0,
                                          spacing: 2.0,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),

        // Divider line
        Container(
          height: 1,
          color: (isDark ? AppColors.cream : AppColors.blackberry)
              .withValues(alpha: 0.2),
        ),
      ],
    );
  }

  Future<void> _showDatePicker(BuildContext context) async {
    final picked = await showAppDatePicker(
      context: context,
      initialDate: widget.selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );

    if (picked != null && !_isSameDay(picked, widget.selectedDate)) {
      widget.onDateSelected(picked);
      // Jump to the month containing the picked date
      final newMonth = DateTime(picked.year, picked.month, 1);
      setState(() {
        _currentMonth = newMonth;
        _baseMonth = newMonth; // Update base month to new reference
      });
      _pageController.jumpToPage(_initialPage);
    }
  }

  void _goToToday() {
    final today = DateTime.now();
    final newMonth = DateTime(today.year, today.month, 1);
    widget.onDateSelected(today);
    setState(() {
      _currentMonth = newMonth;
      _baseMonth = newMonth;
      _todayMonth = newMonth; // Also update today's month reference
    });
    _pageController.jumpToPage(_initialPage);
  }

  String _getDayAbbreviation(int weekday) {
    const days = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    return days[weekday];
  }

  String _formatMonthYear(DateTime date) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  DateTime _dateKey(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Calculate the number of weeks needed to display a month
  int _getWeeksInMonth(DateTime month) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);

    // Calculate days from start of week containing first day to end of week containing last day
    final startWeekday = firstDay.weekday % 7; // Sunday = 0
    final totalDays = startWeekday + lastDay.day;

    return (totalDays / 7).ceil();
  }

  /// Calculate dynamic height based on number of weeks
  double _calculateMonthGridHeight(DateTime month) {
    final weeks = _getWeeksInMonth(month);
    // Each row: 44px height + 4px vertical padding (2 top + 2 bottom)
    return weeks * 48.0;
  }
}
