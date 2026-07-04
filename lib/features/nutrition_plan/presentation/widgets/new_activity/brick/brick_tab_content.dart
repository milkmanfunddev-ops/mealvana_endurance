import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../providers/brick_input_controller.dart';
import 'brick_sport_toggle_selector.dart';
import '../../../../../../shared/widgets/kyle_design/inputs/plus_minus_control.dart';
import '../../../../../../shared/widgets/kyle_design/inputs/intensity_distribution_widget.dart';
import '../../../../../../shared/widgets/kyle_design/inputs/duration_pace_toggle.dart';
import '../../../../../../shared/widgets/kyle_design/buttons/segmented_control.dart';
import '../../../../../../features/nutrition_plan/domain/intensity_distribution.dart';
import '../../../../../../shared/domain/activity_type.dart';
import '../../../../../../theme/kyle_design/app_spacing.dart';
import '../../../../../../theme/kyle_design/app_text_styles.dart';
import '../../../../../../theme/kyle_design/app_colors.dart';
import '../shared/workout_details_widget.dart';
import '../shared/activity_name_field.dart';
import '../../../../../../shared/widgets/kyle_design/inputs/indoor_outdoor_toggle.dart';
import '../shared/environment_section.dart';
import '../shared/fasted_toggle.dart';
import '../../../../../../shared/providers/unit_system_provider.dart';
import '../../../../../../features/nutrition_plan/domain/run_parameters.dart' show UnitSystem;

/// Brick Tab Content
///
/// Main content widget for the brick workout tab in the New Activity screen.
/// Displays:
/// - Sport toggle selector (horizontal row of toggle buttons)
/// - Expandable segment cards with full sport-specific inputs
///   matching the standalone swim/bike/run tabs
///
/// Note: The "Generate Plan" button is in the parent NewActivityScreen.
class BrickTabContent extends ConsumerWidget {
  const BrickTabContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formState = ref.watch(brickInputControllerProvider);
    final controller = ref.read(brickInputControllerProvider.notifier);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final useImperial =
        (ref.watch(unitSystemProvider).value ?? UnitSystem.imperial) != UnitSystem.metric;

    final totalDuration = controller.getTotalDuration();
    final showFastedWarning = _shouldWarnFasted(formState, controller);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ActivityNameField(
          key: const ValueKey('brick.workout_name_field'),
          value: formState.activityTitle,
          onChanged: controller.updateActivityTitle,
          hint: 'e.g., SWIM/BIKE BRICK',
        ),

        const SizedBox(height: AppSpacing.xl),

        // Sport toggle selector (horizontal row)
        BrickSportToggleSelector(
          selectedSports: formState.selectedSports,
          onToggle: (sport) {
            controller.toggleSport(sport);
          },
        ),

        const SizedBox(height: AppSpacing.xl),

        // Brick-level Pre-Activity Fueling Window (applies to whole brick)
        KylePlusMinusControl(
          key: const ValueKey('brick.fueling_window_control'),
          label: 'Pre-Activity Fueling Window',
          value: formState.preActivityMinutes,
          onChanged: controller.updatePreActivityMinutes,
          min: 0,
          max: 480,
          step: 15,
          unit: 'minutes',
        ),

        const SizedBox(height: AppSpacing.xl),

        // Brick-level Fasted Toggle (applies to pre-activity fueling only)
        FastedToggle(
          key: const ValueKey('brick.fasted_toggle'),
          isFasted: formState.isFasted,
          onChanged: controller.updateFasted,
          showWarning: showFastedWarning,
          warningText:
              'Fasted training is not recommended for longer or harder bricks. Consider fueling before.',
        ),

        const SizedBox(height: AppSpacing.xl),

        // Ordered list of expandable segments
        if (formState.selectedSports.length >= 2)
          _buildSegmentList(context, ref, formState, controller, isDark, useImperial),

