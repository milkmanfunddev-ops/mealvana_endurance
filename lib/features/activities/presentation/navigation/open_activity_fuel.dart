import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../../domain/activity.dart';

/// Opens the right surface for a workout tap (Lee, 2026-08-10 — supersedes
/// the 2026-06-29 always-Detail ruling): activities that already have a
/// nutrition plan open **Activity Detail**; plan-less ones go straight to the
/// **New Activity** flow pre-filled, instead of a Detail screen whose only
/// content is a "Generate Plan" placeholder. Import-only activities never get
/// a plan and still land on Detail (read-only).
void openActivityFuel(BuildContext context, Activity activity) {
  if (activity.activityType.isImportOnly || activity.nutritionPlanData != null) {
    context.push('/plan', extra: {'mode': 'view', 'activityId': activity.id});
    return;
  }
  context.push('/distancepacegut', extra: buildGeneratePlanExtras(activity));
}

/// Pre-fill payload for the New Activity ("distance/pace/gut") flow, shared
/// by every plan-less entry point so the screens agree on field names.
Map<String, dynamic> buildGeneratePlanExtras(Activity activity) {
  return {
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
  };
}
