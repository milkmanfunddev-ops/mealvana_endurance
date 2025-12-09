import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';
import '../../../../shared/services/app_external_deps.dart';

/// Calendar Month Screen - Kyle's Design System
/// Shows monthly calendar view with activities and events
class CalendarMonthScreen extends ConsumerStatefulWidget {
  const CalendarMonthScreen({super.key});

  @override
  ConsumerState<CalendarMonthScreen> createState() => _CalendarMonthScreenState();
}

class _CalendarMonthScreenState extends ConsumerState<CalendarMonthScreen> {
  DateTime _currentMonth = DateTime.now();
  bool _isMonthView = true; // true = month view, false = week view

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: _buildAppBar(context),
      body: _buildContent(context),
      bottomNavigationBar: _buildBottomNav(context),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final now = DateTime.now();
    final isCurrentMonth = _currentMonth.year == now.year && _currentMonth.month == now.month;

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      automaticallyImplyLeading: false,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _formatMonthYear(_currentMonth),
                style: AppTextStyles.pageTitle.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              // Today button - only shown when not on current month
              if (!isCurrentMonth) ...[
                const SizedBox(width: AppSpacing.sm),
                GestureDetector(
                  onTap: _goToToday,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: AppRadius.buttonRadius,
                    ),
                    child: Text(
                      'Today',
                      style: AppTextStyles.buttonTertiary.copyWith(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          // View toggle
          _buildViewToggle(context),
        ],
      ),
    );
  }

  Widget _buildViewToggle(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: AppRadius.buttonRadius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Month view button
          InkWell(
            onTap: () => setState(() => _isMonthView = true),
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(15),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: _isMonthView 
                    ? AppColors.blackberry 
                    : Colors.transparent,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(15),
                ),
              ),
              child: Text(
                'BY MONTH',
                style: AppTextStyles.buttonTertiary.copyWith(
                  color: _isMonthView 
                      ? AppColors.cream 
                      : Theme.of(context).colorScheme.onSurface,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          // Week view button
          InkWell(
            onTap: () => setState(() => _isMonthView = false),
            borderRadius: const BorderRadius.horizontal(
              right: Radius.circular(15),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: !_isMonthView 
                    ? AppColors.blackberry 
                    : Colors.transparent,
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(15),
                ),
              ),
              child: Text(
                'BY WEEK',
                style: AppTextStyles.buttonTertiary.copyWith(
                  color: !_isMonthView 
                      ? AppColors.cream 
                      : Theme.of(context).colorScheme.onSurface,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_isMonthView) {
      return _buildMonthView(context);
    } else {
      return _buildWeekView(context);
    }
  }

  Widget _buildMonthView(BuildContext context) {
    return Column(
      children: [
        // Month navigation
        _buildMonthNavigation(context),
        
        const SizedBox(height: AppSpacing.md),
        
        // Day headers
        _buildDayHeaders(context),
        
        const SizedBox(height: AppSpacing.sm),
        
        // Calendar grid
        Expanded(
          child: _buildCalendarGrid(context),
        ),
      ],
    );
  }

  Widget _buildMonthNavigation(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Previous month button
        InkWell(
          onTap: () => _navigateMonth(-1),
          borderRadius: AppRadius.buttonRadius,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
              ),
              borderRadius: AppRadius.buttonRadius,
            ),
            child: Icon(
              FontAwesomeIcons.chevronLeft,
              size: AppIconSizes.controlIcon,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        
        // Current month
        Text(
          _formatMonthYear(_currentMonth),
          style: AppTextStyles.sectionTitle.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        
        // Next month button
        InkWell(
          onTap: () => _navigateMonth(1),
          borderRadius: AppRadius.buttonRadius,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
              ),
              borderRadius: AppRadius.buttonRadius,
            ),
            child: Icon(
              FontAwesomeIcons.chevronRight,
              size: AppIconSizes.controlIcon,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDayHeaders(BuildContext context) {
    final days = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    
    return Row(
      children: days.map((day) => Expanded(
        child: Center(
          child: Text(
            day,
            style: AppTextStyles.smallLabel.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      )).toList(),
    );
  }

  Widget _buildCalendarGrid(BuildContext context) {
    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final daysInMonth = lastDayOfMonth.day;
    final startingWeekday = firstDayOfMonth.weekday % 7; // Adjust for Sunday=0
    
    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1.0,
      ),
      itemCount: 42, // 6 weeks * 7 days
      itemBuilder: (context, index) {
        final dayNumber = index - startingWeekday + 1;
        final isValidDay = dayNumber > 0 && dayNumber <= daysInMonth;
        final isToday = isValidDay && _isToday(DateTime(_currentMonth.year, _currentMonth.month, dayNumber));
        final hasEvents = isValidDay && _hasEventsOnDay(dayNumber);
        
        return _buildCalendarDay(
          context: context,
          dayNumber: isValidDay ? dayNumber : null,
          isToday: isToday,
          hasEvents: hasEvents,
        );
      },
    );
  }

  Widget _buildCalendarDay({
    required BuildContext context,
    required int? dayNumber,
    required bool isToday,
    required bool hasEvents,
  }) {
    if (dayNumber == null) {
      return const SizedBox.shrink();
    }
    
    return InkWell(
      onTap: () => _selectDay(dayNumber),
      borderRadius: AppRadius.circularRadius,
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isToday 
              ? AppColors.blackberry.withOpacity(0.2)
              : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Day number
            Text(
              '$dayNumber',
              style: AppTextStyles.bodyLarge.copyWith(
                color: isToday 
                    ? AppColors.blackberry 
                    : Theme.of(context).colorScheme.onSurface,
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
              ),
            ),
            
            // Event indicator
            if (hasEvents) ...[
              const SizedBox(height: 2),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: AppColors.electrolyte,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWeekView(BuildContext context) {
    return Column(
      children: [
        // Week selector
        _buildWeekSelector(context),
        
        // const SizedBox(height: AppSpacing.lg),
        
        // Today's Activities section
        _buildTodaysActivities(context),
        
        const SizedBox(height: AppSpacing.lg),
        
        // Upcoming Events section
        _buildUpcomingEvents(context),
      ],
    );
  }

  Widget _buildWeekSelector(BuildContext context) {
    final weekDays = _getWeekDays();
    
    return Container(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: weekDays.length,
        itemBuilder: (context, index) {
          final day = weekDays[index];
          final isToday = _isToday(day);
          final hasEvents = _hasEventsOnDay(day.day);
          
          return _buildWeekDayItem(
            context: context,
            day: day,
            isToday: isToday,
            hasEvents: hasEvents,
            isSelected: index == 2, // Select middle day
          );
        },
      ),
    );
  }

  Widget _buildWeekDayItem({
    required BuildContext context,
    required DateTime day,
    required bool isToday,
    required bool hasEvents,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () => _selectDay(day.day),
      borderRadius: AppRadius.cardRadius,
      child: Container(
        margin: const EdgeInsets.only(right: AppSpacing.sm),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected 
              ? AppColors.blackberry 
              : isToday 
                  ? AppColors.blackberry.withOpacity(0.2)
                  : Colors.transparent,
          borderRadius: AppRadius.cardRadius,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _formatDayName(day),
              style: AppTextStyles.smallLabel.copyWith(
                color: isSelected 
                    ? AppColors.cream 
                    : isToday 
                        ? AppColors.blackberry 
                        : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${day.day}',
              style: AppTextStyles.dataNumber.copyWith(
                color: isSelected 
                    ? AppColors.cream 
                    : isToday 
                        ? AppColors.blackberry 
                        : Theme.of(context).colorScheme.onSurface,
                fontSize: 20,
              ),
            ),
            if (hasEvents) ...[
              const SizedBox(height: 2),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: isSelected 
                      ? AppColors.cream 
                      : AppColors.electrolyte,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTodaysActivities(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Text(
          "Today's Activities",
          style: AppTextStyles.sectionTitle.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        
        const SizedBox(height: AppSpacing.md),
        
        // Activity cards
        ..._getMockTodaysActivities().map((activity) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _buildActivityCard(context, activity),
        )),
      ],
    );
  }

  Widget _buildUpcomingEvents(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Text(
          'Upcoming Events',
          style: AppTextStyles.sectionTitle.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        
        const SizedBox(height: AppSpacing.md),
        
        // Event cards
        ..._getMockUpcomingEvents().map((event) => Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: _buildEventCard(context, event),
        )),
      ],
    );
  }

  Widget _buildActivityCard(BuildContext context, MockActivity activity) {
    return BaseCard(
      child: Row(
        children: [
          // Activity icon
          KyleActivityIcon(
            activityType: _mapActivityType(activity.type),
          ),
          
          const SizedBox(width: AppSpacing.md),
          
          // Activity info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.title,
                  style: AppTextStyles.activityTitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  activity.details,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          
          // Action buttons
          Row(
            children: [
              // Check button
              InkWell(
                onTap: () => _completeActivity(context, activity),
                borderRadius: AppRadius.circularRadius,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.orange,
                      width: 2,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    FontAwesomeIcons.check,
                    size: AppIconSizes.controlIcon,
                    color: AppColors.orange,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              // X button
              InkWell(
                onTap: () => _skipActivity(context, activity),
                borderRadius: AppRadius.circularRadius,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: AppColors.dragonfruit,
                      width: 2,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    FontAwesomeIcons.xmark,
                    size: AppIconSizes.controlIcon,
                    color: AppColors.dragonfruit,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(BuildContext context, MockEvent event) {
    return BaseCard(
      child: Row(
        children: [
          // Event icon
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.electrolyte.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              FontAwesomeIcons.calendar,
              size: AppIconSizes.controlIcon,
              color: AppColors.electrolyte,
            ),
          ),
          
          const SizedBox(width: AppSpacing.md),
          
          // Event info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: AppTextStyles.activityTitle.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  event.details,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          
          // Date badge
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: AppColors.blackberry,
              borderRadius: AppRadius.smRadius,
            ),
            child: Text(
              event.dateBadge,
              style: AppTextStyles.smallLabel.copyWith(
                color: AppColors.cream,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Calendar button
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              FontAwesomeIcons.calendar,
              size: AppIconSizes.md,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          
          // Menu button
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              FontAwesomeIcons.bars,
              size: AppIconSizes.md,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          
          // Add button
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.orange,
              shape: BoxShape.circle,
            ),
            child: Icon(
              FontAwesomeIcons.plus,
              size: AppIconSizes.md,
              color: AppColors.blackberry,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateMonth(int direction) {
    setState(() {
      _currentMonth = DateTime(
        _currentMonth.year,
        _currentMonth.month + direction,
      );
    });
  }

  void _goToToday() {
    setState(() {
      _currentMonth = DateTime.now();
    });
  }

  void _selectDay(int day) {
    // Track day selection
    final analytics = ref.read(appExternalDepsProvider);
    analytics.analytics.track('calendar_day_selected', properties: {
      'day': day,
      'month': _currentMonth.month,
      'year': _currentMonth.year,
    });

    // Navigate to activity detail for selected day
    context.push('/activity-detail-kyle');
  }

  void _completeActivity(BuildContext context, MockActivity activity) {
    // Track activity completion
    final analytics = ref.read(appExternalDepsProvider);
    analytics.analytics.track('activity_completed', properties: {
      'activity_id': activity.id,
      'activity_type': activity.type,
    });

    // Show completion dialog
    showDialog(
      context: context,
      builder: (context) => _ActivityCompletionDialog(activity: activity),
    );
  }

  void _skipActivity(BuildContext context, MockActivity activity) {
    // Track activity skip
    final analytics = ref.read(appExternalDepsProvider);
    analytics.analytics.track('activity_skipped', properties: {
      'activity_id': activity.id,
      'activity_type': activity.type,
    });

    // Show skip confirmation
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Activity skipped'),
        backgroundColor: AppColors.dragonfruit,
      ),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.day == now.day && 
           date.month == now.month && 
           date.year == now.year;
  }

  bool _hasEventsOnDay(int day) {
    // Mock logic - some days have events
    return day % 3 == 0 || day % 7 == 0;
  }

  List<DateTime> _getWeekDays() {
    final startOfWeek = DateTime.now();
    final weekDays = <DateTime>[];
    
    for (int i = 0; i < 7; i++) {
      weekDays.add(startOfWeek.add(Duration(days: i - startOfWeek.weekday)));
    }
    
    return weekDays;
  }

  String _formatMonthYear(DateTime date) {
    final months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  String _formatDayName(DateTime date) {
    final days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    return days[date.weekday % 7];
  }

  KyleActivityType _mapActivityType(String type) {
    switch (type.toLowerCase()) {
      case 'running':
        return KyleActivityType.running;
      case 'cycling':
        return KyleActivityType.cycling;
      case 'swimming':
        return KyleActivityType.swimming;
      default:
        return KyleActivityType.running;
    }
  }

  List<MockActivity> _getMockTodaysActivities() {
    return [
      MockActivity(
        id: '1',
        type: 'running',
        title: '10 MILE RUN',
        details: '18.8 mi • 10:30/mi',
      ),
      MockActivity(
        id: '2',
        type: 'cycling',
        title: 'HILL REPEATS',
        details: '12 mi • 15:45/mi',
      ),
    ];
  }

  List<MockEvent> _getMockUpcomingEvents() {
    return [
      MockEvent(
        id: '1',
        title: 'KULTURE CITY HALF MARATHON',
        details: '13 Days Away!',
        dateBadge: 'Nov 22',
      ),
      MockEvent(
        id: '2',
        title: 'TEAM TRAINING SESSION',
        details: '21 Days Away!',
        dateBadge: 'Nov 30',
      ),
    ];
  }
}

// Mock data classes
class MockActivity {
  final String id;
  final String type;
  final String title;
  final String details;

  MockActivity({
    required this.id,
    required this.type,
    required this.title,
    required this.details,
  });
}

class MockEvent {
  final String id;
  final String title;
  final String details;
  final String dateBadge;

  MockEvent({
    required this.id,
    required this.title,
    required this.details,
    required this.dateBadge,
  });
}

class _ActivityCompletionDialog extends StatelessWidget {
  final MockActivity activity;

  const _ActivityCompletionDialog({required this.activity});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: AppRadius.lgRadius,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Success icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.electrolyte.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(
                FontAwesomeIcons.check,
                size: AppIconSizes.xl,
                color: AppColors.electrolyte,
              ),
            ),
            
            const SizedBox(height: AppSpacing.lg),
            
            // Success message
            Text(
              'Activity Complete!',
              style: AppTextStyles.sectionTitle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            
            const SizedBox(height: AppSpacing.sm),
            
            Text(
              'Great job on your ${activity.title.toLowerCase()}! Keep up the good work.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: AppSpacing.lg),
            
            // Done button
            KylePrimaryButton(
              text: 'Done',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}