        // Total duration display (if any segments have data)
        if (totalDuration > 0) ...[
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: Text(
              key: const ValueKey('brick.total_duration_label'),
              'Total Duration: $totalDuration minutes',
              style: AppTextStyles.descriptor.copyWith(
                color: isDark ? AppColors.cream : AppColors.blackberry,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.lg),
      ],
    );
  }

  bool _shouldWarnFasted(
    BrickFormState formState,
    BrickInputController controller,
  ) {
    // Warn if any segment is swimming, any segment is hard (conversational < 70),
    // or the total brick duration is long.
    if (formState.selectedSports.contains('swimming')) return true;

    for (final sport in formState.selectedSports) {
      final input = formState.segmentInputs[sport];
      if (input == null) continue;
      final intensity =
          input.intensityDistribution ??
          IntensityDistribution.defaultDistribution();
      if (intensity.conversationalPct < 70) return true;
    }

    final totalDuration = controller.getTotalDuration();
    if (totalDuration > 75) return true;

    return false;
  }

  Widget _buildSegmentList(
    BuildContext context,
    WidgetRef ref,
    BrickFormState formState,
    BrickInputController controller,
    bool isDark,
    bool useImperial,
  ) {
    // Filter to only show selected sports in the current order
    final orderedSelectedSports = formState.sportOrder
        .where((sport) => formState.selectedSports.contains(sport))
        .toList();

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: orderedSelectedSports.length,
      onReorder: controller.reorderSports,
      proxyDecorator: (child, index, animation) {
        return Material(
          color: Colors.transparent,
          elevation: 4,
          shadowColor: AppColors.blackberry.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          child: child,
        );
      },
      itemBuilder: (context, index) {
        final sport = orderedSelectedSports[index];
        final segmentInput = formState.segmentInputs[sport];

        return _ExpandableSegmentCard(
          key: ValueKey('brick.segment_card_$index'),
          sport: sport,
          order: index + 1,
          segmentInput: segmentInput,
          isDark: isDark,
          useImperial: useImperial,
          onUpdate: (updated) => controller.updateSegmentInput(sport, updated),
        );
      },
    );
  }
}

/// Expandable segment card with sport-specific input fields
class _ExpandableSegmentCard extends StatefulWidget {
  final String sport;
  final int order;
  final BrickSegmentInput? segmentInput;
  final bool isDark;
  final bool useImperial;
  final ValueChanged<BrickSegmentInput> onUpdate;

  const _ExpandableSegmentCard({
    required super.key,
    required this.sport,
    required this.order,
    required this.segmentInput,
    required this.isDark,
    required this.useImperial,
    required this.onUpdate,
  });

  @override
  State<_ExpandableSegmentCard> createState() => _ExpandableSegmentCardState();
}

class _ExpandableSegmentCardState extends State<_ExpandableSegmentCard> {
  bool _isExpanded = false; // Start collapsed

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: (widget.isDark ? AppColors.blackberry : AppColors.cream)
            .withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _getSportColor(widget.sport).withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          // Header (always visible)
          GestureDetector(
            key: ValueKey('brick.segment_expand_${widget.order - 1}'),
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  // Drag handle
                  ReorderableDragStartListener(
                    key: ValueKey('brick.segment_reorder_${widget.order - 1}'),
                    index: widget.order - 1,
                    child: Icon(
                      Icons.drag_handle,
                      color:
                          (widget.isDark
                                  ? AppColors.cream
                                  : AppColors.blackberry)
                              .withValues(alpha: 0.5),
                    ),
                  ),

                  const SizedBox(width: AppSpacing.sm),

                  // Sport icon
                  FaIcon(
                    _getSportIcon(widget.sport),
                    size: 18,
                    color: _getSportColor(widget.sport),
                  ),

                  const SizedBox(width: AppSpacing.sm),

                  // Sport name
                  Expanded(
                    child: Text(
                      '${widget.order}. ${_getSportDisplayName(widget.sport)}',
                      style: AppTextStyles.descriptor.copyWith(
                        color: widget.isDark
                            ? AppColors.cream
                            : AppColors.blackberry,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),

                  // Duration summary (when collapsed)
                  if (!_isExpanded &&
                      (widget.segmentInput?.durationMinutes ?? 0) > 0)
                    Text(
                      '${widget.segmentInput!.durationMinutes} min',
                      style: AppTextStyles.descriptor.copyWith(
                        color:
                            (widget.isDark
                                    ? AppColors.cream
                                    : AppColors.blackberry)
                                .withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),

                  const SizedBox(width: AppSpacing.sm),

                  // Expand/collapse icon
                  Icon(
                    _isExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color:
                        (widget.isDark ? AppColors.cream : AppColors.blackberry)
                            .withValues(alpha: 0.5),
                  ),
                ],
              ),
            ),
          ),

