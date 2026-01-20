import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/calendar_controller.dart';
import '../../../activities/domain/activity.dart';
import '../../../../theme/kyle_design/app_colors.dart';

/// Calendar week view widget
class CalendarWeekView extends ConsumerStatefulWidget {
  const CalendarWeekView({
    super.key,
    this.selectedDate,
    this.onDateSelected,
    this.onActivityTap,
    this.onActivityLongPress,
  });

  final DateTime? selectedDate;
  final Function(DateTime)? onDateSelected;
  final Function(Activity)? onActivityTap;
  final Function(Activity)? onActivityLongPress;

  @override
  ConsumerState<CalendarWeekView> createState() => _CalendarWeekViewState();
}

class _CalendarWeekViewState extends ConsumerState<CalendarWeekView> {
  late DateTime _weekStart;
  late PageController _pageController;
  
  @override
  void initState() {
    super.initState();
    _weekStart = _getWeekStart(widget.selectedDate ?? DateTime.now());
    _pageController = PageController(initialPage: 0);
    
    // Load initial week data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(calendarControllerProvider.notifier).loadWeekActivities(_weekStart);
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  DateTime _getWeekStart(DateTime date) {
    // TODO: Use user preference for week start
    return DateTime(date.year, date.month, date.day - date.weekday + 1);
  }

  DateTime _getWeekEnd(DateTime weekStart) {
    return weekStart.add(const Duration(days: 6, hours: 23, minutes: 59, seconds: 59));
  }

  void _navigateToPreviousWeek() {
    setState(() {
      _weekStart = _weekStart.subtract(const Duration(days: 7));
    });
    ref.read(calendarControllerProvider.notifier).loadWeekActivities(_weekStart);
  }

  void _navigateToNextWeek() {
    setState(() {
      _weekStart = _weekStart.add(const Duration(days: 7));
    });
    ref.read(calendarControllerProvider.notifier).loadWeekActivities(_weekStart);
  }

  void _goToToday() {
    final today = DateTime.now();
    setState(() {
      _weekStart = _getWeekStart(today);
    });
    ref.read(calendarControllerProvider.notifier).loadWeekActivities(_weekStart);
  }

  @override
  Widget build(BuildContext context) {
    final calendarState = ref.watch(calendarControllerProvider);
    
    return Column(
      children: [
        _buildWeekHeader(),
        _buildWeekDaysHeader(),
        Expanded(
          child: calendarState.when(
            data: (state) => _buildWeekContent(state),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading calendar',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => ref.read(calendarControllerProvider.notifier).loadWeekActivities(_weekStart),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeekHeader() {
    final weekEnd = _getWeekEnd(_weekStart);
    final dateFormatter = DateFormat('MMM d');
    final isCurrentWeek = _isCurrentWeek(_weekStart);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _navigateToPreviousWeek,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  '${dateFormatter.format(_weekStart)} - ${dateFormatter.format(weekEnd)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (isCurrentWeek)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'This Week',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: _navigateToNextWeek,
            icon: const Icon(Icons.chevron_right),
          ),
          if (!isCurrentWeek)
            TextButton(
              onPressed: _goToToday,
              child: const Text('Today'),
            ),
        ],
      ),
    );
  }

  Widget _buildWeekDaysHeader() {
    final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
            width: 1,
          ),
        ),
      ),
      child: Consumer(
        builder: (context, ref, child) {
          final calendarState = ref.watch(calendarControllerProvider);

          return Row(
            children: weekDays.asMap().entries.map((entry) {
              final index = entry.key;
              final day = entry.value;
              final date = _weekStart.add(Duration(days: index));
              final isToday = _isToday(date);
              final isSelected = widget.selectedDate != null && _isSameDay(date, widget.selectedDate!);

              // Check if this day has carb loading days
              final hasCarbLoadingDay = calendarState.maybeWhen(
                data: (state) => state.carbLoadingDays.any((carbDay) =>
                  _isSameDay(carbDay.planDate, date)
                ),
                orElse: () => false,
              );

              return Expanded(
                child: GestureDetector(
                  onTap: () => widget.onDateSelected?.call(date),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primaryContainer
                          : isToday
                              ? Theme.of(context).colorScheme.surfaceContainerHighest
                              : null,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Text(
                          day,
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: isToday ? FontWeight.w600 : FontWeight.normal,
                            color: isSelected
                                ? Theme.of(context).colorScheme.onPrimaryContainer
                                : isToday
                                    ? Theme.of(context).colorScheme.onSurfaceVariant
                                    : null,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          date.day.toString(),
                          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Theme.of(context).colorScheme.onPrimaryContainer
                                : isToday
                                    ? Theme.of(context).colorScheme.primary
                                    : null,
                          ),
                        ),
                        // Activity and carb loading indicators
                        const SizedBox(height: 2),
                        _buildDayIndicators(calendarState, date, hasCarbLoadingDay),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _buildWeekContent(CalendarState state) {
    return Row(
      children: List.generate(7, (index) {
        final date = _weekStart.add(Duration(days: index));
        final dayActivities = state.activities.where((activity) => 
          _isSameDay(activity.scheduledDateTime, date)
        ).toList();
        
        return Expanded(
          child: _buildDayColumn(date, dayActivities),
        );
      }),
    );
  }

  Widget _buildDayColumn(DateTime date, List<Activity> activities) {
    final isToday = _isToday(date);
    
    return Container(
      decoration: BoxDecoration(
        color: isToday 
            ? Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
            : null,
        border: Border(
          right: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.3),
            width: 0.5,
          ),
        ),
      ),
      child: ListView.builder(
        padding: const EdgeInsets.all(4),
        itemCount: activities.length,
        itemBuilder: (context, index) {
          final activity = activities[index];
          return _buildActivityTile(activity);
        },
      ),
    );
  }

  Widget _buildActivityTile(Activity activity) {
    final isCompleted = activity.isCompleted;
    final isInProgress = activity.status == ActivityStatus.inProgress;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => widget.onActivityTap?.call(activity),
          onLongPress: () => widget.onActivityLongPress?.call(activity),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getActivityColor(activity).withValues(alpha: 0.1),
              border: Border.all(
                color: _getActivityColor(activity).withValues(alpha: 0.3),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      _getActivityIcon(activity),
                      size: 16,
                      color: _getActivityColor(activity),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        activity.title,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: _getActivityColor(activity),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCompleted)
                      Icon(
                        Icons.check_circle,
                        size: 16,
                        color: Colors.green,
                      )
                    else if (isInProgress)
                      Icon(
                        Icons.play_circle,
                        size: 16,
                        color: Colors.orange,
                      ),
                  ],
                ),
                if (activity.distanceMiles != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    '${activity.distanceMiles!.toStringAsFixed(1)} mi',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
                if (activity.durationMinutes != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    _formatDuration(activity.durationMinutes!),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getActivityColor(Activity activity) {
    switch (activity.status) {
      case ActivityStatus.completed:
        return Colors.green;
      case ActivityStatus.inProgress:
        return Colors.orange;
      case ActivityStatus.skipped:
        return Colors.grey;
      case ActivityStatus.planned:
        return Theme.of(context).colorScheme.secondary;
      case ActivityStatus.draft:
        return Colors.grey.withValues(alpha: 0.5); // Draft activities shown as faded
      case ActivityStatus.archivedForBrick:
        return Colors.grey.withValues(alpha: 0.3); // Archived activities (used in brick) shown as very faded
    }
  }

  IconData _getActivityIcon(Activity activity) {
    switch (activity.intensityLevel) {
      case IntensityLevel.easy:
        return Icons.directions_walk;
      case IntensityLevel.moderate:
        return Icons.directions_run;
      case IntensityLevel.hard:
        return Icons.speed;
      case IntensityLevel.race:
        return Icons.emoji_events;
      default:
        return Icons.directions_run;
    }
  }

  String _formatDuration(int minutes) {
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    if (hours > 0) {
      return '${hours}h ${mins}m';
    }
    return '${mins}m';
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return _isSameDay(date, now);
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
           date1.month == date2.month &&
           date1.day == date2.day;
  }

  bool _isCurrentWeek(DateTime weekStart) {
    final now = DateTime.now();
    final currentWeekStart = _getWeekStart(now);
    return _isSameDay(weekStart, currentWeekStart);
  }

  /// Build day indicators (activity dots and carb loading indicator)
  Widget _buildDayIndicators(AsyncValue<CalendarState> calendarState, DateTime date, bool hasCarbLoadingDay) {
    final activities = calendarState.maybeWhen(
      data: (state) => state.activities.where((activity) {
        // Exclude archived activities (they're part of a brick)
        if (activity.status == ActivityStatus.archivedForBrick) {
          return false;
        }
        return _isSameDay(activity.scheduledDateTime, date);
      }).toList(),
      orElse: () => <Activity>[],
    );

    if (activities.isEmpty && !hasCarbLoadingDay) {
      return const SizedBox.shrink();
    }

    // Build dots for activities (including multi-sport dots for bricks)
    final List<Widget> dots = [];

    for (final activity in activities) {
      if (activity.isBrick && activity.brickMetadata != null) {
        // Brick activity: show one dot per sport in segment order
        final segments = activity.brickMetadata!.segments;
        for (final segment in segments) {
          dots.add(Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: _getSportColor(segment.sport),
              shape: BoxShape.circle,
            ),
          ));
          if (segment != segments.last) {
            dots.add(const SizedBox(width: 2));
          }
        }
      } else {
        // Single-sport activity: show one dot
        dots.add(Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            shape: BoxShape.circle,
          ),
        ));
      }

      // Add spacing between different activities
      if (activity != activities.last) {
        dots.add(const SizedBox(width: 2));
      }
    }

    // Add carb loading indicator if present
    if (hasCarbLoadingDay) {
      if (dots.isNotEmpty) {
        dots.add(const SizedBox(width: 2));
      }
      dots.add(Container(
        width: 5,
        height: 5,
        decoration: const BoxDecoration(
          color: Colors.orange,
          shape: BoxShape.circle,
        ),
      ));
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: dots,
    );
  }

  /// Get sport-specific color for brick segment dots
  Color _getSportColor(String sport) {
    switch (sport.toLowerCase()) {
      case 'swimming':
        return AppColors.electrolyte; // Teal/cyan for swimming
      case 'cycling':
        return AppColors.orange; // Orange for cycling
      case 'running':
        return AppColors.dragonfruit; // Pink for running
      default:
        return AppColors.electrolyte; // Default fallback
    }
  }
}