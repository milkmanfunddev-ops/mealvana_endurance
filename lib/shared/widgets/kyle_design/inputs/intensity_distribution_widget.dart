import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/intensity_distribution.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/workout_preset.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/cards/base_card.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/inputs/intensity_composite_bar.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/inputs/intensity_preset_chips.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/inputs/intensity_zone_slider.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_spacing.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_text_styles.dart';

/// Input mode for the intensity distribution widget.
enum _IntensityInputMode { estimate, precise }

/// Widget for adjusting workout intensity distribution across three training zones.
///
/// Supports two modes toggled via a segmented control in the header:
/// - **Estimate** (default): Tappable workout-type chips that map to preset splits
/// - **Precise**: Three zone sliders for fine-grained percentage adjustment
///
/// Both modes show the composite bar as visual confirmation of the distribution.
///
/// Props:
/// - value: Current intensity distribution
/// - onChanged: Callback when distribution changes
/// - sportType: Activity type for sport-specific chip labels
/// - enabled: Enable/disable all controls
class IntensityDistributionWidget extends ConsumerStatefulWidget {
  const IntensityDistributionWidget({
    super.key,
    required this.value,
    required this.onChanged,
    required this.sportType,
    this.enabled = true,
  });

  final IntensityDistribution value;
  final ValueChanged<IntensityDistribution> onChanged;
  final ActivityType sportType;
  final bool enabled;

  @override
  ConsumerState<IntensityDistributionWidget> createState() =>
      _IntensityDistributionWidgetState();
}

class _IntensityDistributionWidgetState
    extends ConsumerState<IntensityDistributionWidget> {
  _IntensityInputMode _mode = _IntensityInputMode.estimate;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Intensity distribution settings',
      container: true,
      child: BaseCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section label
            Text(
              'INTENSITY',
              style: AppTextStyles.sectionTitle.copyWith(
                fontSize: 14,
                letterSpacing: 1.5,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.cream
                    : AppColors.blackberry,
              ),
            ),

            const SizedBox(height: AppSpacing.md),

            // Estimate / Precise toggle
            _EstimatePreciseToggle(
              mode: _mode,
              enabled: widget.enabled,
              onChanged: (mode) => setState(() => _mode = mode),
            ),

            const SizedBox(height: AppSpacing.md),

            // Composite bar (shown in both modes)
            IntensityCompositeBar(
              conversationalPct: widget.value.conversationalPct,
              tempoPct: widget.value.tempoPct,
              allOutPct: widget.value.allOutPct,
              enabled: widget.enabled,
            ),

            const SizedBox(height: AppSpacing.lg),

            // Mode-specific content
            if (_mode == _IntensityInputMode.estimate)
              IntensityPresetChips(
                sportType: widget.sportType,
                selectedPreset:
                    WorkoutPresetData.matchingPreset(widget.value),
                onSelected: (preset) {
                  final distribution =
                      WorkoutPresetData.presetDistributions[preset]!;
                  widget.onChanged(distribution);
                },
                enabled: widget.enabled,
              )
            else ...[
              // Conversational Zone Slider (Z1-Z2)
              IntensityZoneSlider(
                label: 'Conversational (Z1-Z2)',
                color: IntensityCompositeBar.zoneConversationalColor,
                value: widget.value.conversationalPct,
                onChanged: (newValue) {
                  if (widget.enabled) {
                    final adjusted = widget.value.adjustProportionally(
                      conversationalPct: newValue,
                    );
                    widget.onChanged(adjusted);
                  }
                },
                enabled: widget.enabled,
              ),

              const SizedBox(height: AppSpacing.md),

              // Tempo Zone Slider (Z3-Z4)
              IntensityZoneSlider(
                label: 'Tempo (Z3-Z4)',
                color: IntensityCompositeBar.zoneTempoColor,
                value: widget.value.tempoPct,
                onChanged: (newValue) {
                  if (widget.enabled) {
                    final adjusted = widget.value.adjustProportionally(
                      tempoPct: newValue,
                    );
                    widget.onChanged(adjusted);
                  }
                },
                enabled: widget.enabled,
              ),

              const SizedBox(height: AppSpacing.md),

              // All-Out Zone Slider (Z5+)
              IntensityZoneSlider(
                label: 'All-Out (Z5+)',
                color: IntensityCompositeBar.zoneAllOutColor,
                value: widget.value.allOutPct,
                onChanged: (newValue) {
                  if (widget.enabled) {
                    final adjusted = widget.value.adjustProportionally(
                      allOutPct: newValue,
                    );
                    widget.onChanged(adjusted);
                  }
                },
                enabled: widget.enabled,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Inline two-segment toggle matching KyleSegmentedControl styling.
///
/// Displays "ESTIMATE" and "PRECISE" segments with the same visual treatment
/// as the app's segmented controls (15px radius, 2px border, 200ms animation).
class _EstimatePreciseToggle extends StatelessWidget {
  const _EstimatePreciseToggle({
    required this.mode,
    required this.enabled,
    required this.onChanged,
  });

  final _IntensityInputMode mode;
  final bool enabled;
  final ValueChanged<_IntensityInputMode> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: _IntensityInputMode.values.map((segment) {
        final isSelected = segment == mode;
        return Expanded(
          child: GestureDetector(
            onTap: enabled ? () => onChanged(segment) : null,
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
                  color: _borderColor(isDark),
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  segment.name.toUpperCase(),
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
          ),
        );
      }).toList(),
    );
  }

  Color _borderColor(bool isDark) {
    if (!enabled) {
      return isDark
          ? AppColors.cream.withValues(alpha: 0.3)
          : AppColors.blackberry.withValues(alpha: 0.3);
    }
    return isDark ? AppColors.cream : AppColors.blackberry;
  }
}