          // Expandable content
          if (_isExpanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: _buildSportInputs(),
            ),
        ],
      ),
    );
  }

  Widget _buildSportInputs() {
    final input =
        widget.segmentInput ??
        BrickSegmentInput(sport: widget.sport, order: widget.order);

    switch (widget.sport) {
      case 'running':
        return _BrickRunningInputs(
          input: input,
          isDark: widget.isDark,
          useImperial: widget.useImperial,
          onUpdate: widget.onUpdate,
        );
      case 'cycling':
        return _BrickCyclingInputs(
          input: input,
          isDark: widget.isDark,
          useImperial: widget.useImperial,
          onUpdate: widget.onUpdate,
        );
      case 'swimming':
        return _BrickSwimmingInputs(
          input: input,
          isDark: widget.isDark,
          onUpdate: widget.onUpdate,
        );
      default:
        return const SizedBox.shrink();
    }
  }

  FaIconData _getSportIcon(String sport) {
    switch (sport) {
      case 'swimming':
        return FontAwesomeIcons.personSwimming;
      case 'cycling':
        return FontAwesomeIcons.personBiking;
      case 'running':
        return FontAwesomeIcons.personRunning;
      default:
        return FontAwesomeIcons.dumbbell;
    }
  }

  Color _getSportColor(String sport) {
    switch (sport) {
      case 'swimming':
        return const Color(0xFF4A90D9);
      case 'cycling':
        return AppColors.orange;
      case 'running':
        return AppColors.electrolyte;
      default:
        return AppColors.cream;
    }
  }

  String _getSportDisplayName(String sport) {
    switch (sport) {
      case 'swimming':
        return 'SWIM';
      case 'cycling':
        return 'BIKE';
      case 'running':
        return 'RUN';
      default:
        return sport.toUpperCase();
    }
  }
}

// =============================================================================
// RUNNING INPUTS - matches running_tab_content.dart sections
// =============================================================================

/// Running segment inputs matching the standalone running tab:
/// 1. WorkoutDetailsWidget
/// 2. IntensityDistribution
/// 3. Temperature
/// 4. Humidity
class _BrickRunningInputs extends StatelessWidget {
  final BrickSegmentInput input;
  final bool isDark;
  final bool useImperial;
  final ValueChanged<BrickSegmentInput> onUpdate;

  const _BrickRunningInputs({
    required this.input,
    required this.isDark,
    required this.useImperial,
    required this.onUpdate,
  });

  int _computeEstimatedDurationMinutesFor(BrickSegmentInput data) {
    final distance = data.distanceMiles ?? 3.0;
    final pace = data.paceMinutesPerMile ?? 9.0;
    if (distance <= 0 || pace <= 0) return 0;
    return (distance * pace).round();
  }

  Duration? _computeEstimatedDuration() {
    final minutes = _computeEstimatedDurationMinutesFor(input);
    if (minutes <= 0) return null;
    return Duration(minutes: minutes);
  }

  Duration? _getDisplayedDuration() {
    if (input.durationPaceMode == DurationPaceMode.byDuration) {
      if (input.durationMinutes > 0) {
        return Duration(minutes: input.durationMinutes);
      }
      return _computeEstimatedDuration();
    }
    return _computeEstimatedDuration();
  }

  double? _computePaceFromDuration(BrickSegmentInput data, Duration duration) {
    final distance = data.distanceMiles ?? 0;
    if (distance <= 0) return null;
    final totalMinutes = duration.inSeconds / 60.0;
    if (totalMinutes <= 0) return null;
    return totalMinutes / distance;
  }

