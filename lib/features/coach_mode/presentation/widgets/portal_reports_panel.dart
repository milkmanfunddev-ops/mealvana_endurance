import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../providers/coach_reports_controller.dart';

/// Real reports panel replacing the placeholder.
/// Shows per-athlete summaries with date range toggle.
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
        error: (error, _) => Center(
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
                onPressed: () => ref
                    .read(coachReportsControllerProvider.notifier)
                    .refresh(),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style:
                    TextButton.styleFrom(foregroundColor: AppColors.electrolyte),
              ),
            ],
          ),
        ),
        data: (state) => _buildContent(context, ref, state),
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, WidgetRef ref, CoachReportsState state) {
    return Column(
      children: [
        // Header with date range toggle
        _buildHeader(ref, state),
        const Divider(height: 1, color: AppColors.blackberryLight),

        // Athlete summaries
        if (state.summaries.isEmpty)
          const Expanded(
            child: Center(
              child: Text(
                'No athletes connected yet.',
                style: TextStyle(color: AppColors.textDarkSecondary),
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.summaries.length,
              itemBuilder: (context, index) =>
                  _buildAthleteCard(state.summaries[index]),
            ),
          ),
      ],
    );
  }

  Widget _buildHeader(WidgetRef ref, CoachReportsState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: AppColors.blackberry,
      child: Row(
        children: [
          const Icon(Icons.bar_chart, color: AppColors.electrolyte, size: 24),
          const SizedBox(width: 12),
          const Text(
            'Athlete Reports',
            style: TextStyle(
              color: AppColors.cream,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          // Date range toggle
          SegmentedButton<DateRange>(
            segments: DateRange.values
                .map((r) => ButtonSegment(value: r, label: Text(r.label)))
                .toList(),
            selected: {state.dateRange},
            onSelectionChanged: (selected) {
              ref
                  .read(coachReportsControllerProvider.notifier)
                  .setDateRange(selected.first);
            },
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.electrolyte.withValues(alpha: 0.2);
                }
                return AppColors.blackberryDark;
              }),
              foregroundColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.electrolyte;
                }
                return AppColors.textDarkSecondary;
              }),
              side: WidgetStateProperty.all(
                const BorderSide(color: AppColors.blackberryLight),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            color: AppColors.textDarkSecondary,
            onPressed: () =>
                ref.read(coachReportsControllerProvider.notifier).refresh(),
          ),
        ],
      ),
    );
  }

  Widget _buildAthleteCard(AthleteReportSummary summary) {
    final name = summary.relationship.athleteDisplayName ??
        'Athlete ${summary.relationship.athleteUserId.substring(0, 8)}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.blackberry,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.blackberryLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Athlete name row
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: AppColors.electrolyte,
                child: Text(
                  _getInitials(name),
                  style: const TextStyle(
                    color: AppColors.blackberry,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(
                    color: AppColors.cream,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (summary.unreadMessagesCount > 0)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.dragonfruit,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${summary.unreadMessagesCount} unread',
                    style: const TextStyle(
                      color: AppColors.cream,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Stats row
          Row(
            children: [
              _buildStat(
                Icons.directions_run,
                '${summary.activitiesCompleted}/${summary.activitiesPlanned}',
                'Activities',
                summary.activitiesPlanned > 0
                    ? (summary.completionRate >= 0.8
                        ? AppColors.electrolyte
                        : AppColors.orange)
                    : AppColors.textDarkSecondary,
              ),
              const SizedBox(width: 24),
              _buildStat(
                Icons.event,
                '${summary.upcomingEventsCount}',
                'Upcoming Events',
                AppColors.textDarkSecondary,
              ),
              if (summary.nextEventName != null) ...[
                const SizedBox(width: 24),
                _buildStat(
                  Icons.flag,
                  summary.nextEventName!,
                  summary.nextEventDate != null
                      ? '${summary.nextEventDate!.month}/${summary.nextEventDate!.day}'
                      : 'Upcoming',
                  AppColors.electrolyte,
                ),
              ],
            ],
          ),

          // Completion bar
          if (summary.activitiesPlanned > 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: summary.completionRate,
                backgroundColor: AppColors.blackberryLight,
                valueColor: AlwaysStoppedAnimation(
                  summary.completionRate >= 0.8
                      ? AppColors.electrolyte
                      : AppColors.orange,
                ),
                minHeight: 6,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStat(
      IconData icon, String value, String label, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textDarkSecondary,
            fontSize: 11,
          ),
        ),
      ],
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
