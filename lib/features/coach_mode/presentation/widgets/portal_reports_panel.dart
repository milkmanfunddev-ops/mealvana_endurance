import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../providers/coach_reports_controller.dart';

/// Reports panel with two-level view:
/// 1. Triage overview (default): compact row per athlete
/// 2. Athlete dashboard: metric cards + activity table (when athlete selected)
class PortalReportsPanel extends ConsumerWidget {
  const PortalReportsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportsAsync = ref.watch(coachReportsControllerProvider);

    return Container(
      color: AppColors.blackberryDark,
      child: reportsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.electrolyte),
        ),
        error: (error, _) => _buildError(ref, error),
        data: (state) => _buildContent(context, ref, state),
      ),
    );
  }

  Widget _buildError(WidgetRef ref, Object error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline,
              size: 48, color: AppColors.dragonfruit),
          const SizedBox(height: 16),
          Text(
            error.toString(),
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textDarkSecondary),
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () =>
                ref.read(coachReportsControllerProvider.notifier).refresh(),
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
            style:
                TextButton.styleFrom(foregroundColor: AppColors.electrolyte),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, WidgetRef ref, CoachReportsState state) {
    return Column(
      children: [
        _ReportsHeader(state: state),
        const Divider(height: 1, color: AppColors.blackberryLight),
        Expanded(
          child: state.isTriageView
              ? _TriageOverview(state: state)
              : _AthleteDashboard(state: state),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Header with date range toggle + refresh
// ---------------------------------------------------------------------------

class _ReportsHeader extends ConsumerWidget {
  const _ReportsHeader({required this.state});
  final CoachReportsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.blackberry,
      child: Row(
        children: [
          // Back button when in athlete detail
          if (!state.isTriageView) ...[
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 20),
              color: AppColors.textDarkSecondary,
              tooltip: 'Back to overview',
              onPressed: () => ref
                  .read(coachReportsControllerProvider.notifier)
                  .backToOverview(),
            ),
            const SizedBox(width: 4),
          ],
          const Icon(Icons.bar_chart, color: AppColors.electrolyte, size: 24),
          const SizedBox(width: 12),
          Text(
            state.isTriageView
                ? 'Athlete Reports'
                : state.selectedReport?.relationship.athleteDisplayName ??
                    'Athlete Report',
            style: const TextStyle(
              color: AppColors.cream,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          // Date range chips
          _DateChip(
            label: 'This Week',
            isSelected:
                state.dateRange.type == ReportsDateRangeType.thisWeek,
            onTap: () => ref
                .read(coachReportsControllerProvider.notifier)
                .setDateRange(const ReportsDateRange.thisWeek()),
          ),
          const SizedBox(width: 6),
          _DateChip(
            label: 'Last Week',
            isSelected:
                state.dateRange.type == ReportsDateRangeType.lastWeek,
            onTap: () => ref
                .read(coachReportsControllerProvider.notifier)
                .setDateRange(const ReportsDateRange.lastWeek()),
          ),
          const SizedBox(width: 6),
          _DateChip(
            label: state.dateRange.type == ReportsDateRangeType.custom
                ? state.dateRange.label
                : 'Custom...',
            isSelected:
                state.dateRange.type == ReportsDateRangeType.custom,
            onTap: () => _showDateRangePicker(context, ref),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            color: AppColors.textDarkSecondary,
            tooltip: 'Refresh',
            onPressed: () =>
                ref.read(coachReportsControllerProvider.notifier).refresh(),
          ),
        ],
      ),
    );
  }

  Future<void> _showDateRangePicker(
      BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 90)),
      initialDateRange: state.dateRange.type == ReportsDateRangeType.custom
          ? DateTimeRange(
              start: state.dateRange.resolvedStart,
              end: state.dateRange.resolvedEnd
                  .subtract(const Duration(days: 1)),
            )
          : DateTimeRange(
              start: state.dateRange.resolvedStart,
              end: state.dateRange.resolvedEnd
                  .subtract(const Duration(days: 1)),
            ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppColors.electrolyte,
              onPrimary: AppColors.blackberry,
              surface: AppColors.blackberry,
              onSurface: AppColors.cream,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      ref.read(coachReportsControllerProvider.notifier).setDateRange(
            ReportsDateRange.custom(picked.start, picked.end),
          );
    }
  }
}

