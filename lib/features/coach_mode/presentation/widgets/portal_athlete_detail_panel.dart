import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/database/app_database.dart' as db;
import '../../../../shared/widgets/content_area.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../activities/domain/activity.dart';
import '../../../calendar/domain/calendar_day_indicators.dart';
import '../../../calendar/presentation/providers/calendar_view_provider.dart';
import '../../../calendar/presentation/widgets/calendar_view_toggle.dart';
import '../../../calendar/presentation/widgets/calendar_week_view_kyle.dart';
import '../../../calendar/presentation/widgets/calendar_month_view_kyle.dart';
import '../../../../shared/widgets/kyle_design/feedback/mealvana_snackbar.dart';
import '../../domain/coach_athlete_relationship.dart';
import '../../../carb_loading/presentation/screens/carb_loading_day_detail_page.dart';
import '../providers/athlete_detail_controller.dart';
import '../providers/coach_portal_controller.dart';
import '../screens/coach_chat_screen.dart';
import 'portal_athlete_profile_form.dart';
import 'create_carb_loading_dialog.dart';
import '../../../events/presentation/screens/event_detail_screen.dart';
import 'portal_nutrition_targets_form.dart';

/// Right panel showing athlete details within the coach portal
class PortalAthleteDetailPanel extends ConsumerStatefulWidget {
  final String relationshipId;

  const PortalAthleteDetailPanel({super.key, required this.relationshipId});

  @override
  ConsumerState<PortalAthleteDetailPanel> createState() =>
      _PortalAthleteDetailPanelState();
}

