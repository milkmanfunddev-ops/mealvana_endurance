import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:mealvana_endurance/shared/widgets/primary_button.dart';
import 'package:mealvana_endurance/theme/app_theme.dart';
import '../../domain/activity.dart';
import '../../domain/event.dart';
import '../providers/calendar_controller.dart';
import '../widgets/upcoming_event_widget.dart';
import '../../../activities/presentation/screens/activity_creation_screen.dart';
import '../../../../shared/database/app_database.dart' as db;
import '../../../carb_loading/presentation/screens/carb_loading_day_detail_page.dart';
import '../../../../features/auth/application/auth_service.dart';
import '../../../../shared/services/sync/data_sync_service.dart';

/// Main screen showing calendar date picker and daily activity list.
///
/// This is the PRIMARY tab in the app, showing:
/// - Calendar date picker at top
/// - Upcoming Event widget (if event exists)
/// - Daily activity list for selected date
/// - FAB to create new activities
class ActivitiesListScreen extends ConsumerStatefulWidget {
  const ActivitiesListScreen({super.key});

  @override
  ConsumerState<ActivitiesListScreen> createState() => _ActivitiesListScreenState();
}

class _ActivitiesListScreenState extends ConsumerState<ActivitiesListScreen> {
  DateTime _selectedDate = DateTime.now();
  late ScrollController _dateScrollController;
  bool _showTodayButton = false;
  bool _showMonthView = false; // NEW: Toggle for month view

  // Large range to allow scrolling far in both directions
  static const int _totalDays = 730; // 2 years worth of dates
  static const int _centerIndex = 365; // Start in middle
  static const double _dateItemWidth = 68.0; // 60 width + 8 margin

  @override
  void initState() {
    super.initState();
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
    // Show "Today" button if scrolled away from center (today)
    final currentOffset = _dateScrollController.offset;
    final centerOffset = _centerIndex * _dateItemWidth;
    final distanceFromCenter = (currentOffset - centerOffset).abs();

    // Show button if scrolled more than 3 dates away from today
    final shouldShow = distanceFromCenter > (_dateItemWidth * 3);

    if (shouldShow != _showTodayButton) {
      setState(() {
        _showTodayButton = shouldShow;
      });
    }
  }

