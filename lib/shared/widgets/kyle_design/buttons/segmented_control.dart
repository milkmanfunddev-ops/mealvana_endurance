import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_spacing.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_text_styles.dart';

import '../../../../features/auth/domain/user_preferences.dart'
    show GutTraining, SweatRateCat, SweatSodiumCat, Gender;
import '../../../../features/nutrition_plan/domain/run_parameters.dart'
    show DistanceUnit, PaceUnit;

/// Segmented control for Kyle's design system
/// 15px radius with Blackberry fill/outline
class KyleSegmentedControl<T extends Enum> extends ConsumerWidget {
  const KyleSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
    this.padding,
    this.segmentKeyPrefix,
  });

  final List<T> segments;
  final T selected;
  final ValueChanged<T> onChanged;
  final EdgeInsets? padding;

  /// Optional prefix for auto-generating ValueKeys on each segment button.
  /// If provided, each segment gets key: ValueKey('${segmentKeyPrefix}_${segment.name}_button').
  final String? segmentKeyPrefix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: padding ?? const EdgeInsets.all(AppSpacing.xs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: segments.map((segment) {
          final isSelected = segment == selected;
          return Expanded(
            child: _SegmentButton<T>(
              key: segmentKeyPrefix != null
                  ? ValueKey('${segmentKeyPrefix}_${segment.name}_button')
                  : null,
              segment: segment,
              isSelected: isSelected,
              onTap: () => onChanged(segment),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Individual segment button
class _SegmentButton<T extends Enum> extends StatelessWidget {
  const _SegmentButton({
    super.key,
    required this.segment,
    required this.isSelected,
    required this.onTap,
  });

  final T segment;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 1),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppColors.cream : AppColors.blackberry)
              : Colors.transparent,
          borderRadius: AppRadius.segmentedControlRadius,
          border: Border.all(
            color: isDark ? AppColors.cream : AppColors.blackberry,
            width: 2,
          ),
        ),
        child: Center(
          child: Text(
            _getSegmentLabel(segment),
            style: AppTextStyles.segmentedControl.copyWith(
              color: isSelected
                  ? (isDark ? AppColors.blackberry : AppColors.cream)
                  : (isDark ? AppColors.cream : AppColors.blackberry),
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  String _getSegmentLabel(T segment) {
    // Handle common enum types
    if (segment is GutTraining) {
      return (segment as GutTraining).displayName;
    } else if (segment is SweatSodiumCat) {
      return (segment as SweatSodiumCat).displayName.toUpperCase();
    } else if (segment is SweatRateCat) {
      return (segment as SweatRateCat).displayName;
    } else if (segment is IntensityLevel) {
      return (segment as IntensityLevel).displayName;
    } else if (segment is Gender) {
      return (segment as Gender).displayName;
    } else if (segment is DistanceUnit) {
      return (segment as DistanceUnit).displayName;
    } else if (segment is PaceUnit) {
      return (segment as PaceUnit).displayName;
    } else if (segment is ThemeMode) {
      return (segment as ThemeMode).displayName;
    }

    // Fallback to enum name
    return segment.name.toUpperCase();
  }
}

/// Gut training level segmented control
class KyleGutTrainingSegmentedControl extends ConsumerWidget {
  const KyleGutTrainingSegmentedControl({
    super.key,
    required this.selected,
    required this.onChanged,
    this.showValues = false,
  });

  final GutTraining selected;
  final ValueChanged<GutTraining> onChanged;
  final bool showValues;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (showValues) {
      return _GutTrainingSegmentedControlWithValues(
        selected: selected,
        onChanged: onChanged,
      );
    }

    return KyleSegmentedControl<GutTraining>(
      segments: GutTraining.values,
      selected: selected,
      onChanged: onChanged,
    );
  }
}

/// Gut training control with g/kg/h values displayed
class _GutTrainingSegmentedControlWithValues extends StatelessWidget {
  const _GutTrainingSegmentedControlWithValues({
    required this.selected,
    required this.onChanged,
  });

  final GutTraining selected;
  final ValueChanged<GutTraining> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xs),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: GutTraining.values.map((segment) {
          final isSelected = segment == selected;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(segment),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 1),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? AppColors.cream : AppColors.blackberry)
                      : Colors.transparent,
                  borderRadius: AppRadius.segmentedControlRadius,
                  border: Border.all(
                    color: isDark ? AppColors.cream : AppColors.blackberry,
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      segment.displayName,
                      style: AppTextStyles.segmentedControl.copyWith(
                        color: isSelected
                            ? (isDark ? AppColors.blackberry : AppColors.cream)
                            : (isDark ? AppColors.cream : AppColors.blackberry),
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      segment.gkgValue,
                      style: AppTextStyles.smallLabel.copyWith(
                        fontSize: 10,
                        color: isSelected
                            ? (isDark
                                  ? AppColors.blackberry.withValues(alpha: 0.8)
                                  : AppColors.cream.withValues(alpha: 0.8))
                            : (isDark
                                  ? AppColors.cream.withValues(alpha: 0.6)
                                  : AppColors.blackberry.withValues(
                                      alpha: 0.6,
                                    )),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Sweat rate level segmented control
class KyleSweatRateSegmentedControl extends ConsumerWidget {
  const KyleSweatRateSegmentedControl({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final SweatRateCat selected;
  final ValueChanged<SweatRateCat> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return KyleSegmentedControl<SweatRateCat>(
      segments: SweatRateCat.values,
      selected: selected,
      onChanged: onChanged,
    );
  }
}

/// Sweat sodium category segmented control (Low / Average / High)
class KyleSweatSodiumSegmentedControl extends ConsumerWidget {
  const KyleSweatSodiumSegmentedControl({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final SweatSodiumCat selected;
  final ValueChanged<SweatSodiumCat> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return KyleSegmentedControl<SweatSodiumCat>(
      segments: SweatSodiumCat.values,
      selected: selected,
      onChanged: onChanged,
    );
  }
}

/// Intensity level segmented control
class KyleIntensitySegmentedControl extends ConsumerWidget {
  const KyleIntensitySegmentedControl({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final IntensityLevel selected;
  final ValueChanged<IntensityLevel> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return KyleSegmentedControl<IntensityLevel>(
      segments: IntensityLevel.values,
      selected: selected,
      onChanged: onChanged,
    );
  }
}

/// Intensity levels enum
enum IntensityLevel { easy, moderate, hard, veryHard }

/// Extension for gut training display names
extension GutTrainingDisplayExtension on GutTraining {
  String get displayName {
    switch (this) {
      case GutTraining.low:
        return 'LOW';
      case GutTraining.moderate:
        return 'MODERATE';
      case GutTraining.high:
        return 'HIGH';
    }
  }

  /// Get the band multiplier value for each gut training level
  String get gkgValue {
    switch (this) {
      case GutTraining.low:
        return '0.7\u00d7';
      case GutTraining.moderate:
        return '1.0\u00d7';
      case GutTraining.high:
        return '1.2\u00d7';
    }
  }
}

/// Extension for sweat rate display names
extension SweatRateCatDisplayExtension on SweatRateCat {
  String get displayName {
    switch (this) {
      case SweatRateCat.light:
        return 'LOW';
      case SweatRateCat.medium:
        return 'MODERATE';
      case SweatRateCat.heavy:
        return 'HIGH';
    }
  }
}

/// Extension for intensity level display names
extension IntensityLevelExtension on IntensityLevel {
  String get displayName {
    switch (this) {
      case IntensityLevel.easy:
        return 'EASY';
      case IntensityLevel.moderate:
        return 'MODERATE';
      case IntensityLevel.hard:
        return 'HARD';
      case IntensityLevel.veryHard:
        return 'VERY HARD';
    }
  }
}

/// Extension for gender display names
extension GenderDisplayExtension on Gender {
  String get displayName {
    switch (this) {
      case Gender.male:
        return 'Male';
      case Gender.female:
        return 'Female';
      case Gender.other:
        return 'Other';
    }
  }
}

/// Extension for theme mode display names
extension ThemeModeDisplayExtension on ThemeMode {
  String get displayName {
    switch (this) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }
}
