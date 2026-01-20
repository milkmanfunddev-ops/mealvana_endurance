import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../providers/activities_controller.dart';
import '../providers/brick_creation_available_provider.dart';
import '../providers/brick_selection_controller.dart';
import '../providers/brick_actions_controller.dart';
import '../../../calendar/presentation/providers/calendar_view_provider.dart';
import '../../../calendar/presentation/widgets/calendar_view_toggle.dart';
import '../../../calendar/presentation/widgets/calendar_week_view_kyle.dart';
import '../../../calendar/presentation/widgets/calendar_month_view_kyle.dart';
import '../../../calendar/domain/calendar_day_indicators.dart';
import '../../../calendar/presentation/providers/calendar_selected_date_provider.dart';
import '../../../events/presentation/providers/events_controller.dart';
import '../../../events/presentation/widgets/upcoming_event_card_kyle.dart';
import '../../../../shared/widgets/kyle_design/typography/section_header_text.dart';
import '../../../../shared/widgets/kyle_design/buttons/secondary_button.dart';
import '../../../carb_loading/presentation/providers/carb_loading_controller.dart';
import '../widgets/activity_card.dart';
import '../widgets/carb_loading_day_card.dart';
import '../widgets/create_brick_button.dart';
import '../widgets/brick_confirmation_dialog.dart';
import '../widgets/brick_ungroup_dialog.dart';
import '../widgets/brick_minimum_warning_dialog.dart';
import '../widgets/brick_group_card.dart';
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
            ref.invalidate(activitiesControllerProvider);
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
              // Section Header with Create Brick button
              if (hasItems)
                SliverToBoxAdapter(
                  child: _buildTodaysActivitiesHeader(
                    activities,
                    selectedDate,
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
                          final activity = selectedDateActivities[activityIndex];

                          // Get selection mode state
                          final selectionState = ref.watch(brickSelectionControllerProvider);
                          final isSelectionMode = selectionState.isSelectionMode;
                          final isSelected = ref.read(brickSelectionControllerProvider.notifier)
                              .isActivitySelected(activity.id);
                          final selectionOrder = ref.read(brickSelectionControllerProvider.notifier)
                              .getSelectionOrder(activity.id);

                          // Render brick group card for brick activities (but not in selection mode)
                          if (activity.isBrick && !isSelectionMode) {
                            return BrickGroupCard(
                              brick: activity,
                              onUngroup: () => _handleUngroupBrick(activity.id),
                              onViewCombined: () => _handleViewCombinedBrick(activity),
                              onRemoveSegment: (segmentIndex) => _handleRemoveSegment(activity.id, segmentIndex),
                            );
                          }

                          // Render regular activity card
                          return ActivityCard(
                            activity: activity,
                            isSelectionMode: isSelectionMode,
                            isSelected: isSelected,
                            selectionOrder: selectionOrder,
                            onSelectionToggle: () {
                              ref.read(brickSelectionControllerProvider.notifier)
                                  .toggleActivity(activity);
                            },
                          );
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

  /// Build the "Today's Activities" header with optional Create Brick button
  Widget _buildTodaysActivitiesHeader(
    List<Activity> activities,
    DateTime selectedDate,
  ) {
    final isBrickAvailable = ref.watch(
      isBrickCreationAvailableProvider(
        activities: activities,
        selectedDate: selectedDate,
      ),
    );

    final selectionState = ref.watch(brickSelectionControllerProvider);
    final isSelectionMode = selectionState.isSelectionMode;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SectionHeaderText(
            text: "Today's Activities",
            topPadding: 0,
            bottomPadding: 0,
          ),
          if (!isSelectionMode && isBrickAvailable)
            CreateBrickButton(
              onPressed: _handleCreateBrickPressed,
            ),
          if (isSelectionMode)
            Row(
              children: [
                KyleSecondaryButtonSmall(
                  text: "Cancel",
                  onPressed: _handleCancelSelection,
                  variant: SecondaryButtonVariant.blackberry,
                ),
                const SizedBox(width: 8),
                KyleSecondaryButtonSmall(
                  text: "Confirm (${selectionState.selectedActivityIds.length})",
                  onPressed: ref.read(brickSelectionControllerProvider.notifier).canCreateBrick()
                      ? () => _handleConfirmSelection(activities, selectedDate)
                      : null,
                  variant: SecondaryButtonVariant.orange,
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// Handle Create Brick button press
  /// Enters selection mode to choose activities for brick creation
  void _handleCreateBrickPressed() {
    ref.read(brickSelectionControllerProvider.notifier).enterSelectionMode();
  }

  /// Handle Cancel button press in selection mode
  /// Exits selection mode and clears all selections
  void _handleCancelSelection() {
    ref.read(brickSelectionControllerProvider.notifier).exitSelectionMode();
  }

  /// Handle Confirm button press in selection mode
  /// Shows confirmation dialog and creates brick from selected activities
  Future<void> _handleConfirmSelection(
    List<Activity> activities,
    DateTime selectedDate,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final selectionController = ref.read(brickSelectionControllerProvider.notifier);
    final actionsController = ref.read(brickActionsControllerProvider.notifier);

    // Get selected activity IDs in order
    final selectedIds = selectionController.getSelectedOrder();

    // Get full Activity objects in the same order
    final selectedActivities = selectedIds
        .map((id) => activities.firstWhere((a) => a.id == id))
        .toList();

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => BrickConfirmationDialog(
        selectedActivities: selectedActivities,
      ),
    );

    if (confirmed != true) {
      return; // User cancelled
    }

    try {
      // Show loading indicator
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Creating brick workout...'),
          duration: Duration(seconds: 2),
        ),
      );

      // Call controller to create brick (follows FOA pattern - business logic in controller)
      await actionsController.createBrickFromSelection(
        activities: selectedActivities,
        segmentOrder: selectedIds,
      );

      // Exit selection mode
      selectionController.exitSelectionMode();

      // Refresh activities list
      ref.invalidate(activitiesControllerProvider);

      // Show success message
      messenger.clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Brick workout created successfully!'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error creating brick: $e'),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  /// Handle Ungroup button press on brick group card
  /// Shows confirmation dialog and ungroups brick back to standalone activities
  Future<void> _handleUngroupBrick(String brickId) async {
    final messenger = ScaffoldMessenger.of(context);
    final actionsController = ref.read(brickActionsControllerProvider.notifier);

    // Get segment count for dialog message
    final activitiesState = ref.read(activitiesControllerProvider);

    // Use maybeWhen to safely extract activities list
    final activities = activitiesState.maybeWhen(
      data: (activitiesData) => (activitiesData as List).cast<Activity>(),
      orElse: () => <Activity>[],
    );

    final brick = activities.firstWhere(
      (a) => a.id == brickId,
      orElse: () => throw StateError('Brick not found'),
    );

    final segmentCount = brick.brickMetadata?.segments.length ?? 0;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => BrickUngroupDialog(
        segmentCount: segmentCount,
      ),
    );

    if (confirmed != true) {
      return; // User cancelled
    }

    try {
      // Show loading indicator
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Ungrouping brick...'),
          duration: Duration(seconds: 2),
        ),
      );

      // Call controller to ungroup brick
      await actionsController.ungroupBrick(brickId);

      // Refresh activities list
      ref.invalidate(activitiesControllerProvider);

      // Show success message
      messenger.clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Brick ungrouped successfully!'),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      messenger.clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error ungrouping brick: $e'),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  /// Handle View Combined button press on brick group card
  /// Navigates to activity details screen or new activity screen based on nutrition plan status
  void _handleViewCombinedBrick(Activity brick) {
    // TODO: Implement navigation to brick detail screen (Phase 5)
    // For now, show a placeholder message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('View Combined navigation not yet implemented (Phase 5)'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  /// Handle Remove Segment button press on brick segment card
  /// Shows warning dialog if this would leave only 1 sport
  Future<void> _handleRemoveSegment(String brickId, int segmentIndex) async {
    final messenger = ScaffoldMessenger.of(context);

    // Get brick activity
    final activitiesState = ref.read(activitiesControllerProvider);

    // Use maybeWhen to safely extract activities list
    final activities = activitiesState.maybeWhen(
      data: (activitiesData) => (activitiesData as List).cast<Activity>(),
      orElse: () => <Activity>[],
    );

    final brick = activities.firstWhere(
      (a) => a.id == brickId,
      orElse: () => throw StateError('Brick not found'),
    );

    final segmentCount = brick.brickMetadata?.segments.length ?? 0;

    // If removing this segment would leave only 1 sport, show warning dialog
    if (segmentCount <= 2) {
      final shouldUngroup = await showDialog<bool>(
        context: context,
        builder: (context) => const BrickMinimumWarningDialog(),
      );

      if (shouldUngroup == true) {
        // User wants to ungroup entirely
        await _handleUngroupBrick(brickId);
      }
      return;
    }

    // If 3+ segments, remove segment is not yet implemented
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Remove segment feature not yet implemented'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