class _DateChip extends StatelessWidget {
  const _DateChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected
          ? AppColors.electrolyte.withValues(alpha: 0.2)
          : AppColors.blackberryDark,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? AppColors.electrolyte
                  : AppColors.blackberryLight,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: isSelected
                  ? AppColors.electrolyte
                  : AppColors.textDarkSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Level 1: Triage Overview
// ---------------------------------------------------------------------------

class _TriageOverview extends ConsumerWidget {
  const _TriageOverview({required this.state});
  final CoachReportsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.overviews.isEmpty) {
      return const Center(
        child: Text(
          'No athletes connected yet.',
          style: TextStyle(color: AppColors.textDarkSecondary),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Table header
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.blackberry,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(8)),
              border: Border.all(color: AppColors.blackberryLight),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text('Athlete',
                      style: TextStyle(
                          color: AppColors.textDarkSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Completed',
                      style: TextStyle(
                          color: AppColors.textDarkSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Fuel Logs',
                      style: TextStyle(
                          color: AppColors.textDarkSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
                Expanded(
                  flex: 2,
                  child: Text('Adherence',
                      style: TextStyle(
                          color: AppColors.textDarkSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
                Expanded(
                  flex: 3,
                  child: Text('Last Completed',
                      style: TextStyle(
                          color: AppColors.textDarkSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
                Expanded(
                  flex: 3,
                  child: Text('Next Event',
                      style: TextStyle(
                          color: AppColors.textDarkSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          // Table rows
          ...state.overviews.map((overview) => _TriageRow(overview: overview)),
          // Footer hint
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Click any row to see their full report',
              style: TextStyle(
                color: AppColors.textDarkSecondary.withValues(alpha: 0.6),
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

class _TriageRow extends ConsumerWidget {
  const _TriageRow({required this.overview});
  final AthleteOverview overview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = overview.relationship.athleteDisplayName ??
        'Athlete ${overview.relationship.athleteUserId.substring(0, 8)}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          ref
              .read(coachReportsControllerProvider.notifier)
              .selectAthlete(overview.relationship.id);
        },
        hoverColor: AppColors.blackberryLight.withValues(alpha: 0.3),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: AppColors.blackberryLight),
              right: BorderSide(color: AppColors.blackberryLight),
              bottom: BorderSide(color: AppColors.blackberryLight),
            ),
          ),
          child: Row(
            children: [
              // Athlete name
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: AppColors.electrolyte,
                      child: Text(
                        _getInitials(name),
                        style: const TextStyle(
                          color: AppColors.blackberry,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          color: AppColors.cream,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              // Completed
              Expanded(
                flex: 2,
                child: Text(
                  '${overview.activitiesCompleted}/${overview.activitiesPlanned}',
                  style: TextStyle(
                    color: overview.activitiesPlanned > 0
                        ? AppColors.cream
                        : AppColors.textDarkSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              // Fuel logs
              Expanded(
                flex: 2,
                child: Text(
                  overview.fuelLogsCount > 0
                      ? '${overview.fuelLogsCount}/${overview.activitiesCompleted > 0 ? overview.activitiesCompleted : overview.activitiesPlanned}'
                      : '--',
                  style: TextStyle(
                    color: overview.fuelLogsCount > 0
                        ? AppColors.cream
                        : AppColors.textDarkSecondary,
                    fontSize: 13,
                  ),
                ),
              ),
              // Adherence
              Expanded(
                flex: 2,
                child: Text(
                  overview.avgAdherence != null
                      ? '${(overview.avgAdherence! * 100).round()}%'
                      : '--',
                  style: TextStyle(
                    color: overview.avgAdherence != null
                        ? (overview.avgAdherence! >= 0.8
                            ? AppColors.electrolyte
                            : AppColors.orange)
                        : AppColors.textDarkSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              // Last completed
              Expanded(
                flex: 3,
                child: overview.lastCompletedActivityName != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            overview.lastCompletedActivityName!,
                            style: const TextStyle(
                              color: AppColors.cream,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (overview.lastCompletedDate != null)
                            Text(
                              DateFormat.MMMd()
                                  .format(overview.lastCompletedDate!),
                              style: const TextStyle(
                                color: AppColors.textDarkSecondary,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      )
                    : const Text(
                        '--',
                        style: TextStyle(
                          color: AppColors.textDarkSecondary,
                          fontSize: 13,
                        ),
                      ),
              ),
              // Next event
              Expanded(
                flex: 3,
                child: overview.nextEventName != null
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            overview.nextEventName!,
                            style: const TextStyle(
                              color: AppColors.cream,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (overview.nextEventDate != null)
                            Text(
                              DateFormat.MMMd()
                                  .format(overview.nextEventDate!),
                              style: const TextStyle(
                                color: AppColors.textDarkSecondary,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      )
                    : const Text(
                        '--',
                        style: TextStyle(
                          color: AppColors.textDarkSecondary,
                          fontSize: 13,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getInitials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0].isNotEmpty ? parts[0][0].toUpperCase() : '?';
  }
}

// ---------------------------------------------------------------------------
// Level 2: Athlete Dashboard
// ---------------------------------------------------------------------------

class _AthleteDashboard extends ConsumerWidget {
  const _AthleteDashboard({required this.state});
  final CoachReportsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final report = state.selectedReport;

    // Loading state while detail is being fetched
    if (report == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.electrolyte),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ActivityTable(activities: report.activities),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Activity Table
// ---------------------------------------------------------------------------

class _ActivityTable extends StatefulWidget {
  const _ActivityTable({required this.activities});
  final List<ActivityReportItem> activities;

  @override
  State<_ActivityTable> createState() => _ActivityTableState();
}

class _ActivityTableState extends State<_ActivityTable> {
  String? _expandedActivityId;

  @override
  Widget build(BuildContext context) {
    if (widget.activities.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.blackberry,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.blackberryLight),
        ),
        child: const Center(
          child: Text(
            'No activities in this period.',
            style: TextStyle(color: AppColors.textDarkSecondary),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Table header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.blackberry,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(8)),
            border: Border.all(color: AppColors.blackberryLight),
          ),
          child: const Row(
            children: [
              Expanded(
                  flex: 6,
                  child: Text('Activity',
                      style: TextStyle(
                          color: AppColors.textDarkSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600))),
              Expanded(
                  flex: 2,
                  child: Text('Date',
                      style: TextStyle(
                          color: AppColors.textDarkSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600))),
              Expanded(
                  flex: 2,
                  child: Text('Duration',
                      style: TextStyle(
                          color: AppColors.textDarkSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600))),
              Expanded(
                  flex: 2,
                  child: Text('Carbs',
                      style: TextStyle(
                          color: AppColors.textDarkSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600))),
              Expanded(
                  flex: 2,
                  child: Text('Calories',
                      style: TextStyle(
                          color: AppColors.textDarkSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600))),
              Expanded(
                  flex: 2,
                  child: Text('Status',
                      style: TextStyle(
                          color: AppColors.textDarkSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600))),
            ],
          ),
        ),
        // Activity rows
        ...widget.activities.map((a) => _buildActivityRow(a)),
      ],
    );
  }

  Widget _buildActivityRow(ActivityReportItem activity) {
    final isExpanded = _expandedActivityId == activity.activityId;

    return Column(
      children: [
        // Summary row
        Material(
          color: isExpanded
              ? AppColors.blackberryLight.withValues(alpha: 0.3)
              : Colors.transparent,
          child: InkWell(
            onTap: () {
              setState(() {
                _expandedActivityId =
                    isExpanded ? null : activity.activityId;
              });
            },
            hoverColor: AppColors.blackberryLight.withValues(alpha: 0.2),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: AppColors.blackberryLight),
                  right: BorderSide(color: AppColors.blackberryLight),
                  bottom: BorderSide(color: AppColors.blackberryLight),
                ),
              ),
              child: Row(
                children: [
                  // Activity name
                  Expanded(
                    flex: 6,
                    child: Row(
                      children: [
                        Icon(
                          isExpanded
                              ? Icons.keyboard_arrow_down
                              : Icons.keyboard_arrow_right,
                          size: 18,
                          color: AppColors.textDarkSecondary,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            activity.name,
                            style: const TextStyle(
                              color: AppColors.cream,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Date
                  Expanded(
                    flex: 2,
                    child: Text(
                      DateFormat.MMMd().format(activity.scheduledDate),
                      style: const TextStyle(
                        color: AppColors.textDarkSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  // Duration
                  Expanded(
                    flex: 2,
                    child: Text(
                      _formatDuration(activity.durationMinutes),
                      style: const TextStyle(
                        color: AppColors.textDarkSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  // Total carbs
                  Expanded(
                    flex: 2,
                    child: Text(
                      activity.plannedTotalCarbs != null
                          ? '${activity.plannedTotalCarbs}g'
                          : '--',
                      style: const TextStyle(
                        color: AppColors.cream,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  // Total calories
                  Expanded(
                    flex: 2,
                    child: Text(
                      activity.plannedTotalCalories != null
                          ? '${activity.plannedTotalCalories}'
                          : '--',
                      style: const TextStyle(
                        color: AppColors.cream,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  // Status
                  Expanded(
                    flex: 2,
                    child: Row(
                      children: [
                        if (activity.isCompleted)
                          const Icon(Icons.check_circle,
                              size: 14, color: AppColors.electrolyte)
                        else
                          Icon(Icons.schedule,
                              size: 14,
                              color: AppColors.textDarkSecondary
                                  .withValues(alpha: 0.5)),
                        const SizedBox(width: 4),
                        Text(
                          activity.isCompleted ? 'Done' : 'Planned',
                          style: TextStyle(
                            color: activity.isCompleted
                                ? AppColors.electrolyte
                                : AppColors.textDarkSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Expanded detail
        if (isExpanded) _ExpandedActivityDetail(activity: activity),
      ],
    );
  }

  String _formatDuration(int? minutes) {
    if (minutes == null) return '--';
    if (minutes >= 60) {
      final h = minutes ~/ 60;
      final m = minutes % 60;
      return m > 0 ? '${h}h${m}m' : '${h}h';
    }
    return '${minutes}m';
  }
}

// ---------------------------------------------------------------------------
// Expanded Activity Detail (planned vs actual side-by-side)
// ---------------------------------------------------------------------------

class _ExpandedActivityDetail extends StatelessWidget {
  const _ExpandedActivityDetail({required this.activity});
  final ActivityReportItem activity;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(40, 8, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.blackberry.withValues(alpha: 0.5),
        border: Border(
          left: BorderSide(color: AppColors.blackberryLight),
          right: BorderSide(color: AppColors.blackberryLight),
          bottom: BorderSide(color: AppColors.blackberryLight),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Side-by-side cards
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Planned card
              Expanded(
                child: _MacroCard(
                  title: 'PLANNED',
                  before: activity.plannedBefore,
                  during: activity.plannedDuring,
                  after: activity.plannedAfter,
                  totalCalories: activity.plannedTotalCalories,
                  color: AppColors.electrolyte,
                ),
              ),
              const SizedBox(width: 12),
              // Actual card
              Expanded(
                child: activity.hasFuelLog
                    ? _MacroCard(
                        title: 'ACTUAL',
                        before: activity.actualBefore,
                        during: activity.actualDuring,
                        after: activity.actualAfter,
                        totalCalories: activity.actualTotalCalories,
                        color: AppColors.orange,
                      )
                    : _NoFuelLogCard(isCompleted: activity.isCompleted),
              ),
            ],
          ),

          // Feedback row
          if (activity.hasFuelLog) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (activity.adherence != null) ...[
                  Text(
                    'Adherence: ${(activity.adherence! * 100).round()}%',
                    style: TextStyle(
                      color: activity.adherence! >= 0.8
                          ? AppColors.electrolyte
                          : AppColors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                if (activity.satisfactionRating != null)
                  Text(
                    _buildStars(activity.satisfactionRating!),
                    style: const TextStyle(
                        color: AppColors.electrolyte, fontSize: 12),
                  ),
              ],
            ),
          ],

          // Athlete notes (prominent)
          if (activity.notes != null && activity.notes!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.blackberryLight.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(6),
                border: Border(
                  left: BorderSide(
                    color: AppColors.electrolyte.withValues(alpha: 0.5),
                    width: 3,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Athlete Notes',
                    style: TextStyle(
                      color: AppColors.textDarkSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    activity.notes!,
                    style: const TextStyle(
                      color: AppColors.cream,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Link to full detail
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: () => _openActivityDetail(context, activity),
            icon: const Icon(Icons.open_in_new, size: 14),
            label: const Text('Open full activity detail'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.electrolyte,
              textStyle: const TextStyle(fontSize: 12),
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 28),
            ),
          ),
        ],
      ),
    );
  }

  void _openActivityDetail(BuildContext context, ActivityReportItem activity) {
    context.push('/plan', extra: {
      'activityId': activity.activityId,
      'isCoachView': true,
    });
  }

  String _buildStars(int rating) {
    return List.generate(5, (i) => i < rating ? '\u2605' : '\u2606').join();
  }
}

// ---------------------------------------------------------------------------
// Macro side-by-side card
// ---------------------------------------------------------------------------

class _MacroCard extends StatelessWidget {
  const _MacroCard({
    required this.title,
    required this.before,
    required this.during,
    required this.after,
    required this.totalCalories,
    required this.color,
  });

  final String title;
  final SectionMacros? before;
  final SectionMacros? during;
  final SectionMacros? after;
  final int? totalCalories;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.blackberry,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          _buildRow('B:', before),
          const SizedBox(height: 4),
          _buildRow('D:', during),
          const SizedBox(height: 4),
          _buildRow('A:', after),
          const Divider(height: 12, color: AppColors.blackberryLight),
          Text(
            totalCalories != null ? 'Total: $totalCalories cal' : 'Total: --',
            style: const TextStyle(
              color: AppColors.cream,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, SectionMacros? macros) {
    return Row(
      children: [
        SizedBox(
          width: 20,
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.textDarkSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            macros != null
                ? '${macros.carbs}g C / ${macros.protein}g P / ${macros.fat}g F'
                : '--',
            style: const TextStyle(
              color: AppColors.cream,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _NoFuelLogCard extends StatelessWidget {
  const _NoFuelLogCard({required this.isCompleted});
  final bool isCompleted;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.blackberry,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.blackberryLight),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            isCompleted ? 'No fuel log filed' : 'Not yet completed',
            style: const TextStyle(
              color: AppColors.textDarkSecondary,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}