  void _updateDerivedFields(BrickSegmentInput updated) {
    if (updated.durationPaceMode == DurationPaceMode.byDuration) {
      if (updated.durationMinutes > 0) {
        final pace = _computePaceFromDuration(
          updated,
          Duration(minutes: updated.durationMinutes),
        );
        if (pace != null) {
          onUpdate(updated.copyWith(paceMinutesPerMile: pace));
          return;
        }
        onUpdate(updated);
        return;
      }
    }

    final autoMinutes = _computeEstimatedDurationMinutesFor(updated);
    if (autoMinutes > 0) {
      onUpdate(updated.copyWith(durationMinutes: autoMinutes));
      return;
    }
    onUpdate(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. WORKOUT DETAILS
        WorkoutDetailsWidget(
          sport: ActivityType.running,
          distance: input.distanceMiles ?? 3.0,
          distanceUnit: 'mi',
          mode: input.durationPaceMode,
          estimatedDuration: _getDisplayedDuration(),
          pace: input.paceMinutesPerMile ?? 9.0,
          paceUnit: 'min/mi',
          onDistanceChanged: (v) =>
              _updateDerivedFields(input.copyWith(distanceMiles: v)),
          onModeChanged: (mode) {
            final updated = input.copyWith(durationPaceMode: mode);
            _updateDerivedFields(updated);
          },
          onPaceChanged: (v) =>
              _updateDerivedFields(input.copyWith(paceMinutesPerMile: v)),
          onDurationChanged: (duration) {
            final pace = _computePaceFromDuration(input, duration);
            onUpdate(
              input.copyWith(
                durationMinutes: duration.inMinutes,
                paceMinutesPerMile: pace ?? input.paceMinutesPerMile,
              ),
            );
          },
          enabled: true,
        ),

        const SizedBox(height: AppSpacing.xl),

        // 2. INTENSITY DISTRIBUTION
        IntensityDistributionWidget(
          value:
              input.intensityDistribution ??
              IntensityDistribution.defaultDistribution(),
          onChanged: (intensity) {
            onUpdate(input.copyWith(intensityDistribution: intensity));
          },
          sportType: ActivityType.running,
          enabled: true,
        ),

        const SizedBox(height: AppSpacing.xl),

        // 3. TEMPERATURE
        KylePlusMinusDecimalControl(
          label: 'Temperature',
          value: useImperial ? (input.temperatureC * 9 / 5) + 32 : input.temperatureC,
          onChanged: useImperial
              ? (f) => onUpdate(input.copyWith(temperatureC: (f - 32) * 5 / 9))
              : (v) => onUpdate(input.copyWith(temperatureC: v)),
          min: useImperial ? 23.0 : -5.0,
          max: useImperial ? 104.0 : 40.0,
          step: useImperial ? 2.0 : 1.0,
          decimalPlaces: 0,
          unit: useImperial ? '°F' : '°C',
        ),

        const SizedBox(height: AppSpacing.xl),

        // 4. HUMIDITY
        KylePlusMinusDecimalControl(
          label: 'Humidity',
          value: input.humidityPct,
          onChanged: (v) => onUpdate(input.copyWith(humidityPct: v)),
          min: 20.0,
          max: 95.0,
          step: 5.0,
          decimalPlaces: 0,
          unit: '%',
        ),
      ],
    );
  }
}

// =============================================================================
// CYCLING INPUTS - matches cycling_tab_content.dart sections
// =============================================================================

/// Cycling segment inputs matching the standalone cycling tab:
/// 1. WorkoutDetailsWidget
/// 2. IntensityDistribution
/// 3. Indoor/Outdoor Toggle
/// 4. Environment Section (collapsible)
class _BrickCyclingInputs extends StatelessWidget {
  final BrickSegmentInput input;
  final bool isDark;
  final bool useImperial;
  final ValueChanged<BrickSegmentInput> onUpdate;

  const _BrickCyclingInputs({
    required this.input,
    required this.isDark,
    required this.useImperial,
    required this.onUpdate,
  });

  bool get _isIndoor =>
      (input.indoorOutdoor ?? 'outdoor') == 'indoor' ||
      (input.terrain ?? '').contains('indoor');

  int _computeEstimatedDurationMinutesFor(BrickSegmentInput data) {
    final distance = data.distanceMiles ?? 20.0;
    final speed = data.speedMph ?? 18.0;
    if (distance <= 0 || speed <= 0) return 0;
    return ((distance / speed) * 60).round();
  }

  Duration? _computeEstimatedDuration() {
    final minutes = _computeEstimatedDurationMinutesFor(input);
    if (minutes <= 0) return null;
    return Duration(minutes: minutes);
  }

  Duration? _getDisplayedDuration() {
    if (input.durationPaceMode == DurationPaceMode.byDuration) {
      if (input.durationMinutes > 0) {
        return Duration(minutes: input.durationMinutes);
      }
      return _computeEstimatedDuration();
    }
    return _computeEstimatedDuration();
  }

  double? _computeSpeedFromDuration(BrickSegmentInput data, Duration duration) {
    final distance = data.distanceMiles ?? 0;
    if (distance <= 0) return null;
    final hours = duration.inSeconds / 3600.0;
    if (hours <= 0) return null;
    return distance / hours;
  }

