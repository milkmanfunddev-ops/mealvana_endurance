import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mealvana_endurance/theme/app_theme.dart';
import '../providers/activities_controller.dart';
import '../../../events/presentation/providers/events_controller.dart';
import '../../../events/presentation/widgets/upcoming_event_widget.dart';
import '../../../carb_loading/presentation/providers/carb_loading_controller.dart';
import '../widgets/calendar_date_picker.dart' as custom_calendar;
import '../widgets/activity_card.dart';
import '../widgets/carb_loading_day_card.dart';
import 'activity_creation_screen.dart';
import '../../../../shared/database/app_database.dart' as db;

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
  DateTime _selectedDate = DateTime.now();

  // Cache the date range to avoid creating new provider instances on every rebuild
  late final DateTime _queryStartDate = DateTime.now().subtract(const Duration(days: 365));
  late final DateTime _queryEndDate = DateTime.now().add(const Duration(days: 730));

  @override
  Widget build(BuildContext context) {
    final activitiesState = ref.watch(activitiesControllerProvider);
    final upcomingEvent = ref.watch(nextUpcomingEventProvider);
    final carbLoadingState = ref.watch(carbLoadingDaysForRangeProvider(
      _queryStartDate,
      _queryEndDate,
    ));

    return Scaffold(
      backgroundColor: AppTheme.baseCream,
      body: SafeArea(
        child: Column(
          children: [
            custom_calendar.CalendarDatePicker(
              selectedDate: _selectedDate,
              onDateSelected: (date) {
                setState(() {
                  _selectedDate = date;
                });
              },
            ),
            Expanded(
              child: _buildContent(activitiesState, upcomingEvent, carbLoadingState),
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

  Widget _buildContent(
    AsyncValue activitiesState,
    AsyncValue upcomingEvent,
    AsyncValue<List<dynamic>> carbLoadingState,
  ) {
    return activitiesState.when(
      data: (activities) {
        final carbLoadingDays = carbLoadingState.maybeWhen(
          data: (days) => days.cast<db.CarbLoadingDay>(),
          orElse: () => <db.CarbLoadingDay>[],
        );

        final selectedDateActivities = activities.where((activity) {
          return _isSameDay(activity.scheduledDateTime, _selectedDate);
        }).toList();

        final selectedDateCarbDays = carbLoadingDays.where((carbDay) {
          return _isSameDay(carbDay.planDate, _selectedDate);
        }).toList();

        final hasItems = selectedDateActivities.isNotEmpty || selectedDateCarbDays.isNotEmpty;

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(activitiesControllerProvider);
            ref.invalidate(carbLoadingControllerProvider);
            ref.invalidate(nextUpcomingEventProvider);
          },
          child: CustomScrollView(
            slivers: [
              // Upcoming Event Widget
              SliverToBoxAdapter(
                child: upcomingEvent.when(
                  data: (event) => UpcomingEventWidget(upcomingEventData: event),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ),
              // Activities and Carb Days List
              if (!hasItems)
                SliverFillRemaining(child: _buildEmptyState())
              else
                SliverPadding(
                  padding: const EdgeInsets.all(16),
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
                      childCount: (selectedDateCarbDays.length + selectedDateActivities.length) as int,
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
            _selectedDate.toString().split(' ')[0],
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[500],
                ),
          ),
        ],
      ),
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
