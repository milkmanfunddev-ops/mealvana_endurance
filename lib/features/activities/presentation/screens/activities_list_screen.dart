import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../providers/activities_controller.dart';
import '../../../calendar/presentation/providers/calendar_view_provider.dart';
import '../../../calendar/presentation/widgets/calendar_view_toggle.dart';
import '../../../calendar/presentation/widgets/calendar_week_view_kyle.dart';
import '../../../calendar/presentation/widgets/calendar_month_view_kyle.dart';
import '../../../calendar/domain/calendar_day_indicators.dart';
import '../../../calendar/presentation/providers/calendar_selected_date_provider.dart';
import '../../../events/presentation/providers/events_controller.dart';
import '../../../events/presentation/widgets/upcoming_event_card_kyle.dart';
import '../../../../shared/widgets/kyle_design/typography/section_header_text.dart';
import '../../../carb_loading/presentation/providers/carb_loading_controller.dart';
import '../widgets/activity_card.dart';
import '../widgets/carb_loading_day_card.dart';
import '../../../../shared/database/app_database.dart' as db;
import '../../domain/activity.dart';

/// Main screen showing calendar date picker and daily activity list.
///
/// This is the PRIMARY tab in the app, showing:
/// - Calendar date picker at top (week or month view)
/// - Upcoming Event widget (if event exists)
/// - Daily activity list for selected date
/// - FAB to create new activities
class ActivitiesListScreen extends ConsumerStatefulWidget {
  const ActivitiesListScreen({super.key});

  @override
  ConsumerState<ActivitiesListScreen> createState() => _ActivitiesListScreenState();
}

class _ActivitiesListScreenState extends ConsumerState<ActivitiesListScreen> {
  // Cache the date range to avoid creating new provider instances on every rebuild
  late final DateTime _queryStartDate = DateTime.now().subtract(const Duration(days: 365));
  late final DateTime _queryEndDate = DateTime.now().add(const Duration(days: 730));

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(calendarSelectedDateProvider);
    final activitiesState = ref.watch(activitiesControllerProvider);
    final upcomingEvent = ref.watch(nextUpcomingEventProvider);
    final allEventsState = ref.watch(allEventsProvider);
    final carbLoadingState = ref.watch(carbLoadingDaysForRangeProvider(
      _queryStartDate,
      _queryEndDate,
    ));
    final calendarMode = ref.watch(calendarViewProvider);