  void _updateDerivedFields(BrickSegmentInput updated) {
    if (updated.durationPaceMode == DurationPaceMode.byDuration) {
      if (updated.durationMinutes > 0) {
        final speed = _computeSpeedFromDuration(
          updated,
          Duration(minutes: updated.durationMinutes),
        );
        if (speed != null) {
          onUpdate(updated.copyWith(speedMph: speed));
          return;
        }
        onUpdate(updated);
        return;
      }
    }

    final autoMinutes = _computeEstimatedDurationMinutesFor(updated);
    if (autoMinutes > 0) {
      onUpdate(updated.copyWith(durationMinutes: autoMinutes));
      return;
    }
    onUpdate(updated);
  }

  @override
  Widget build(BuildContext context) {
    final isIndoor = _isIndoor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. WORKOUT DETAILS
        WorkoutDetailsWidget(
          sport: ActivityType.cycling,
          distance: input.distanceMiles ?? 20.0,
          distanceUnit: 'mi',
          mode: input.durationPaceMode,
          estimatedDuration: _getDisplayedDuration(),
          pace: input.speedMph ?? 18.0,
          paceUnit: 'mph',
          onDistanceChanged: (v) =>
              _updateDerivedFields(input.copyWith(distanceMiles: v)),
          onModeChanged: (mode) {
            final updated = input.copyWith(durationPaceMode: mode);
            _updateDerivedFields(updated);
          },
          onPaceChanged: (v) =>
              _updateDerivedFields(input.copyWith(speedMph: v)),
          onDurationChanged: (duration) {
            final speed = _computeSpeedFromDuration(input, duration);
            onUpdate(
              input.copyWith(
                durationMinutes: duration.inMinutes,
                speedMph: speed ?? input.speedMph,
              ),
            );
          },
        ),

        const SizedBox(height: AppSpacing.xl),

        // 2. INTENSITY DISTRIBUTION
        IntensityDistributionWidget(
          value:
              input.intensityDistribution ??
              IntensityDistribution.defaultDistribution(),
          onChanged: (intensity) {
            onUpdate(input.copyWith(intensityDistribution: intensity));
          },
          sportType: ActivityType.cycling,
        ),

        const SizedBox(height: AppSpacing.xl),

        // 3. INDOOR/OUTDOOR TOGGLE
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Environment',
              style: AppTextStyles.descriptor.copyWith(
                color: isDark ? AppColors.cream : AppColors.blackberry,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            IndoorOutdoorToggle(
              isIndoor: isIndoor,
              onChanged: (indoor) {
                final terrain = indoor ? 'flat_indoor' : 'flat_outdoor';
                onUpdate(
                  input.copyWith(
                    indoorOutdoor: indoor ? 'indoor' : 'outdoor',
                    terrain: terrain,
                  ),
                );
              },
              isDark: isDark,
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.xl),

        // 4. ENVIRONMENT SECTION (collapsible, no weather params)
        EnvironmentSection(
          isExpanded: input.showEnvironment,
          onToggle: () =>
              onUpdate(input.copyWith(showEnvironment: !input.showEnvironment)),
          temperatureC: input.temperatureC,
          onTemperatureChanged: (v) =>
              onUpdate(input.copyWith(temperatureC: v)),
          humidityPct: input.humidityPct,
          onHumidityChanged: (v) => onUpdate(input.copyWith(humidityPct: v)),
          windCondition: input.windCondition,
          onWindChanged: (v) => onUpdate(input.copyWith(windCondition: v)),
          sunExposure: input.sunExposure,
          onSunChanged: (v) => onUpdate(input.copyWith(sunExposure: v)),
          isIndoor: isIndoor,
          showWindAndSun: false,
          useImperial: useImperial,
        ),
      ],
    );
  }
}

// =============================================================================
// SWIMMING INPUTS - matches swimming_tab_content.dart sections
// =============================================================================

/// Water type enum for segmented control in brick swimming segment
enum _BrickWaterType { pool, openWater }

/// Swimming segment inputs matching the standalone swimming tab:
/// 1. WorkoutDetailsWidget
/// 2. IntensityDistribution
/// 3. Pool/Open Water toggle
class _BrickSwimmingInputs extends StatelessWidget {
  final BrickSegmentInput input;
  final bool isDark;
  final ValueChanged<BrickSegmentInput> onUpdate;

