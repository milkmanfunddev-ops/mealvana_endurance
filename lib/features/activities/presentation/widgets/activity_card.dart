import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../domain/activity.dart';
import '../../../../shared/domain/activity_type.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../providers/activities_controller.dart';
import 'activity_action_buttons.dart';

/// Reusable activity card widget matching Kyle's design.
///
/// Displays activity information in a card with:
/// - Activity icon (36px circle with Electrolyte background)
/// - Activity title and details (Compadre + Apercu fonts)
/// - Action buttons (check mark and X)
///
/// Specifications:
/// - Border radius: 15px
/// - Icon: 36px circle, Electrolyte background, Blackberry icon
/// - Title: Compadre, 16px
/// - Details: Apercu Mono, 12px
/// - Action buttons: 36px circles on the right
class ActivityCard extends ConsumerWidget {
  const ActivityCard({
    super.key,
    required this.activity,
  });

  final Activity activity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.blackberryLight : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: (isDark ? AppColors.cream : AppColors.blackberry)
              .withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => _handleTap(context),
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _buildActivityIcon(),
              const SizedBox(width: 12),
              Expanded(
                child: _buildActivityDetails(context, isDark),
              ),
              ActivityActionButtons(
                isCompleted: activity.status == ActivityStatus.completed,
                onComplete: () => _handleComplete(context, ref),
                onDelete: () => _handleDelete(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityIcon() {
    return Container(
      width: 36,
      height: 36,
      decoration: const BoxDecoration(
        color: AppColors.electrolyte,
        shape: BoxShape.circle,
      ),
      child: Icon(
        _getActivityIcon(activity.activityType),
        color: AppColors.blackberry,
        size: 18,
      ),
    );
  }

  Widget _buildActivityDetails(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          activity.title,
          style: TextStyle(
            fontFamily: 'Compadre',
            fontSize: 14,
            color: isDark ? AppColors.cream : AppColors.blackberry,
            height: 1.3,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Text(
          _formatActivityDetails(),
          style: TextStyle(
            fontFamily: 'Apercu',
            fontSize: 12,
            color: (isDark ? AppColors.cream : AppColors.blackberry)
                .withValues(alpha: 0.7),
            height: 1.3,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Future<void> _handleComplete(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final activitiesController = ref.read(activitiesControllerProvider.notifier);

    // Toggle completion status
    final newStatus = activity.status == ActivityStatus.completed
        ? ActivityStatus.planned
        : ActivityStatus.completed;

    try {
      final updatedActivity = activity.copyWith(
        status: newStatus,
        completedAt: newStatus == ActivityStatus.completed ? DateTime.now() : null,
      );

      await activitiesController.updateActivity(updatedActivity);

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            newStatus == ActivityStatus.completed
                ? 'Activity marked as completed'
                : 'Activity marked as incomplete',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error updating activity: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  Future<void> _handleDelete(BuildContext context, WidgetRef ref) async {
    // Capture messenger before async gap
    final messenger = ScaffoldMessenger.of(context);
    final activityTitle = activity.title;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Activity'),
          content: Text('Are you sure you want to delete "$activityTitle"?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: AppColors.error),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final activitiesController = ref.read(activitiesControllerProvider.notifier);
      await activitiesController.deleteActivity(activity.id);

      messenger.showSnackBar(
        SnackBar(
          content: Text('Deleted "$activityTitle"'),
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error deleting activity: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _handleTap(BuildContext context) {
    context.push('/plan', extra: {
      'mode': 'view',
      'activityId': activity.id,
    });
  }

  String _formatActivityDetails() {
    final parts = <String>[];

    switch (activity.activityType) {
      case ActivityType.running:
        if (activity.distanceMiles != null) {
          parts.add('${activity.distanceMiles!.toStringAsFixed(1)} mi');
        }
        if (activity.formattedPace != null) {
          parts.add(activity.formattedPace!);
        }
        break;

      case ActivityType.cycling:
        if (activity.distanceMiles != null) {
          parts.add('${activity.distanceMiles!.toStringAsFixed(1)} mi');
        }
        if (activity.cyclingSpeedMph != null) {
          parts.add('${activity.cyclingSpeedMph!.toStringAsFixed(1)} mph');
        }
        break;

      case ActivityType.swimming:
        if (activity.distanceMiles != null) {
          final meters = (activity.distanceMiles! * 1609.34).round();
          parts.add('${meters}m');
        }
        if (activity.swimmingPacePer100mSeconds != null) {
          final totalSeconds = activity.swimmingPacePer100mSeconds!;
          final minutes = totalSeconds ~/ 60;
          final seconds = totalSeconds % 60;
          parts.add('$minutes:${seconds.toString().padLeft(2, '0')}/100m');
        }
        break;

      case ActivityType.triathlon:
      case ActivityType.duathlon:
      case ActivityType.multisport:
        if (activity.distanceMiles != null) {
          parts.add('${activity.distanceMiles!.toStringAsFixed(1)} mi');
        }
        break;
    }

    return parts.join(' • ');
  }

  IconData _getActivityIcon(ActivityType activityType) {
    switch (activityType) {
      case ActivityType.running:
        return FontAwesomeIcons.personRunning;
      case ActivityType.cycling:
        return FontAwesomeIcons.personBiking;
      case ActivityType.swimming:
        return FontAwesomeIcons.personSwimming;
      case ActivityType.triathlon:
      case ActivityType.duathlon:
      case ActivityType.multisport:
        return FontAwesomeIcons.trophy;
    }
  }
}