    // Build comprehensive indicator map for calendar dots
    final dayIndicators = _buildDayIndicatorsMap(
      activitiesState,
      allEventsState,
      carbLoadingState,
    );

    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.blackberry : AppColors.cream,
      body: Column(
        children: [
          // Top padding to account for status bar
          SizedBox(height: MediaQuery.of(context).padding.top + 12),
          // Calendar view toggle
          CalendarViewToggle(
            selectedMode: calendarMode,
            onModeChanged: (mode) {
              ref.read(calendarViewProvider.notifier).setView(mode);
            },
          ),
          const SizedBox(height: 8),
          // Calendar (week or month view)
          if (calendarMode == CalendarViewMode.week)
            CalendarWeekViewKyle(
              selectedDate: selectedDate,
              onDateSelected: (date) {
                ref.read(calendarSelectedDateProvider.notifier).setDate(date);
              },
              dayIndicators: dayIndicators,
            )
          else
            CalendarMonthViewKyle(
              selectedDate: selectedDate,
              onDateSelected: (date) {
                ref.read(calendarSelectedDateProvider.notifier).setDate(date);
              },
              dayIndicators: dayIndicators,
            ),
          Expanded(
            child: _buildContent(activitiesState, upcomingEvent, carbLoadingState, selectedDate),
          ),
        ],
      ),
      // FloatingActionButton removed - now in FloatingActionButtonsBar
    );
  }

  /// Build comprehensive map of day indicators for calendar dots
  /// Combines activities, events, and carb loading days
  Map<DateTime, Set<DayIndicatorType>> _buildDayIndicatorsMap(
    AsyncValue activitiesState,
    AsyncValue allEventsState,
    AsyncValue<List<dynamic>> carbLoadingState,
  ) {
    final map = <DateTime, Set<DayIndicatorType>>{};

    // Add activity indicators
    activitiesState.whenData((activities) {
      for (final activity in activities) {
        final date = DateTime(
          activity.scheduledDateTime.year,
          activity.scheduledDateTime.month,
          activity.scheduledDateTime.day,
        );
        map.putIfAbsent(date, () => {}).add(DayIndicatorType.activity);
      }
    });

    // Add event indicators
    allEventsState.whenData((events) {
      for (final event in events) {
        // Use the dedicated eventDate field
        if (event.eventDate != null) {
          final date = DateTime(
            event.eventDate!.year,
            event.eventDate!.month,
            event.eventDate!.day,
          );
          map.putIfAbsent(date, () => {}).add(DayIndicatorType.event);
        }
      }
    });

    // Add carb loading indicators
    carbLoadingState.whenData((carbDays) {
      final carbLoadingDays = carbDays.cast<db.CarbLoadingDay>();
      for (final carbDay in carbLoadingDays) {
        final date = DateTime(
          carbDay.planDate.year,
          carbDay.planDate.month,
          carbDay.planDate.day,
        );
        map.putIfAbsent(date, () => {}).add(DayIndicatorType.carbLoading);
      }
    });

    return map;
  }

  Widget _buildContent(
    AsyncValue activitiesState,
    AsyncValue upcomingEvent,
    AsyncValue<List<dynamic>> carbLoadingState,
    DateTime selectedDate,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return activitiesState.when(
      data: (activitiesData) {
        // Cast to proper type since AsyncValue loses generic type info
        final activities = (activitiesData as List).cast<Activity>();

        final carbLoadingDays = carbLoadingState.maybeWhen(
          data: (days) => days.cast<db.CarbLoadingDay>(),
          orElse: () => <db.CarbLoadingDay>[],
        );

        final selectedDateActivities = activities.where((activity) {
          return _isSameDay(activity.scheduledDateTime, selectedDate);
        }).toList();
        // Sort by time (ascending) so morning activities appear before afternoon
        selectedDateActivities.sort((a, b) => a.scheduledDateTime.compareTo(b.scheduledDateTime));

        final selectedDateCarbDays = carbLoadingDays.where((carbDay) {
          return _isSameDay(carbDay.planDate, selectedDate);
        }).toList();

        final hasItems = selectedDateActivities.isNotEmpty || selectedDateCarbDays.isNotEmpty;

        return RefreshIndicator(
          onRefresh: () async {
            // Force sync from Supabase to get coach changes
            await ref.read(activitiesControllerProvider.notifier).forceRefresh();
            // Also refresh related providers
            ref.invalidate(carbLoadingControllerProvider);
            ref.invalidate(nextUpcomingEventProvider);
          },
          child: CustomScrollView(
            slivers: [
              // Upcoming Events Section Header
              const SliverToBoxAdapter(
                child: SectionHeaderText(text: "Upcoming Events"),
              ),
              // Upcoming Event Card
              SliverToBoxAdapter(
                child: upcomingEvent.when(
                  data: (event) => UpcomingEventCardKyle(upcomingEventData: event),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),
              // Divider between Upcoming Events and Today's Activities
              SliverToBoxAdapter(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  height: 1,
                  color: (isDark ? AppColors.cream : AppColors.blackberry).withValues(alpha: 0.2),
                ),
              ),
              // Section Header
              if (hasItems)
                const SliverToBoxAdapter(
                  child: SectionHeaderText(
                    text: "Today's Activities",
                    topPadding: 0,
                  ),
                ),
              // Activities and Carb Days List
              if (!hasItems)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 24, left: 16, right: 16),
                    child: _buildEmptyState(selectedDate),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final carbDayCount = selectedDateCarbDays.length;
                        if (index < carbDayCount) {
                          return CarbLoadingDayCard(carbDay: selectedDateCarbDays[index]);
                        } else {
                          final activityIndex = index - carbDayCount;
                          return ActivityCard(activity: selectedDateActivities[activityIndex]);
                        }
                      },
                      childCount: (selectedDateCarbDays.length + selectedDateActivities.length),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => _buildErrorState(error),
    );
  }

  Widget _buildEmptyState(DateTime selectedDate) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
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
          selectedDate.toString().split(' ')[0],
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[500],
              ),
        ),
      ],
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 48, color: Colors.red),
          const SizedBox(height: 16),
          Text('Error loading activities: $error'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              ref.invalidate(activitiesControllerProvider);
              ref.invalidate(carbLoadingControllerProvider);
              ref.invalidate(nextUpcomingEventProvider);
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}