  const _BrickSwimmingInputs({
    required this.input,
    required this.isDark,
    required this.onUpdate,
  });

  int _computeEstimatedDurationMinutesFor(BrickSegmentInput data) {
    final distance = data.distanceMeters ?? 1500.0;
    final pacePer100m = (data.pacePer100mSeconds ?? 120).toDouble();
    if (distance <= 0 || pacePer100m <= 0) return 0;
    final totalSeconds = (distance / 100) * pacePer100m;
    return (totalSeconds / 60).round();
  }

  Duration? _computeEstimatedDuration() {
    final minutes = _computeEstimatedDurationMinutesFor(input);
    if (minutes <= 0) return null;
    return Duration(minutes: minutes);
  }

  Duration? _getDisplayedDuration() {
    if (input.durationPaceMode == DurationPaceMode.byDuration) {
      if (input.durationMinutes > 0) {
        return Duration(minutes: input.durationMinutes);
      }
      return _computeEstimatedDuration();
    }
    return _computeEstimatedDuration();
  }

  int? _computePaceFromDuration(BrickSegmentInput data, Duration duration) {
    final distance = data.distanceMeters ?? 0;
    if (distance <= 0) return null;
    final segments = distance / 100.0;
    if (segments <= 0) return null;
    final totalSeconds = duration.inSeconds;
    if (totalSeconds <= 0) return null;
    return (totalSeconds / segments).round();
  }

  void _updateDerivedFields(BrickSegmentInput updated) {
    if (updated.durationPaceMode == DurationPaceMode.byDuration) {
      if (updated.durationMinutes > 0) {
        final pace = _computePaceFromDuration(
          updated,
          Duration(minutes: updated.durationMinutes),
        );
        if (pace != null) {
          onUpdate(updated.copyWith(pacePer100mSeconds: pace));
          return;
        }
        onUpdate(updated);
        return;
      }
    }

    final autoMinutes = _computeEstimatedDurationMinutesFor(updated);
    if (autoMinutes > 0) {
      onUpdate(updated.copyWith(durationMinutes: autoMinutes));
      return;
    }
    onUpdate(updated);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. WORKOUT DETAILS
        WorkoutDetailsWidget(
          sport: ActivityType.swimming,
          distance: (input.distanceMeters ?? 1500).toDouble(),
          distanceUnit: 'meters',
          mode: input.durationPaceMode,
          estimatedDuration: _getDisplayedDuration(),
          pace:
              (input.pacePer100mSeconds ?? 120).toDouble() /
              60, // Convert seconds to minutes
          paceUnit: 'min/100m',
          onDistanceChanged: (distance) =>
              _updateDerivedFields(input.copyWith(distanceMeters: distance)),
          onModeChanged: (mode) {
            final updated = input.copyWith(durationPaceMode: mode);
            _updateDerivedFields(updated);
          },
          onPaceChanged: (paceMinutes) => _updateDerivedFields(
            input.copyWith(pacePer100mSeconds: (paceMinutes * 60).round()),
          ),
          onDurationChanged: (duration) {
            final pace = _computePaceFromDuration(input, duration);
            onUpdate(
              input.copyWith(
                durationMinutes: duration.inMinutes,
                pacePer100mSeconds: pace ?? input.pacePer100mSeconds,
              ),
            );
          },
        ),

        const SizedBox(height: AppSpacing.xl),

        // 2. INTENSITY DISTRIBUTION
        IntensityDistributionWidget(
          value:
              input.intensityDistribution ??
              IntensityDistribution.defaultDistribution(),
          onChanged: (intensity) {
            onUpdate(input.copyWith(intensityDistribution: intensity));
          },
          sportType: ActivityType.swimming,
        ),

        const SizedBox(height: AppSpacing.xl),

        // 3. POOL/OPEN WATER TOGGLE
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
            KyleSegmentedControl<_BrickWaterType>(
              segments: _BrickWaterType.values,
              selected: (input.poolOrOpenWater ?? 'pool') == 'pool'
                  ? _BrickWaterType.pool
                  : _BrickWaterType.openWater,
              onChanged: (type) {
                onUpdate(
                  input.copyWith(
                    poolOrOpenWater: type == _BrickWaterType.pool
                        ? 'pool'
                        : 'open_water',
                  ),
                );
              },
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.xxl),
      ],
    );
  }
}
