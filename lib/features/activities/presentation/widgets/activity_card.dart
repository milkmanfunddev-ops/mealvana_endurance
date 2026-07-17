import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../domain/activity.dart';
import '../../../../shared/domain/activity_type.dart';
import '../../../../shared/services/app_external_deps.dart';
import '../../../../shared/services/analytics/analytics_events.dart';
import '../../../../shared/providers/unit_system_provider.dart';
import '../../../../shared/utils/unit_formatter.dart';
import '../../../nutrition_plan/domain/run_parameters.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../shared/widgets/kyle_design/feedback/mealvana_snackbar.dart';
import '../../../integrations/presentation/widgets/garmin_attribution.dart';
import '../providers/activities_controller.dart';

/// Reusable activity card widget matching Kyle's design.
///
/// Displays activity information in a card with:
/// - Activity icon (36px circle with Electrolyte background)
/// - Activity title and details with scheduled time (Compadre + Apercu fonts)
/// - Tap anywhere opens the detail/edit surface
/// - Swipe-to-delete gesture in either direction, with an Undo snackbar
///   (unified card interaction 391e3fdb — no chevron, no confirm dialog)
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
    final useMetric =
        (ref.watch(unitSystemProvider).value ?? UnitSystem.imperial) ==
        UnitSystem.metric;

    // Wrap in Dismissible for swipe-to-delete (only when NOT in selection
    // mode). Both directions delete (unified card interaction 391e3fdb);
    // confirmDismiss returns false so the row leaves via the provider rebuild
    // rather than a structural dismiss.
    if (!isSelectionMode) {
      return Dismissible(
        key: Key(activity.id),
        direction: DismissDirection.horizontal,
        background: _buildDismissBackground(isDark, Alignment.centerLeft),
        secondaryBackground:
            _buildDismissBackground(isDark, Alignment.centerRight),
        confirmDismiss: (direction) async {
          _handleDelete(context, ref);
          return false;
        },
        child: _buildCard(context, ref, isDark, useMetric),
      );
    }

    // Selection mode - no dismissible
    return _buildCard(context, ref, isDark, useMetric);
  }

  Widget _buildCard(
    BuildContext context,
    WidgetRef ref,
    bool isDark,
    bool useMetric,
  ) {
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
        key: ValueKey('calendar.activity_card_${activity.id}'),
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
              Expanded(
                child: _buildActivityDetails(context, isDark, useMetric),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDismissBackground(bool isDark, Alignment alignment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.error,
        borderRadius: BorderRadius.circular(15),
      ),
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 20),
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

  Widget _buildActivityDetails(
    BuildContext context,
    bool isDark,
    bool useMetric,
  ) {
    // Attribution is required whenever the card shows Garmin-sourced data,
    // including TP/FS-planned activities completed by a Garmin push.
    final hasGarminData = activity.hasGarminData;

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
          _formatActivityDetails(useMetric),
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
        // Garmin brand attribution (required by Garmin API Brand Guidelines).
        // Renders `[tag logo] Garmin [device model]` — or `Garmin Connect`
        // when no device model was carried on the push.
        if (hasGarminData) ...[
          const SizedBox(height: 4),
          GarminAttribution(deviceName: activity.garminDeviceName),
        ],
      ],
    );
  }

  /// Soft-delete with an undo affordance (offline-first) — no blocking
  /// confirm dialog. Mirrors the Fuel Timeline's delete pattern so meal and
  /// activity cards behave identically everywhere (391e3fdb).
  void _handleDelete(BuildContext context, WidgetRef ref) {
    // Capture the messenger before kicking off the delete so we're never
    // relying on `context` staying valid past this point, and clear any
    // snackbar already in flight so a rapid double-swipe can't queue two
    // "Activity deleted" toasts back to back.
    final messenger = ScaffoldMessenger.of(context);
    ref.read(activitiesControllerProvider.notifier).deleteActivity(activity.id);
    messenger.clearSnackBars();
    MealvanaSnackbar.showInfo(
      context,
      'Activity deleted',
      duration: const Duration(seconds: 3),
      actionLabel: 'Undo',
      // Read the notifier fresh at tap time (the autoDispose provider may have
      // been recreated since delete) and surface any failure — restoreActivity
      // returns a Future, so without this the error would be dropped silently.
      onAction: () async {
        try {
          await ref
              .read(activitiesControllerProvider.notifier)
              .restoreActivity(activity);
        } catch (_) {
          if (context.mounted) {
            MealvanaSnackbar.showError(context, 'Could not restore activity');
          }
        }
      },
    );
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

    // Import-only activities (e.g. strength/hiking/etc. imported from a
    // provider we don't natively support) never get a nutrition plan and
    // can't be edited — show a minimal read-only detail sheet instead of
    // routing into an editor. Deletion still works via the swipe gesture.
    if (activity.activityType.isImportOnly) {
      _showImportOnlyDetailSheet(context);
      return;
    }

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
          'initialTitle': activity.title,
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

  /// Minimal read-only detail sheet for import-only activities.
  ///
  /// These are catch-all imports (strength, hiking, yoga, etc.) from
  /// providers we don't natively support. There's no editor for them —
  /// just enough context to identify what was imported. Deletion happens
  /// via the swipe gesture on the card itself, not from this sheet.
  void _showImportOnlyDetailSheet(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final dateFormat = DateFormat('EEEE, MMM d • h:mm a');

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: isDark ? AppColors.blackberryLight : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: textColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: const BoxDecoration(
                        color: AppColors.electrolyte,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getActivityIcon(activity.activityType),
                        color: AppColors.blackberry,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        activity.title,
                        style: TextStyle(
                          fontFamily: 'Sansita',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildDetailRow(
                  textColor,
                  'When',
                  dateFormat.format(activity.scheduledDateTime),
                ),
                if (activity.durationMinutes != null)
                  _buildDetailRow(
                    textColor,
                    'Duration',
                    '${activity.durationMinutes} min',
                  ),
                if (activity.distanceMiles != null)
                  _buildDetailRow(
                    textColor,
                    'Distance',
                    '${activity.distanceMiles!.toStringAsFixed(1)} mi',
                  ),
                if (activity.syncedFromProvider != null)
                  _buildDetailRow(
                    textColor,
                    'Imported from',
                    _formatProviderName(activity.syncedFromProvider!),
                  ),
                if (activity.notes != null && activity.notes!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    activity.notes!,
                    style: TextStyle(
                      fontFamily: 'Apercu',
                      fontSize: 13,
                      color: textColor.withValues(alpha: 0.7),
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  'This activity type isn\'t editable in Mealvana — swipe to delete if you don\'t want to see it.',
                  style: TextStyle(
                    fontFamily: 'Apercu',
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: textColor.withValues(alpha: 0.5),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailRow(Color textColor, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Apercu',
                fontSize: 13,
                color: textColor.withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontFamily: 'Apercu',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Human-readable provider name for the "Imported from" row.
  String _formatProviderName(String provider) {
    switch (provider) {
      case 'final_surge':
        return 'Final Surge';
      case 'training_peaks':
        return 'TrainingPeaks';
      case 'garmin':
        return 'Garmin Connect';
      case 'vdot':
        return 'VDOT';
      case 'strava':
        return 'Strava';
      default:
        return provider;
    }
  }

  String _formatActivityDetails(bool useMetric) {
    final parts = <String>[];
    final distanceUnit = useMetric
        ? DistanceUnit.kilometers
        : DistanceUnit.miles;
    final paceUnit = useMetric ? PaceUnit.minPerKm : PaceUnit.minPerMile;

    // Add scheduled time first
    final timeFormat = DateFormat('h:mm a');
    parts.add(timeFormat.format(activity.scheduledDateTime));

    switch (activity.activityType) {
      case ActivityType.running:
        if (activity.distanceMiles != null) {
          parts.add(
            UnitFormatter.formatDistance(
              activity.distanceMiles!,
              unit: distanceUnit,
            ),
          );
        }
        if (activity.paceTargetMinutesPerMile != null) {
          parts.add(
            UnitFormatter.formatPace(
              activity.paceTargetMinutesPerMile!,
              unit: paceUnit,
            ),
          );
        }
        break;

      case ActivityType.cycling:
        if (activity.distanceMiles != null) {
          parts.add(
            UnitFormatter.formatDistance(
              activity.distanceMiles!,
              unit: distanceUnit,
            ),
          );
        }
        if (activity.cyclingSpeedMph != null) {
          parts.add(
            UnitFormatter.formatSpeed(
              activity.cyclingSpeedMph!,
              useMetric: useMetric,
            ),
          );
        }
        break;

      case ActivityType.swimming:
        // Swimming distance is pool-length convention (meters), not an
        // imperial/metric split - leave as-is.
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
          parts.add(
            UnitFormatter.formatDistance(
              activity.distanceMiles!,
              unit: distanceUnit,
            ),
          );
        }
        break;

      case ActivityType.other:
        if (activity.durationMinutes != null) {
          parts.add('${activity.durationMinutes} min');
        }
        break;
    }

    return parts.join(' • ');
  }

  IconData _getActivityIcon(ActivityType activityType) {
    switch (activityType) {
      case ActivityType.running:
        return FontAwesomeIcons.personRunning.data;
      case ActivityType.cycling:
        return FontAwesomeIcons.personBiking.data;
      case ActivityType.swimming:
        return FontAwesomeIcons.personSwimming.data;
      case ActivityType.triathlon:
      case ActivityType.duathlon:
      case ActivityType.multisport:
        return FontAwesomeIcons.trophy.data;
      case ActivityType.brick:
        return FontAwesomeIcons.link.data; // Chain link icon for brick workouts
      case ActivityType.other:
        return FontAwesomeIcons.circle.data;
    }
  }
}