  void _scrollToToday() {
    _dateScrollController.animateTo(
      _centerIndex * _dateItemWidth,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
    setState(() {
      _selectedDate = DateTime.now();
    });
  }

  // NEW: Show date picker dialog
  Future<void> _showDatePickerDialog() async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
              onPrimary: Colors.white,
              surface: AppTheme.baseCream,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (pickedDate != null && pickedDate != _selectedDate) {
      setState(() {
        _selectedDate = pickedDate;
        // Scroll to the picked date
        final daysFromToday = _selectedDate.difference(DateTime.now()).inDays;
        _dateScrollController.animateTo(
          (_centerIndex + daysFromToday) * _dateItemWidth,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final calendarState = ref.watch(calendarControllerProvider);
    final upcomingEvent = ref.watch(nextUpcomingEventProvider);

    return Scaffold(
      backgroundColor: AppTheme.baseCream,
      body: SafeArea(
        child: Column(
          children: [
            // Calendar Date Picker
            _buildCalendarPicker(calendarState),
        
            // Content based on calendar state
            Expanded(
              child: calendarState.when(
                data: (calendarData) {
                  // Get activities for selected date (all activities - events are shown separately in Events List screen)
                  final selectedDateActivities = calendarData.activities.where((activity) {
                    return _isSameDay(activity.scheduledDateTime, _selectedDate);
                  }).toList();

                  // Get carb loading days for selected date
                  final selectedDateCarbDays = calendarData.carbLoadingDays.where((carbDay) {
                    return _isSameDay(carbDay.planDate, _selectedDate);
                  }).toList();

                  // Check if we have any items to display
                  final hasItems = selectedDateActivities.isNotEmpty || selectedDateCarbDays.isNotEmpty;

                  return RefreshIndicator(
                    onRefresh: () async {
                      // Sync data with Supabase (download + upload dirty records)
                      final authService = ref.read(authServiceProvider);
                      final user = await authService.getCurrentUser();
                      if (user != null) {
                        await ref.read(dataSyncServiceProvider).syncAllData(user.id);
                      }
                      // Refresh local UI state
                      ref.invalidate(calendarControllerProvider);
                      ref.invalidate(nextUpcomingEventProvider);
                    },
                    child: CustomScrollView(
                      slivers: [
                        // Upcoming Event Widget at TOP
                        SliverToBoxAdapter(
                          child: upcomingEvent.when(
                            data: (event) => _buildUpcomingEventSection(event),
                            loading: () => const SizedBox.shrink(),
                            error: (_, __) => const SizedBox.shrink(),
                          ),
                        ),
                        // Daily Activity List
                        if (!hasItems)
                          SliverFillRemaining(
                            child: _buildEmptyState(),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.all(16),
                            sliver: SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  // Show carb loading days first, then activities
                                  if (index < selectedDateCarbDays.length) {
                                    return _buildCarbLoadingDayCard(selectedDateCarbDays[index]);
                                  } else {
                                    final activityIndex = index - selectedDateCarbDays.length;
                                    return _buildActivityCard(selectedDateActivities[activityIndex]);
                                  }
                                },
                                childCount: selectedDateCarbDays.length + selectedDateActivities.length,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stack) => Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Error loading activities: $error'),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          ref.invalidate(calendarControllerProvider);
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => ActivityCreationScreen(
                selectedDate: _selectedDate,
              ),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('New Activity'),
      ),
    );
  }

  Widget _buildCalendarPicker(AsyncValue<dynamic> calendarState) {
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
          // Month/Year Header with controls
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () {
                    setState(() {
                      // Move to previous month
                      final newMonth = DateTime(_selectedDate.year, _selectedDate.month - 1, 1);
                      _selectedDate = newMonth;
                      // Only scroll if week view is visible
                      if (!_showMonthView) {
                        final daysFromToday = _selectedDate.difference(DateTime.now()).inDays;
                        _dateScrollController.animateTo(
                          (_centerIndex + daysFromToday) * _dateItemWidth,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      }
                    });
                  },
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // NEW: Tappable date text that opens date picker
                      InkWell(
                        onTap: _showDatePickerDialog,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          child: Text(
                            DateFormat('MMMM yyyy').format(_selectedDate),
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                      ),
                      // "Today" pill button (appears when scrolled away from today)
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
                Row(
                  children: [
                    // NEW: Month view toggle button
                    IconButton(
                      icon: Icon(
                        Icons.view_module,
                        color: _showMonthView ? Theme.of(context).primaryColor : Colors.grey[600],
                      ),
                      tooltip: 'Month View',
                      onPressed: () {
                        setState(() {
                          _showMonthView = !_showMonthView;
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.chevron_right),
                      onPressed: () {
                        setState(() {
                          // Move to next month
                          final newMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 1);
                          _selectedDate = newMonth;
                          // Only scroll if week view is visible
                          if (!_showMonthView) {
                            final daysFromToday = _selectedDate.difference(DateTime.now()).inDays;
                            _dateScrollController.animateTo(
                              (_centerIndex + daysFromToday) * _dateItemWidth,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Show either week view or month view
          if (_showMonthView)
            _buildMonthCalendarView(calendarState)
          else
            _buildWeekView(calendarState),
        ],
      ),
    );
  }

  // NEW: Build month calendar view with event dots
  // Build week view with event dots
  Widget _buildWeekView(AsyncValue<dynamic> calendarState) {
    return calendarState.when(
      data: (calendarData) {
        return SizedBox(
          height: 90,
          child: ListView.builder(
            controller: _dateScrollController,
            scrollDirection: Axis.horizontal,
            itemCount: _totalDays,
            itemBuilder: (context, index) {
              final date = _getScrollableDate(index);
              final isSelected = _isSameDay(date, _selectedDate);
              final isToday = _isSameDay(date, DateTime.now());
              
              // Check for activities, events, and carb loading days
              final hasActivity = calendarData.activities.any((a) => _isSameDay(a.scheduledDateTime, date));
              final hasEvent = calendarData.events.any((e) => _isSameDay(e.dateTime, date));
              final hasCarbDay = calendarData.carbLoadingDays.any((c) => _isSameDay(c.planDate, date));

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDate = date;
                  });
                },
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
                      const SizedBox(height: 4),
                      // Event dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (hasActivity)
                            Container(
                              width: 5,
                              height: 5,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                color: isSelected ? AppTheme.baseCream : const Color(0xFF2196F3),
                                shape: BoxShape.circle,
                              ),
                            ),
                          if (hasEvent)
                            Container(
                              width: 5,
                              height: 5,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                color: isSelected ? AppTheme.baseCream : const Color(0xFF4CAF50),
                                shape: BoxShape.circle,
                              ),
                            ),
                          if (hasCarbDay)
                            Container(
                              width: 5,
                              height: 5,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                color: isSelected ? AppTheme.baseCream : const Color(0xFFFF9800),
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
      loading: () => const SizedBox(
        height: 90,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildMonthCalendarView(AsyncValue<dynamic> calendarState) {
    return calendarState.when(
      data: (calendarData) {
        // Get first day of the month
        final firstDayOfMonth = DateTime(_selectedDate.year, _selectedDate.month, 1);
        final lastDayOfMonth = DateTime(_selectedDate.year, _selectedDate.month + 1, 0);
        final daysInMonth = lastDayOfMonth.day;
        
        // Get the weekday of the first day (1 = Monday, 7 = Sunday)
        final firstWeekday = firstDayOfMonth.weekday;
        
        // Calculate total cells needed (including empty cells at start)
        final totalCells = daysInMonth + (firstWeekday - 1);
        final rows = (totalCells / 7).ceil();

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Column(
            children: [
              // Weekday headers
              Row(
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
              ),
              const SizedBox(height: 8),
              // Calendar grid
              ...List.generate(rows, (rowIndex) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: List.generate(7, (colIndex) {
                      final cellIndex = rowIndex * 7 + colIndex;
                      final dayNumber = cellIndex - (firstWeekday - 1) + 1;
                      
                      if (dayNumber < 1 || dayNumber > daysInMonth) {
                        // Empty cell
                        return Expanded(child: SizedBox(height: 50));
                      }
                      
                      final date = DateTime(_selectedDate.year, _selectedDate.month, dayNumber);
                      final isSelected = _isSameDay(date, _selectedDate);
                      final isToday = _isSameDay(date, DateTime.now());
                      
                      // Check for activities, events, and carb loading days
                      final hasActivity = calendarData.activities.any((a) => _isSameDay(a.scheduledDateTime, date));
                      final hasEvent = calendarData.events.any((e) => _isSameDay(e.dateTime, date));
                      final hasCarbDay = calendarData.carbLoadingDays.any((c) => _isSameDay(c.planDate, date));
                      
                      return Expanded(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _selectedDate = date;
                              // Optionally hide month view after selection
                              // _showMonthView = false;
                            });
                          },
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
                                color: isToday ? const Color(0xFFFFC107) : Colors.transparent,
                                width: 2,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$dayNumber',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: isSelected ? AppTheme.baseCream : Colors.black,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                // Event dots
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    if (hasActivity)
                                      Container(
                                        width: 5,
                                        height: 5,
                                        margin: const EdgeInsets.symmetric(horizontal: 1),
                                        decoration: BoxDecoration(
                                          color: isSelected ? AppTheme.baseCream : const Color(0xFF2196F3),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    if (hasEvent)
                                      Container(
                                        width: 5,
                                        height: 5,
                                        margin: const EdgeInsets.symmetric(horizontal: 1),
                                        decoration: BoxDecoration(
                                          color: isSelected ? AppTheme.baseCream : const Color(0xFF4CAF50),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    if (hasCarbDay)
                                      Container(
                                        width: 5,
                                        height: 5,
                                        margin: const EdgeInsets.symmetric(horizontal: 1),
                                        decoration: BoxDecoration(
                                          color: isSelected ? AppTheme.baseCream : const Color(0xFFFF9800),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                );
              }),
            ],
          ),
        );
      },
      loading: () => const SizedBox(
        height: 300,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildActivityCard(Activity activity) {
    // Determine card styling based on activity type (all activities use the same color now)
    final accentColor = const Color(0xFF2196F3);

    return Dismissible(
      key: Key(activity.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
          size: 32,
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Delete Activity'),
              content: Text('Are you sure you want to delete "${activity.title}"?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        );
      },
      onDismissed: (direction) {
        // Delete the activity (fire and forget - optimistic update)
        // The item has already been removed from the UI by the Dismissible widget
        ref.read(calendarControllerProvider.notifier).deleteActivity(activity.id);

        // Show confirmation
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleted "${activity.title}"'),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () {
                  // TODO: Implement undo functionality if needed
                },
              ),
            ),
          );
        }
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: () async {
            // All activities go to the Activity Detail Screen now
            // The activity detail screen will show event info if one exists
            context.push('/plan', extra: {
              'mode': 'view',
              'activityId': activity.id,
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Activity Type Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.directions_run,
                    color: accentColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),

                // Activity Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        activity.title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatActivityDetails(activity),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                    ],
                  ),
                ),

                // Status Indicator
                _buildStatusIndicator(activity),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCarbLoadingDayCard(db.CarbLoadingDay carbDay) {
    final dayNumber = carbDay.dayNumber;
    final targetCarbs = carbDay.carbTargetGrams;
    final loggedCarbs = carbDay.loggedCarbsGrams;
    final progress = targetCarbs > 0 ? (loggedCarbs / targetCarbs).clamp(0.0, 1.0) : 0.0;
    final isCompleted = carbDay.completed;

    return Dismissible(
      key: Key(carbDay.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
          size: 32,
        ),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Delete Carb Loading Day'),
              content: Text('Are you sure you want to delete "Carb Loading Day $dayNumber"?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        );
      },
      onDismissed: (direction) async {
        // Delete the carb loading day and wait for completion
        await ref.read(calendarControllerProvider.notifier).deleteCarbLoadingDay(carbDay.id);

        // Show confirmation - check mounted after async operation
        if (!context.mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Deleted "Carb Loading Day $dayNumber"'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () {
                // TODO: Implement undo functionality if needed
              },
            ),
          ),
        );
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => CarbLoadingDayDetailPage(
                  carbLoadingDay: carbDay,
                ),
              ),
            );
          },
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: const Color(0xFFFF9800),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                // Carb Loading Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF9800).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.restaurant_menu,
                    color: Color(0xFFFF9800),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),

                // Carb Loading Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Carb Loading Day $dayNumber',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF9800),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              'RACE PREP',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Target: ${targetCarbs}g carbs',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                      ),
                      if (loggedCarbs > 0) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  backgroundColor: Colors.grey[200],
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    progress >= 0.9 ? Colors.green : const Color(0xFFFF9800),
                                  ),
                                  minHeight: 8,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${loggedCarbs}g',
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Status Indicator
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isCompleted ? Colors.green.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isCompleted ? Icons.check : Icons.schedule,
                    color: isCompleted ? Colors.green : Colors.grey[600],
                    size: 20,
                  ),
                ),
              ],
              ), // Row
            ), // Padding
          ), // Container
        ), // InkWell
      ), // Card
    ); // Dismissible
  }

  Widget _buildStatusIndicator(Activity activity) {
    switch (activity.status) {
      case ActivityStatus.completed:
        return const Icon(
          Icons.check_circle,
          color: Color(0xFF4CAF50),
          size: 24,
        );
      case ActivityStatus.skipped:
        return const Icon(
          Icons.remove_circle_outline,
          color: Colors.grey,
          size: 24,
        );
      case ActivityStatus.inProgress:
        return const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(Color(0xFFFF9800)),
          ),
        );
      case ActivityStatus.planned:
        // TODO: Check if activity has nutrition plan and show appropriate indicator
        return Container(
          width: 10,
          height: 10,
          decoration: const BoxDecoration(
            color: Color(0xFF2196F3),
            shape: BoxShape.circle,
          ),
        );
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'No activities scheduled',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            DateFormat('EEEE, MMMM d').format(_selectedDate),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => ActivityCreationScreen(
                    selectedDate: _selectedDate,
                  ),
                ),
              );
            },
            text: 'Create Activity',
          ),
        ],
      ),
    );
  }

  String _formatActivityDetails(Activity activity) {
    final parts = <String>[];

    if (activity.distanceMiles != null) {
      parts.add('${activity.distanceMiles} mi');
    }

    if (activity.formattedDuration != null) {
      parts.add(activity.formattedDuration!);
    }

    if (activity.formattedPace != null) {
      parts.add(activity.formattedPace!);
    }

    return parts.join(' • ');
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  DateTime _getScrollableDate(int index) {
    // Calculate date relative to today, with _centerIndex representing today
    final today = DateTime.now();
    final daysOffset = index - _centerIndex;
    return DateTime(today.year, today.month, today.day).add(Duration(days: daysOffset));
  }

  Widget _buildUpcomingEventSection(Event? upcomingEvent) {
    return UpcomingEventWidget(
      upcomingEvent: upcomingEvent,
    );
  }
}
