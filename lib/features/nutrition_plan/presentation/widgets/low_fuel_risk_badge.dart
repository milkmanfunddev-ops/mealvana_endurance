import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../domain/nutrition_plan.dart';

/// Non-judgmental indicator shown when athlete's planned carb intake
/// is significantly below target (33% or more below).
///
/// Helps athletes identify under-fueling risks without being preachy.
class LowFuelRiskBadge extends StatelessWidget {
  const LowFuelRiskBadge({
    super.key,
    required this.nutritionPlan,
    this.threshold = 0.67, // Show warning if actual < 67% of target (33% below)
  });

  /// The nutrition plan to analyze for under-fueling
  final NutritionPlan nutritionPlan;

  /// Threshold ratio below which warning is shown (default: 0.67 = 33% below target)
  final double threshold;

  /// Calculate fuel status from the nutrition plan
  /// Returns a record with (isLowFuel, actualCarbs, targetCarbs, lowestSection)
  ({bool isLowFuel, int actualCarbs, int targetCarbs, String? lowestSection}) _calculateFuelStatus() {
    int totalActualCarbs = 0;
    int totalTargetCarbs = 0;
    String? lowestSection;
    double lowestRatio = double.infinity;

    for (final section in nutritionPlan.sections) {
      // Calculate actual carbs from food items in this section
      // V2 template plans store foods in subPhases, not directly in section.foodItems
      int sectionActualCarbs = 0;
      if (section.hasSubPhases) {
        for (final subPhase in section.subPhases!) {
          for (final food in subPhase.foodItems) {
            if (food.nutritionalInfo != null) {
              sectionActualCarbs += food.nutritionalInfo!.carbs ?? 0;
            }
          }
        }
      } else {
        for (final food in section.foodItems) {
          if (food.nutritionalInfo != null) {
            sectionActualCarbs += food.nutritionalInfo!.carbs ?? 0;
          }
        }
      }

      // Get target carbs for this section
      final sectionTargetCarbs = section.carbsTarget?.round() ?? 0;

      totalActualCarbs += sectionActualCarbs;
      totalTargetCarbs += sectionTargetCarbs;

      // Track which section has the lowest ratio
      if (sectionTargetCarbs > 0) {
        final ratio = sectionActualCarbs / sectionTargetCarbs;
        if (ratio < lowestRatio) {
          lowestRatio = ratio;
          lowestSection = _getSectionName(section.id);
        }
      }
    }

    // Check if overall carbs are below threshold
    final isLowFuel = totalTargetCarbs > 0 &&
        (totalActualCarbs / totalTargetCarbs) < threshold;

    return (
      isLowFuel: isLowFuel,
      actualCarbs: totalActualCarbs,
      targetCarbs: totalTargetCarbs,
      lowestSection: isLowFuel ? lowestSection : null,
    );
  }

  /// Get user-friendly section name from section ID
  String _getSectionName(String sectionId) {
    if (sectionId.contains('before')) return 'before';
    if (sectionId.contains('during')) return 'during';
    if (sectionId.contains('after')) return 'after';
    return sectionId;
  }

  @override
  Widget build(BuildContext context) {
    final status = _calculateFuelStatus();

    // Don't show anything if fuel levels are adequate
    if (!status.isLowFuel) {
      return const SizedBox.shrink();
    }

    final percentage = status.targetCarbs > 0
        ? ((status.actualCarbs / status.targetCarbs) * 100).round()
        : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.dragonfruit.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: AppColors.dragonfruit.withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: AppColors.dragonfruit.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: FaIcon(
              FontAwesomeIcons.bolt,
              color: AppColors.dragonfruit,
              size: 16,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),

          // Text content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge label
                Row(
                  children: [
                    Text(
                      'LOW FUEL RISK',
                      style: AppTextStyles.sectionTitle.copyWith(
                        color: AppColors.dragonfruit,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.dragonfruit.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.xxs),
                      ),
                      child: Text(
                        '$percentage%',
                        style: AppTextStyles.smallLabel.copyWith(
                          color: AppColors.dragonfruit,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxs),

                // Helpful message
                Text(
                  'Planned intake is below target for this workload.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textLight.withValues(alpha: 0.8),
                  ),
                ),

                // Optional: Show carb numbers
                const SizedBox(height: AppSpacing.xs),
                Text(
                  '${status.actualCarbs}g of ${status.targetCarbs}g carbs planned',
                  style: AppTextStyles.smallLabel.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
