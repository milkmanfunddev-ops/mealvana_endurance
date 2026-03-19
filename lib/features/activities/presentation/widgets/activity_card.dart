import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../domain/activity.dart';
import '../../../../shared/domain/activity_type.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/services/analytics/analytics_events.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../shared/widgets/kyle_design/feedback/mealvana_snackbar.dart';
import '../providers/activities_controller.dart';

/// Reusable activity card widget matching Kyle's design.
///
/// Displays activity information in a card with:
/// - Activity icon (36px circle with Electrolyte background)
/// - Activity title and details with scheduled time (Compadre + Apercu fonts)
/// - Right chevron icon
/// - Swipe-to-delete gesture (swipe left)
///
/// Selection Mode Support:
/// - When isSelectionMode is true, shows checkbox on left side
/// - When isSelected is true, shows numbered indicator instead of checkbox
/// - selectionOrder determines the number shown (1, 2, 3)
/// - onSelectionToggle is called when card is tapped in selection mode
///
/// Specifications:
/// - Border radius: 15px
/// - Icon: 36px circle, Electrolyte background, Blackberry icon
/// - Title: Compadre, 16px
/// - Details: Apercu Mono, 12px
/// - Chevron: 20px, theme-aware with 0.5 opacity
class ActivityCard extends ConsumerWidget {
  const ActivityCard({
    super.key,
    required this.activity,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.selectionOrder,
    this.onSelectionToggle,
  });

  final Activity activity;
  final bool isSelectionMode;
  final bool isSelected;
  final int? selectionOrder;
  final VoidCallback? onSelectionToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Wrap in Dismissible for swipe-to-delete (only when NOT in selection mode)
    if (!isSelectionMode) {
      return Dismissible(
        key: Key(activity.id),
        direction: DismissDirection.endToStart,
        background: _buildDismissBackground(isDark),
        confirmDismiss: (direction) async {
          return await _handleDelete(context, ref);
        },
        child: _buildCard(context, ref, isDark),
      );
    }

    // Selection mode - no dismissible
    return _buildCard(context, ref, isDark);
  }

  Widget _buildCard(BuildContext context, WidgetRef ref, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.blackberryLight : Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: (isDark ? AppColors.cream : AppColors.blackberry).withValues(
            alpha: 0.1,
          ),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: () => isSelectionMode
            ? onSelectionToggle?.call()
            : _handleTap(context, ref),
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Selection indicator (checkbox or numbered order)
              if (isSelectionMode) ...[
                _buildSelectionIndicator(isDark),
                const SizedBox(width: 12),
              ],
              _buildActivityIcon(),
              const SizedBox(width: 12),
              Expanded(child: _buildActivityDetails(context, isDark)),
              // Show chevron when NOT in selection mode
              if (!isSelectionMode)
                Icon(
                  Icons.chevron_right,
                  color: (isDark ? AppColors.cream : AppColors.blackberry)
                      .withValues(alpha: 0.5),
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDismissBackground(bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(15),
      ),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20),
      child: const Icon(Icons.delete, color: Colors.white, size: 24),
    );
  }

  /// Build selection indicator - either checkbox or numbered order
  Widget _buildSelectionIndicator(bool isDark) {
    if (isSelected && selectionOrder != null) {
      // Show numbered indicator (①, ②, ③)
      return Container(
        width: 32,
        height: 32,
        decoration: const BoxDecoration(
          color: AppColors.electrolyte,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            '$selectionOrder',
            style: const TextStyle(
              fontFamily: 'Compadre',
              fontSize: 16,
              color: AppColors.blackberry,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      );
    } else {
      // Show empty checkbox
      return Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: (isDark ? AppColors.cream : AppColors.blackberry).withValues(
              alpha: 0.3,
            ),
            width: 2,
          ),
        ),
      );
    }
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
            fontFamily: 'Sansita',
            fontSize: 15,
            fontWeight: FontWeight.w700,
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
            color: (isDark ? AppColors.cream : AppColors.blackberry).withValues(
              alpha: 0.7,
            ),
            height: 1.3,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Future<bool> _handleDelete(BuildContext context, WidgetRef ref) async {
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

    if (confirmed != true) return false;

    try {
      final activitiesController = ref.read(
        activitiesControllerProvider.notifier,
      );
      await activitiesController.deleteActivity(activity.id);

      MealvanaSnackbar.showSuccess(context, 'Deleted "$activityTitle"');
      return true;
    } catch (e) {
      MealvanaSnackbar.showError(context, 'Error deleting activity: $e');
      return false;
    }
  }

  void _handleTap(BuildContext context, WidgetRef ref) {
    // Track activity viewed with synced workout info
    // Use activity.userId as the device_id (userId is the Supabase auth user ID)
    final isSyncedWorkout = activity.syncedFromProvider != null;

    ref
        .read(appExternalDepsProvider)
        .analytics
        .trackActivityViewed(
          deviceId: activity.userId,
          activityId: activity.id,
          activityType: activity.activityType.name,
          hasNutritionPlan: activity.nutritionPlanData != null,
          isSyncedWorkout: isSyncedWorkout,
          syncedFromProvider: activity.syncedFromProvider,
          providerWorkoutId: activity.providerWorkoutId,
        );

    // Check if activity has a nutrition plan
    if (activity.nutritionPlanData == null) {
      // No nutrition plan - open New Activity screen with pre-populated data
      context.push(
        '/distancepacegut',
        extra: {
          'activityId': activity.id,
          'initialDate': activity.scheduledDateTime,
          'distance': activity.distanceMiles,
          'initialDurationMinutes': activity.durationMinutes,
          'goalPace': activity.paceTargetMinutesPerMile,
          'activityType': activity.activityType.name,
          // Cycling-specific parameters
          'cyclingSpeedMph': activity.cyclingSpeedMph,
          'cyclingTerrain': activity.cyclingTerrain,
          'cyclingIndoorOutdoor': activity.cyclingIndoorOutdoor,
          'cyclingElevationGainFt': activity.cyclingElevationGainFt,
          'cyclingSessionGoal': activity.cyclingSessionGoal,
          // Swimming-specific parameters
          'swimmingPacePer100mSeconds': activity.swimmingPacePer100mSeconds,
          'swimmingPoolOrOpenWater': activity.swimmingPoolOrOpenWater,
          'swimmingWaterTempC': activity.swimmingWaterTempC,
          // Shared parameters
          'intensityTarget': activity.intensityTarget,
          'timeBeforeMinutes': activity.timeBeforeMinutes,
        },
      );
    } else {
      // Has nutrition plan - open Activity Detail screen (current behavior)
      context.push('/plan', extra: {'mode': 'view', 'activityId': activity.id});
    }
  }

  String _formatActivityDetails() {
    final parts = <String>[];

    // Add scheduled time first
    final timeFormat = DateFormat('h:mm a');
    parts.add(timeFormat.format(activity.scheduledDateTime));

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
      case ActivityType.brick:
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
      case ActivityType.brick:
        return FontAwesomeIcons.link; // Chain link icon for brick workouts
    }
  }
}
