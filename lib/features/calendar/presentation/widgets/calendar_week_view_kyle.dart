import 'package:flutter/material.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../shared/widgets/app_date_picker.dart';
import '../../domain/calendar_day_indicators.dart';

/// Week calendar view matching Kyle's design
///
/// Displays a single week (Sunday-Saturday) with:
/// - Day abbreviations (S M T W T F S)
/// - Day numbers
/// - Selected day highlighting (Cream bg in dark mode, Blackberry bg in light mode)
/// - Activity indicators (6px cyan dots below days with activities)
/// - Month/year title
/// - Divider line below calendar
///
/// Specifications:
/// - Day abbreviations: Apercu Mono, 12px
/// - Day numbers: Compadre Regular, 18px
/// - Selected day: 40px wide × 60px high, 15px border radius
/// - Activity dots: 6px diameter, Electrolyte color
///
/// Example:
/// ```dart
/// CalendarWeekViewKyle(
///   selectedDate: DateTime.now(),
///   onDateSelected: (date) => setState(() => _selectedDate = date),
///   datesWithActivities: {
///     DateTime(2025, 11, 13): true,
///     DateTime(2025, 11, 15): true,
///   },
/// )
/// ```
class CalendarWeekViewKyle extends StatefulWidget {
  const CalendarWeekViewKyle({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    this.dayIndicators = const {},
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final Map<DateTime, Set<DayIndicatorType>> dayIndicators;

  @override
  State<CalendarWeekViewKyle> createState() => _CalendarWeekViewKyleState();
}

class _CalendarWeekViewKyleState extends State<CalendarWeekViewKyle> {
  late PageController _pageController;
  late DateTime _currentWeekStart;
  late DateTime _baseWeekStart; // Fixed reference point that never changes
  static const int _initialPage = 500; // Start at middle page
  late DateTime
  _todayWeekStart; // Week start for today (for "Today" button logic)
  bool _handledFirstPageChange = false;

  @override
  void initState() {
    super.initState();
    _currentWeekStart = _getWeekStart(widget.selectedDate);
    _baseWeekStart = _currentWeekStart; // Store the base reference
    _todayWeekStart = _getWeekStart(DateTime.now()); // Store today's week start
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
    final isCurrentWeek = _isSameDay(_currentWeekStart, _todayWeekStart);

    return Column(
      children: [
        // Month/Year title with nav arrows and optional Today button
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Previous week arrow
              Semantics(
                button: true,
                label: 'Previous week',
                child: GestureDetector(
                  key: const ValueKey('calendar.prev_month_button'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _goToPreviousWeek,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      Icons.chevron_left,
                      size: 24,
                      color: isDark ? AppColors.cream : AppColors.blackberry,
                    ),
                  ),
                ),
              ),
              // Month/Year title (tappable for date picker)
              Semantics(
                button: true,
                label: 'Choose month',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _showDatePicker(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      key: const ValueKey('calendar.month_label'),
                      _formatMonthYear(widget.selectedDate),
                      style: const TextStyle(
                        fontFamily: 'Sansita',
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ),
              // Next week arrow
              Semantics(
                button: true,
                label: 'Next week',
                child: GestureDetector(
                  key: const ValueKey('calendar.next_month_button'),
                  behavior: HitTestBehavior.opaque,
                  onTap: _goToNextWeek,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Icon(
                      Icons.chevron_right,
                      size: 24,
                      color: isDark ? AppColors.cream : AppColors.blackberry,
                    ),
                  ),
                ),
              ),
              // Today button - only shown when not on current week
              if (!isCurrentWeek) ...[
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: _goToToday,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
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

        // Horizontally scrollable week view
        SizedBox(
          height: 100, // Height for day abbreviations + day numbers
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              final weekOffset = index - _initialPage;
              final newWeekStart = _baseWeekStart.add(
                Duration(days: weekOffset * 7),
              );
              setState(() {
                _currentWeekStart = newWeekStart;
              });
              if (!_handledFirstPageChange) {
                _handledFirstPageChange = true;
                return;
              }
              // Auto-select first day of new week if current selection not in view
              final firstDayOfWeek = newWeekStart;
              if (!_isInWeek(widget.selectedDate, firstDayOfWeek)) {
                widget.onDateSelected(_normalize(firstDayOfWeek));
              }
            },
            itemBuilder: (context, index) {
              final weekOffset = index - _initialPage;
              final weekStart = _baseWeekStart.add(
                Duration(days: weekOffset * 7),
              );
              final weekDays = List.generate(
                7,
                (i) => weekStart.add(Duration(days: i)),
              );

              return Column(
                children: [
                  // Day abbreviations row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: weekDays.map((date) {
                      return Expanded(
                        child: Text(
                          _getDayAbbreviation(date.weekday % 7),
                          style: TextStyle(
                            fontFamily: 'Apercu',
                            fontSize: 12,
                            color: isDark
                                ? AppColors.cream
                                : AppColors.blackberry,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 8),

                  // Day numbers row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: weekDays.map((date) {
                      final isSelected = _isSameDay(date, widget.selectedDate);
                      final indicators =
                          widget.dayIndicators[_dateKey(date)] ?? {};

                      return Expanded(
                        child: GestureDetector(
                          key: ValueKey(
                            'calendar.day_cell_${date.year}_${date.month.toString().padLeft(2, '0')}_${date.day.toString().padLeft(2, '0')}',
                          ),
                          onTap: () => widget.onDateSelected(_normalize(date)),
                          child: Container(
                            height: 60,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDark
                                        ? AppColors.cream
                                        : AppColors.blackberry)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '${date.day}',
                                  style: TextStyle(
                                    fontFamily: 'Compadre',
                                    fontSize: 18,
                                    color: isSelected
                                        ? (isDark
                                              ? AppColors.blackberry
                                              : AppColors.cream)
                                        : (isDark
                                              ? AppColors.cream
                                              : AppColors.blackberry),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                // Show indicator dots
                                if (indicators.isNotEmpty)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: CalendarDayIndicators.buildDots(
                                      indicators: indicators,
                                      dotSize: 6.0,
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
                ],
              );
            },
          ),
        ),

        // Divider line
        Container(
          height: 1,
          color: (isDark ? AppColors.cream : AppColors.blackberry).withValues(
            alpha: 0.2,
          ),
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
      // Jump to the week containing the picked date
      final newWeekStart = _getWeekStart(picked);
      setState(() {
        _currentWeekStart = newWeekStart;
        _baseWeekStart = newWeekStart; // Update base week to new reference
      });
      _pageController.jumpToPage(_initialPage);
    }
  }

  void _goToPreviousWeek() {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _goToNextWeek() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _goToToday() {
    final today = DateTime.now();
    final newWeekStart = _getWeekStart(today);
    widget.onDateSelected(today);
    setState(() {
      _currentWeekStart = newWeekStart;
      _baseWeekStart = newWeekStart;
      _todayWeekStart = newWeekStart; // Also update today's week reference
    });
    _pageController.jumpToPage(_initialPage);
  }

  bool _isInWeek(DateTime date, DateTime weekStart) {
    final weekEnd = weekStart.add(const Duration(days: 6));
    return date.isAfter(weekStart.subtract(const Duration(days: 1))) &&
        date.isBefore(weekEnd.add(const Duration(days: 1)));
  }

  DateTime _getWeekStart(DateTime date) {
    return date.subtract(Duration(days: date.weekday % 7));
  }

  String _getDayAbbreviation(int weekday) {
    const days = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    return days[weekday];
  }

  String _formatMonthYear(DateTime date) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  DateTime _dateKey(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  DateTime _normalize(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }
}
