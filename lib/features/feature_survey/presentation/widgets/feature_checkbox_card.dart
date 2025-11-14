import 'package:flutter/material.dart';
import '../../domain/feature_survey_data.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../../../theme/kyle_design/app_spacing.dart';

/// Card widget for displaying a feature with checkbox
/// Tapping anywhere on the card toggles the checkbox
class FeatureCheckboxCard extends StatelessWidget {
  const FeatureCheckboxCard({
    super.key,
    required this.feature,
    required this.isSelected,
    required this.isEnabled,
    required this.onToggle,
  });

  final Feature feature;
  final bool isSelected;
  final bool isEnabled;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(
        vertical: AppSpacing.xs,
        horizontal: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(15.0), // 15px from Kyle's design
        border: Border.all(
          color: isSelected
              ? AppColors.electrolyte // Electrolyte for selected state
              : (isDark ? AppColors.borderDark : AppColors.borderLight),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isEnabled ? onToggle : null,
          borderRadius: BorderRadius.circular(15.0),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon with circular background (36px circle per Kyle's design)
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.electrolyte
                        : (isDark ? AppColors.inactive : AppColors.borderLightSecondary),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    feature.icon,
                    color: isSelected
                        ? AppColors.blackberry
                        : (isDark ? AppColors.cream : AppColors.blackberry),
                    size: 18, // ~50% of container size
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        feature.name,
                        style: AppTextStyles.subtitle.copyWith(
                          color: isEnabled
                              ? (isDark ? AppColors.cream : AppColors.blackberry)
                              : AppColors.disabled,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        feature.description,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: isEnabled
                              ? (isDark ? AppColors.textDarkSecondary : AppColors.textLightSecondary)
                              : AppColors.disabled,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                // Checkbox
                Transform.scale(
                  scale: 0.9,
                  child: Checkbox(
                    value: isSelected,
                    onChanged: isEnabled ? (_) => onToggle() : null,
                    activeColor: AppColors.electrolyte,
                    checkColor: AppColors.blackberry,
                    side: BorderSide(
                      color: isDark ? AppColors.cream : AppColors.blackberry,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
