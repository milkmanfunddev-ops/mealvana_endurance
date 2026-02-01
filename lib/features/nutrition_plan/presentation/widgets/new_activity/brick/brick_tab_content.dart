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
import '../../../../../../shared/widgets/kyle_design/inputs/indoor_outdoor_toggle.dart';
import '../shared/environment_section.dart';
import '../shared/deck_conditions_section.dart';

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

    final totalDuration = controller.getTotalDuration();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sport toggle selector (horizontal row)
        BrickSportToggleSelector(
          selectedSports: formState.selectedSports,
          onToggle: (sport) {
            controller.toggleSport(sport);
          },
        ),

        const SizedBox(height: AppSpacing.xl),

        // Ordered list of expandable segments
        if (formState.selectedSports.length >= 2)
          _buildSegmentList(context, ref, formState, controller, isDark),

        // Total duration display (if any segments have data)
        if (totalDuration > 0) ...[
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: Text(
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

  Widget _buildSegmentList(
    BuildContext context,
    WidgetRef ref,
    BrickFormState formState,
    BrickInputController controller,
    bool isDark,
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
          key: ValueKey(sport),
          sport: sport,
          order: index + 1,
          segmentInput: segmentInput,
          isDark: isDark,
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
  final ValueChanged<BrickSegmentInput> onUpdate;

  const _ExpandableSegmentCard({
    required super.key,
    required this.sport,
    required this.order,
    required this.segmentInput,
    required this.isDark,
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
                    index: widget.order - 1,
                    child: Icon(
                      Icons.drag_handle,
                      color: (widget.isDark ? AppColors.cream : AppColors.blackberry)
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
                        color: widget.isDark ? AppColors.cream : AppColors.blackberry,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),

                  // Duration summary (when collapsed)
                  if (!_isExpanded && (widget.segmentInput?.durationMinutes ?? 0) > 0)
                    Text(
                      '${widget.segmentInput!.durationMinutes} min',
                      style: AppTextStyles.descriptor.copyWith(
                        color: (widget.isDark ? AppColors.cream : AppColors.blackberry)
                            .withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),

                  const SizedBox(width: AppSpacing.sm),

                  // Expand/collapse icon
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: (widget.isDark ? AppColors.cream : AppColors.blackberry)
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
    final input = widget.segmentInput ??
        BrickSegmentInput(sport: widget.sport, order: widget.order);

    switch (widget.sport) {
      case 'running':
        return _BrickRunningInputs(
          input: input,
          isDark: widget.isDark,
          onUpdate: widget.onUpdate,
        );
      case 'cycling':
        return _BrickCyclingInputs(
          input: input,
          isDark: widget.isDark,
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

  IconData _getSportIcon(String sport) {
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
/// 3. Pre-Run Fueling Window
/// 4. Temperature
/// 5. Humidity
class _BrickRunningInputs extends StatelessWidget {
  final BrickSegmentInput input;
  final bool isDark;
  final ValueChanged<BrickSegmentInput> onUpdate;

  const _BrickRunningInputs({
    required this.input,
    required this.isDark,
    required this.onUpdate,
  });

  Duration? _computeEstimatedDuration() {
    final distance = input.distanceMiles ?? 3.0;
    final pace = input.paceMinutesPerMile ?? 9.0;
    if (distance <= 0 || pace <= 0) return null;
    final totalMinutes = distance * pace;
    return Duration(minutes: totalMinutes.floor());
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
          estimatedDuration: input.durationPaceMode == DurationPaceMode.byDuration
              ? Duration(minutes: input.durationMinutes)
              : _computeEstimatedDuration(),
          pace: input.paceMinutesPerMile ?? 9.0,
          paceUnit: 'min/mi',
          onDistanceChanged: (v) => onUpdate(input.copyWith(distanceMiles: v)),
          onModeChanged: (mode) => onUpdate(input.copyWith(durationPaceMode: mode)),
          onPaceChanged: (v) => onUpdate(input.copyWith(paceMinutesPerMile: v)),
          onDurationChanged: (duration) =>
              onUpdate(input.copyWith(durationMinutes: duration.inMinutes)),
          enabled: true,
        ),

        const SizedBox(height: AppSpacing.xl),

        // 2. INTENSITY DISTRIBUTION
        IntensityDistributionWidget(
          value: input.intensityDistribution ??
              IntensityDistribution.defaultDistribution(),
          onChanged: (intensity) {
            onUpdate(input.copyWith(intensityDistribution: intensity));
          },
          sportType: ActivityType.running,
          enabled: true,
        ),

        const SizedBox(height: AppSpacing.xl),

        // 3. PRE-RUN FUELING WINDOW
        KylePlusMinusControl(
          label: 'Pre-Run Fueling Window',
          value: input.preActivityMinutes,
          onChanged: (v) => onUpdate(input.copyWith(preActivityMinutes: v)),
          min: 0,
          max: 480,
          step: 15,
          unit: 'minutes',
        ),

        const SizedBox(height: AppSpacing.xl),

        // 4. TEMPERATURE
        KylePlusMinusDecimalControl(
          label: 'Temperature',
          value: input.temperatureC,
          onChanged: (v) => onUpdate(input.copyWith(temperatureC: v)),
          min: -5.0,
          max: 40.0,
          step: 1.0,
          decimalPlaces: 0,
          unit: '°C',
        ),

        const SizedBox(height: AppSpacing.xl),

        // 5. HUMIDITY
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
/// 3. Time Before Ride
/// 4. Indoor/Outdoor Toggle
/// 5. Environment Section (collapsible)
class _BrickCyclingInputs extends StatelessWidget {
  final BrickSegmentInput input;
  final bool isDark;
  final ValueChanged<BrickSegmentInput> onUpdate;

  const _BrickCyclingInputs({
    required this.input,
    required this.isDark,
    required this.onUpdate,
  });

  bool get _isIndoor => (input.indoorOutdoor ?? 'outdoor') == 'indoor' ||
      (input.terrain ?? '').contains('indoor');

  Duration? _computeEstimatedDuration() {
    final distance = input.distanceMiles ?? 20.0;
    final speed = input.speedMph ?? 18.0;
    if (distance <= 0 || speed <= 0) return null;
    final totalMinutes = (distance / speed) * 60;
    return Duration(minutes: totalMinutes.floor());
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
          estimatedDuration: input.durationPaceMode == DurationPaceMode.byDuration
              ? Duration(minutes: input.durationMinutes)
              : _computeEstimatedDuration(),
          pace: input.speedMph ?? 18.0,
          paceUnit: 'mph',
          onDistanceChanged: (v) => onUpdate(input.copyWith(distanceMiles: v)),
          onModeChanged: (mode) => onUpdate(input.copyWith(durationPaceMode: mode)),
          onPaceChanged: (v) => onUpdate(input.copyWith(speedMph: v)),
          onDurationChanged: (duration) =>
              onUpdate(input.copyWith(durationMinutes: duration.inMinutes)),
        ),

        const SizedBox(height: AppSpacing.xl),

        // 2. INTENSITY DISTRIBUTION
        IntensityDistributionWidget(
          value: input.intensityDistribution ??
              IntensityDistribution.defaultDistribution(),
          onChanged: (intensity) {
            onUpdate(input.copyWith(intensityDistribution: intensity));
          },
          sportType: ActivityType.cycling,
        ),

        const SizedBox(height: AppSpacing.xl),

        // 3. TIME BEFORE RIDE
        KylePlusMinusControl(
          label: 'Time Before Ride',
          value: input.preActivityMinutes,
          onChanged: (v) => onUpdate(input.copyWith(preActivityMinutes: v)),
          min: 0,
          max: 480,
          step: 15,
          unit: 'minutes',
        ),

        const SizedBox(height: AppSpacing.xl),

        // 4. INDOOR/OUTDOOR TOGGLE
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
                onUpdate(input.copyWith(
                  indoorOutdoor: indoor ? 'indoor' : 'outdoor',
                  terrain: terrain,
                ));
              },
              isDark: isDark,
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.xl),

        // 5. ENVIRONMENT SECTION (collapsible, no weather params)
        EnvironmentSection(
          isExpanded: input.showEnvironment,
          onToggle: () => onUpdate(input.copyWith(showEnvironment: !input.showEnvironment)),
          temperatureC: input.temperatureC,
          onTemperatureChanged: (v) => onUpdate(input.copyWith(temperatureC: v)),
          humidityPct: input.humidityPct,
          onHumidityChanged: (v) => onUpdate(input.copyWith(humidityPct: v)),
          windCondition: input.windCondition,
          onWindChanged: (v) => onUpdate(input.copyWith(windCondition: v)),
          sunExposure: input.sunExposure,
          onSunChanged: (v) => onUpdate(input.copyWith(sunExposure: v)),
          isIndoor: isIndoor,
        ),
      ],
    );
  }
}

// =============================================================================
// SWIMMING INPUTS - matches swimming_tab_content.dart sections
// =============================================================================

/// Water type enum for segmented control in brick swimming segment
enum _BrickWaterType {
  pool,
  openWater,
}

/// Swimming segment inputs matching the standalone swimming tab:
/// 1. WorkoutDetailsWidget
/// 2. IntensityDistribution
/// 3. Time Before Swim
/// 4. Pool/Open Water toggle
/// 5. Deck Conditions (collapsible)
class _BrickSwimmingInputs extends StatelessWidget {
  final BrickSegmentInput input;
  final bool isDark;
  final ValueChanged<BrickSegmentInput> onUpdate;

  const _BrickSwimmingInputs({
    required this.input,
    required this.isDark,
    required this.onUpdate,
  });

  Duration? _computeEstimatedDuration() {
    final distance = input.distanceMeters ?? 1500.0;
    final pacePer100m = (input.pacePer100mSeconds ?? 120).toDouble();
    if (distance <= 0 || pacePer100m <= 0) return null;
    final totalSeconds = (distance / 100) * pacePer100m;
    return Duration(seconds: totalSeconds.floor());
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
          estimatedDuration: input.durationPaceMode == DurationPaceMode.byDuration
              ? Duration(minutes: input.durationMinutes)
              : _computeEstimatedDuration(),
          pace: (input.pacePer100mSeconds ?? 120).toDouble() / 60, // Convert seconds to minutes
          paceUnit: 'min/100m',
          onDistanceChanged: (distance) =>
              onUpdate(input.copyWith(distanceMeters: distance)),
          onModeChanged: (mode) => onUpdate(input.copyWith(durationPaceMode: mode)),
          onPaceChanged: (paceMinutes) =>
              onUpdate(input.copyWith(pacePer100mSeconds: (paceMinutes * 60).round())),
          onDurationChanged: (duration) =>
              onUpdate(input.copyWith(durationMinutes: duration.inMinutes)),
        ),

        const SizedBox(height: AppSpacing.xl),

        // 2. INTENSITY DISTRIBUTION
        IntensityDistributionWidget(
          value: input.intensityDistribution ??
              IntensityDistribution.defaultDistribution(),
          onChanged: (intensity) {
            onUpdate(input.copyWith(intensityDistribution: intensity));
          },
          sportType: ActivityType.swimming,
        ),

        const SizedBox(height: AppSpacing.xl),

        // 3. TIME BEFORE SWIM
        KylePlusMinusControl(
          label: 'Time Before Swim',
          value: input.preActivityMinutes,
          onChanged: (v) => onUpdate(input.copyWith(preActivityMinutes: v)),
          min: 0,
          max: 480,
          step: 15,
          unit: 'minutes',
        ),

        const SizedBox(height: AppSpacing.xl),

        // 4. POOL/OPEN WATER TOGGLE
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
                onUpdate(input.copyWith(
                  poolOrOpenWater: type == _BrickWaterType.pool ? 'pool' : 'open_water',
                ));
              },
            ),
          ],
        ),

        const SizedBox(height: AppSpacing.xl),

        // 5. DECK CONDITIONS (collapsible, no weather params)
        DeckConditionsSection(
          isExpanded: input.showEnvironment,
          onToggle: () => onUpdate(input.copyWith(showEnvironment: !input.showEnvironment)),
          deckTemperature: input.deckTemperature,
          onTemperatureChanged: (v) => onUpdate(input.copyWith(deckTemperature: v)),
          deckHumidity: input.deckHumidity,
          onHumidityChanged: (v) => onUpdate(input.copyWith(deckHumidity: v)),
        ),
      ],
    );
  }
}