class _PortalAthleteDetailPanelState
    extends ConsumerState<PortalAthleteDetailPanel>
    with SingleTickerProviderStateMixin {
  DateTime _selectedDate = DateTime.now();
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    final portalState = ref.read(coachPortalControllerProvider);
    _tabController = TabController(
      length: 6,
      initialIndex: portalState.initialTabIndex.clamp(0, 5),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(
      athleteDetailControllerProvider(widget.relationshipId),
    );

    return Container(
      color: AppColors.blackberryDark,
      child: detailAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.electrolyte),
        ),
        error: (error, _) => _buildErrorView(error.toString()),
        data: (state) => _buildContent(state),
      ),
    );
  }

  Widget _buildErrorView(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: AppColors.dragonfruit,
            ),
            const SizedBox(height: 16),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textDarkSecondary),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.electrolyte,
              ),
              onPressed: () {
                ref
                    .read(
                      athleteDetailControllerProvider(
                        widget.relationshipId,
                      ).notifier,
                    )
                    .refresh();
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(AthleteDetailState state) {
    return Column(
      children: [
        // Athlete header
        _buildAthleteHeader(state),

        // Tab bar
        Container(
          color: AppColors.blackberry,
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.electrolyte,
            unselectedLabelColor: AppColors.textDarkSecondary,
            indicatorColor: AppColors.electrolyte,
            dividerColor: AppColors.blackberryLight,
            tabs: [
              const Tab(icon: Icon(Icons.person, size: 18), text: 'Profile'),
              const Tab(icon: Icon(Icons.tune, size: 18), text: 'Targets'),
              Tab(
                icon: const Icon(Icons.calendar_today, size: 18),
                text: 'Events (${state.events.length})',
              ),
              const Tab(
                icon: Icon(Icons.restaurant, size: 18),
                text: 'Carb Loading',
              ),
              Tab(
                icon: const Icon(Icons.directions_run, size: 18),
                text: 'Activities (${state.activities.length})',
              ),
              const Tab(icon: Icon(Icons.chat, size: 18), text: 'Chat'),
            ],
          ),
        ),

        // Tab views — constrained so forms don't stretch on wide screens
        Expanded(
          child: ContentArea.wide(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProfileTab(state),
                _buildNutritionTargetsTab(state),
                _buildEventsTab(state),
                _buildCarbLoadingTab(state),
                _buildActivitiesTab(state),
                _buildChatTab(state),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAthleteHeader(AthleteDetailState state) {
    final relationship = state.relationship;
    final athleteProfile = state.athleteProfile;

    String athleteName;
    if (athleteProfile != null) {
      athleteName = athleteProfile.displayName;
    } else {
      athleteName =
          relationship.athleteDisplayName ??
          'Athlete ${relationship.athleteUserId.substring(0, 8)}...';
    }

    return Container(
      padding: const EdgeInsets.all(16),
      color: AppColors.blackberry,
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.electrolyte,
            child: Text(
              _getInitials(athleteName),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.blackberryDark,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  athleteName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.cream,
                  ),
                ),
                const SizedBox(height: 4),
                _buildStatusChip(relationship.status),
              ],
            ),
          ),
          // Refresh button
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textDarkSecondary),
            tooltip: 'Refresh athlete data',
            onPressed: () {
              ref
                  .read(
                    athleteDetailControllerProvider(
                      widget.relationshipId,
                    ).notifier,
                  )
                  .refresh();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(RelationshipStatus status) {
    final (label, color) = switch (status) {
      RelationshipStatus.active => ('Active', AppColors.electrolyte),
      RelationshipStatus.pending => ('Pending', AppColors.orange),
      RelationshipStatus.declined => ('Declined', AppColors.dragonfruit),
      RelationshipStatus.archived => ('Archived', AppColors.inactive),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildProfileTab(AthleteDetailState state) {
    return PortalAthleteProfileForm(
      key: ValueKey('profile_${state.relationship.athleteUserId}'),
      relationshipId: widget.relationshipId,
      profile: state.athleteProfile,
      athleteUserId: state.relationship.athleteUserId,
    );
  }

  Widget _buildNutritionTargetsTab(AthleteDetailState state) {
    return PortalNutritionTargetsForm(
      key: ValueKey('targets_${state.relationship.athleteUserId}'),
      relationshipId: widget.relationshipId,
      athleteProfile: state.athleteProfile,
    );
  }

  Widget _buildEventsTab(AthleteDetailState state) {
    return Stack(
      children: [
        if (state.events.isEmpty)
          _buildEmptyView(
            'No Events',
            'This athlete has no upcoming events.',
            Icons.calendar_today,
          )
        else
          ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: state.events.length,
            itemBuilder: (context, index) {
              final event = state.events[index];
              return GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EventDetailScreen(
                        eventId: event.id,
                        forUserId: state.relationship.athleteUserId,
                      ),
                    ),
                  );
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.blackberry,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.blackberryLight),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.event,
                        color: AppColors.electrolyte,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.eventName ?? 'Unnamed Event',
                              style: const TextStyle(
                                color: AppColors.cream,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              event.eventDate != null
                                  ? _formatDate(event.eventDate!)
                                  : 'Date TBD',
                              style: const TextStyle(
                                color: AppColors.textDarkSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: AppColors.textDarkSecondary,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        // Create event FAB
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            heroTag: 'createEvent',
            mini: true,
            backgroundColor: AppColors.electrolyte,
            foregroundColor: AppColors.blackberryDark,
            onPressed: () => _navigateToCreateEvent(state),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  Future<void> _navigateToCreateEvent(AthleteDetailState state) async {
    final result = await context.push(
      '/events/create',
      extra: {'forUserId': state.relationship.athleteUserId},
    );
    if (!mounted) return;

    // Always refresh after returning — the event may have been created
    // even if the result doesn't explicitly indicate success
    ref
        .read(athleteDetailControllerProvider(widget.relationshipId).notifier)
        .refresh();

    if (result is Map && result['success'] == true) {
      MealvanaSnackbar.showSuccess(context, 'Event created');

      // Navigate to event detail screen so coach can review and manage the event
      final eventId = result['eventId'] as String?;
      if (eventId != null && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EventDetailScreen(
              eventId: eventId,
              forUserId: state.relationship.athleteUserId,
            ),
          ),
        );
      }
    }
  }

  Future<void> _showCreateCarbLoadingDialog(AthleteDetailState state) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => CreateCarbLoadingDialog(
        events: state.events,
        athleteWeightPounds: state.athleteProfile?.weightPounds,
      ),
    );
    if (result == null || !mounted) return;

    try {
      await ref
          .read(athleteDetailControllerProvider(widget.relationshipId).notifier)
          .createCarbLoadingPlan(
            eventId: result['eventId'] as String?,
            protocolDays: result['protocolDays'] as int,
            raceDate: result['raceDate'] as DateTime,
            bodyWeightPounds: result['bodyWeightPounds'] as double,
          );

      if (!mounted) return;
      MealvanaSnackbar.showSuccess(context, 'Carb loading plan created');
    } catch (e) {
      if (!mounted) return;
      MealvanaSnackbar.showError(context, 'Failed to create plan: $e');
    }
  }

  Widget _buildCarbLoadingTab(AthleteDetailState state) {
    final carbLoadingDays = state.carbLoadingDays;

    return Stack(
      children: [
        if (carbLoadingDays.isEmpty)
          _buildEmptyView(
            'No Carb Loading Days',
            'This athlete has no carb loading days yet.',
            Icons.restaurant,
          )
        else
          ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: carbLoadingDays.length,
            itemBuilder: (context, index) {
              final carbLoadingDay = carbLoadingDays[index];
              final progressLabel =
                  '${carbLoadingDay.loggedCarbsGrams}/${carbLoadingDay.carbTargetGrams}g';

              return GestureDetector(
                onTap: () => _openCarbLoadingDay(carbLoadingDay),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.blackberry,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.blackberryLight),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.restaurant_menu,
                        color: AppColors.electrolyte,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Carb Loading Day ${carbLoadingDay.dayNumber}',
                              style: const TextStyle(
                                color: AppColors.cream,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Text(
                              '${_formatDate(carbLoadingDay.planDate)} • $progressLabel',
                              style: const TextStyle(
                                color: AppColors.textDarkSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        carbLoadingDay.completed
                            ? Icons.check_circle
                            : Icons.chevron_right,
                        color: carbLoadingDay.completed
                            ? AppColors.electrolyte
                            : AppColors.textDarkSecondary,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        // Create carb loading plan FAB
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            heroTag: 'createCarbLoading',
            mini: true,
            backgroundColor: AppColors.electrolyte,
            foregroundColor: AppColors.blackberryDark,
            onPressed: () => _showCreateCarbLoadingDialog(state),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  Future<void> _openCarbLoadingDay(db.CarbLoadingDay carbLoadingDay) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            CarbLoadingDayDetailPage(carbLoadingDay: carbLoadingDay),
      ),
    );

    if (!mounted) return;
    ref
        .read(athleteDetailControllerProvider(widget.relationshipId).notifier)
        .refresh();
  }

  Widget _buildActivitiesTab(AthleteDetailState state) {
    final calendarMode = ref.watch(calendarViewProvider);
    final dayIndicators = _buildDayIndicatorsMap(state);

    final selectedDateActivities =
        state.activities.where((activity) {
            return _isSameDay(activity.scheduledDateTime, _selectedDate);
          }).toList()
          ..sort((a, b) => a.scheduledDateTime.compareTo(b.scheduledDateTime));

    return Stack(
      children: [
        Column(
          children: [
            SizedBox(height: kIsWeb ? 20 : 4),
            CalendarViewToggle(
              selectedMode: calendarMode,
              onModeChanged: (mode) {
                ref.read(calendarViewProvider.notifier).setView(mode);
              },
            ),
            const SizedBox(height: 8),
            if (calendarMode == CalendarViewMode.week)
              CalendarWeekViewKyle(
                selectedDate: _selectedDate,
                onDateSelected: (date) {
                  setState(() {
                    _selectedDate = date;
                  });
                },
                dayIndicators: dayIndicators,
              )
            else
              CalendarMonthViewKyle(
                selectedDate: _selectedDate,
                onDateSelected: (date) {
                  setState(() {
                    _selectedDate = date;
                  });
                },
                dayIndicators: dayIndicators,
              ),
            const SizedBox(height: 8),
            Expanded(
              child: selectedDateActivities.isEmpty
                  ? _buildEmptyActivitiesForDate()
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: selectedDateActivities.length,
                      itemBuilder: (context, index) {
                        final activity = selectedDateActivities[index];
                        return _buildActivityItem(activity);
                      },
                    ),
            ),
          ],
        ),
        // Create activity FAB
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            heroTag: 'createActivity',
            mini: true,
            backgroundColor: AppColors.electrolyte,
            foregroundColor: AppColors.blackberryDark,
            onPressed: () => _navigateToCreateActivity(state),
            child: const Icon(Icons.add),
          ),
        ),
      ],
    );
  }

  Future<void> _navigateToCreateActivity(AthleteDetailState state) async {
    await context.push(
      '/distancepacegut',
      extra: {
        'forUserId': state.relationship.athleteUserId,
        'initialDate': _selectedDate,
      },
    );
    if (!mounted) return;

    ref
        .read(athleteDetailControllerProvider(widget.relationshipId).notifier)
        .refresh();
  }

  Widget _buildActivityItem(Activity activity) {
    return GestureDetector(
      onTap: () {
        context.push(
          '/plan',
          extra: {'activityId': activity.id, 'isCoachView': true},
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.blackberry,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.blackberryLight),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.directions_run,
              color: AppColors.electrolyte,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.title,
                    style: const TextStyle(
                      color: AppColors.cream,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    '${activity.distanceMiles?.toStringAsFixed(1) ?? "-"} mi - ${_formatDate(activity.scheduledDateTime)}',
                    style: const TextStyle(
                      color: AppColors.textDarkSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: AppColors.textDarkSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatTab(AthleteDetailState state) {
    // Embed the chat screen inline within the portal
    return CoachChatScreen(relationshipId: widget.relationshipId);
  }

  Map<DateTime, Set<DayIndicatorType>> _buildDayIndicatorsMap(
    AthleteDetailState state,
  ) {
    final map = <DateTime, Set<DayIndicatorType>>{};

    for (final activity in state.activities) {
      final date = DateTime(
        activity.scheduledDateTime.year,
        activity.scheduledDateTime.month,
        activity.scheduledDateTime.day,
      );
      map.putIfAbsent(date, () => {}).add(DayIndicatorType.activity);
    }

    for (final event in state.events) {
      if (event.eventDate != null) {
        final date = DateTime(
          event.eventDate!.year,
          event.eventDate!.month,
          event.eventDate!.day,
        );
        map.putIfAbsent(date, () => {}).add(DayIndicatorType.event);
      }
    }

    for (final plan in state.carbLoadingPlans) {
      final raceDate = DateTime(
        plan.raceDate.year,
        plan.raceDate.month,
        plan.raceDate.day,
      );
      map.putIfAbsent(raceDate, () => {}).add(DayIndicatorType.carbLoading);
    }

    return map;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildEmptyActivitiesForDate() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.calendar_today, size: 40, color: AppColors.inactive),
          const SizedBox(height: 12),
          Text(
            'No activities on ${_formatDate(_selectedDate)}',
            style: const TextStyle(color: AppColors.textDarkSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView(String title, String message, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: AppColors.inactive),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: AppColors.cream,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textDarkSecondary,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
  }
}
