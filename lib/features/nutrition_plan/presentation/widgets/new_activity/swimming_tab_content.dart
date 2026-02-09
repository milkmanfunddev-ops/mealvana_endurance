import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../../shared/widgets/kyle_design/inputs/plus_minus_control.dart';
import '../../../../../shared/widgets/kyle_design/buttons/segmented_control.dart';
import '../../../../../shared/widgets/kyle_design/inputs/intensity_distribution_widget.dart';
import '../../providers/swimming_input_controller.dart';
import '../../../../../theme/kyle_design/app_spacing.dart';
import '../../../../../theme/kyle_design/app_text_styles.dart';
import '../../../../../theme/kyle_design/app_colors.dart';
import '../../../../../shared/domain/activity_type.dart';
import 'shared/workout_details_widget.dart';

/// Swimming Tab Content
///
/// Sport-specific form fields for swimming activities:
/// - Pool/Open Water (toggle)
/// - Distance (meters)
/// - Pace per 100m (seconds)
/// - Time before Swim
/// - Intensity Target (dropdown)
/// - Session Goal (dropdown)
/// - Water Temperature
/// - Environment Section (collapsible)
///   - Deck Temperature, Deck Humidity
///
/// Status: Phase 2 - Full implementation with Kyle design components
class SwimmingTabContent extends ConsumerWidget {
  const SwimmingTabContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formState = ref.watch(swimmingInputControllerProvider);
    final controller = ref.read(swimmingInputControllerProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [

          // WORKOUT DETAILS
          WorkoutDetailsWidget(
            sport: ActivityType.swimming,
            distance: formState.distanceMeters.toDouble(),
            distanceUnit: 'meters',
            mode: formState.durationPaceMode,
            estimatedDuration: formState.estimatedDuration,
            pace: formState.pacePer100mSeconds.toDouble() / 60, // Convert seconds to minutes
            paceUnit: 'min/100m',
            onDistanceChanged: (distance) => controller.updateDistance(distance.round()),
            onModeChanged: controller.updateDurationPaceMode,
            onPaceChanged: (paceMinutes) => controller.updatePace((paceMinutes * 60).round()), // Convert minutes to seconds
            onDurationChanged: controller.updateDuration,
          ),

          // Zone-based pace hint
          if (formState.zoneSuggestedPacePer100mSeconds != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.electrolyte.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: AppColors.electrolyte.withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.water,
                        size: 10,
                        color: AppColors.electrolyteDark,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Pace from Training Peaks zones',
                        style: AppTextStyles.smallLabel.copyWith(
                          color: AppColors.electrolyteDark,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: AppSpacing.xl),

          // INTENSITY DISTRIBUTION
          IntensityDistributionWidget(
            value: formState.intensity,
            onChanged: controller.updateIntensityDistribution,
            sportType: ActivityType.swimming,
          ),

          const SizedBox(height: AppSpacing.xl),

          // Time before Swim
          KylePlusMinusControl(
            label: 'Pre-Swim Fueling Window',
            value: formState.preSwimMinutes,
            onChanged: controller.updatePreSwimMinutes,
            min: 0,
            max: 480,
            step: 30,
            unit: 'minutes',
          ),

          const SizedBox(height: AppSpacing.xl),

          // Pool/Open Water Toggle
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Water Type',
                style: AppTextStyles.descriptor.copyWith(
                  color: isDark ? AppColors.cream : AppColors.blackberry,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              KyleSegmentedControl<_WaterType>(
                segments: _WaterType.values,
                selected: formState.poolOrOpenWater == 'pool'
                    ? _WaterType.pool
                    : _WaterType.openWater,
                onChanged: (type) {
                  controller.updatePoolOrOpenWater(
                    type == _WaterType.pool ? 'pool' : 'open_water',
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.xl),

          const SizedBox(height: AppSpacing.xxl),
        ],
    );
  }
}

/// Water type enum for segmented control
enum _WaterType {
  pool,
  openWater,
}
