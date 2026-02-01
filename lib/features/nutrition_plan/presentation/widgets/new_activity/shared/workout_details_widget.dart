import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/inputs/duration_pace_toggle.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_spacing.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_text_styles.dart';

/// Workout Details Widget
///
/// Displays distance input with duration/pace toggle and estimated field.
///
/// Sport-specific behavior:
/// - Running: "Estimated Duration" when By Duration, "Average Pace" (min:sec/mi) when By Pace
/// - Cycling: "Estimated Duration" when By Duration, "Average Speed" (mph) when By Speed
/// - Swimming: "Estimated Duration" when By Duration, "Average Pace" (min:sec/100) when By Pace
///
/// Usage:
/// ```dart
/// WorkoutDetailsWidget(
///   sport: ActivityType.running,
///   distance: 18.0,
///   distanceUnit: 'mi',
///   mode: DurationPaceMode.byDuration,
///   estimatedDuration: Duration(hours: 2, minutes: 38),
///   pace: 8.78, // min/mile
///   paceUnit: 'min/mi',
///   onDistanceChanged: (value) => controller.updateDistance(value),
///   onModeChanged: (mode) => controller.updateMode(mode),
///   onPaceChanged: (pace) => controller.updatePace(pace),
/// )
/// ```
class WorkoutDetailsWidget extends StatelessWidget {
  const WorkoutDetailsWidget({
    super.key,
    required this.sport,
    required this.distance,
    required this.distanceUnit,
    required this.mode,
    this.estimatedDuration,
    this.pace,
    required this.paceUnit,
    required this.onDistanceChanged,
    required this.onModeChanged,
    required this.onPaceChanged,
    this.onDurationChanged,
    this.enabled = true,
  });

  final ActivityType sport;
  final double distance;
  final String distanceUnit;
  final DurationPaceMode mode;
  final Duration? estimatedDuration;
  final double? pace;
  final String paceUnit;
  final ValueChanged<double> onDistanceChanged;
  final ValueChanged<DurationPaceMode> onModeChanged;
  final ValueChanged<double> onPaceChanged;
  final ValueChanged<Duration>? onDurationChanged;
  final bool enabled;

  String get _secondaryFieldLabel {
    if (mode == DurationPaceMode.byDuration) {
      return 'Estimated Duration';
    } else {
      // By Pace mode
      if (sport == ActivityType.cycling) {
        return 'Average Speed';
      } else {
        return 'Average Pace';
      }
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '$hours:${minutes.toString().padLeft(2, '0')}';
    } else {
      return '$minutes min';
    }
  }

  String _formatPace(double paceValue) {
    if (sport == ActivityType.cycling) {
      // Speed in mph/kph
      return paceValue.toStringAsFixed(1);
    } else {
      // Pace in min/mile or min/100m
      final minutes = paceValue.floor();
      final seconds = ((paceValue - minutes) * 60).round();
      return '$minutes:${seconds.toString().padLeft(2, '0')}';
    }
  }

  String get _secondaryFieldValue {
    if (mode == DurationPaceMode.byDuration) {
      if (estimatedDuration == null) {
        return '--';
      }
      return _formatDuration(estimatedDuration!);
    } else {
      // By Pace mode
      if (pace == null) {
        return '--';
      }
      return _formatPace(pace!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title
        Text(
          'WORKOUT DETAILS',
          style: AppTextStyles.sectionTitle.copyWith(
            fontSize: 14,
            letterSpacing: 1.5,
            color: isDark ? AppColors.cream : AppColors.blackberry,
          ),
        ),

        const SizedBox(height: AppSpacing.md),

        // Distance Input
        _DistanceInput(
          distance: distance,
          distanceUnit: distanceUnit,
          onChanged: onDistanceChanged,
          enabled: enabled,
          isDark: isDark,
        ),

        const SizedBox(height: AppSpacing.md),

        // Duration/Pace Toggle
        DurationPaceToggle(
          value: mode,
          onChanged: onModeChanged,
          sport: sport,
          enabled: enabled,
        ),

        const SizedBox(height: AppSpacing.md),

        // Estimated Duration or Pace Field
        _SecondaryField(
          label: _secondaryFieldLabel,
          value: _secondaryFieldValue,
          unit: mode == DurationPaceMode.byPace ? paceUnit : null,
          isDark: isDark,
          enabled: enabled,
          isEditable: true,
          onChanged: mode == DurationPaceMode.byPace ? onPaceChanged : null,
          onDurationChanged: mode == DurationPaceMode.byDuration ? onDurationChanged : null,
          isDurationMode: mode == DurationPaceMode.byDuration,
        ),
      ],
    );
  }
}

/// Distance input field with unit display
class _DistanceInput extends StatefulWidget {
  const _DistanceInput({
    required this.distance,
    required this.distanceUnit,
    required this.onChanged,
    required this.enabled,
    required this.isDark,
  });

  final double distance;
  final String distanceUnit;
  final ValueChanged<double> onChanged;
  final bool enabled;
  final bool isDark;

  @override
  State<_DistanceInput> createState() => _DistanceInputState();
}

class _DistanceInputState extends State<_DistanceInput> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.distance.toStringAsFixed(1));
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(_DistanceInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.distance != widget.distance && !_focusNode.hasFocus) {
      _controller.text = widget.distance.toStringAsFixed(1);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final value = double.tryParse(_controller.text);
    if (value != null && value > 0) {
      widget.onChanged(value);
    } else {
      // Revert to previous value
      _controller.text = widget.distance.toStringAsFixed(1);
    }
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: 'Distance ',
                style: AppTextStyles.bodySmall.copyWith(
                  color: widget.isDark ? AppColors.cream : AppColors.blackberry,
                  fontWeight: FontWeight.w400,
                ),
              ),
              TextSpan(
                text: '*',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.orange, // Amber/orange asterisk
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? AppColors.inputBackground
                      : AppColors.cream.withValues(alpha: 0.5),
                  borderRadius: AppRadius.inputRadius,
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: widget.enabled,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.done,
                  textAlign: TextAlign.left,
                  style: AppTextStyles.inputText.copyWith(
                    color: widget.isDark ? AppColors.cream : AppColors.blackberry,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  onSubmitted: (_) => _handleSubmit(),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              widget.distanceUnit.toLowerCase(),
              style: AppTextStyles.bodySmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Secondary field for estimated duration or pace
class _SecondaryField extends StatefulWidget {
  const _SecondaryField({
    required this.label,
    required this.value,
    this.unit,
    required this.isDark,
    required this.enabled,
    required this.isEditable,
    this.onChanged,
    this.onDurationChanged,
    this.isDurationMode = false,
  });

  final String label;
  final String value;
  final String? unit;
  final bool isDark;
  final bool enabled;
  final bool isEditable;
  final ValueChanged<double>? onChanged;
  final ValueChanged<Duration>? onDurationChanged;
  final bool isDurationMode;

  @override
  State<_SecondaryField> createState() => _SecondaryFieldState();
}

class _SecondaryFieldState extends State<_SecondaryField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(_SecondaryField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_focusNode.hasFocus) {
      _controller.text = widget.value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (!widget.isEditable) return;

    final text = _controller.text.trim();

    if (widget.isDurationMode && widget.onDurationChanged != null) {
      // Parse duration format: "H:MM", "MM min", or just minutes
      Duration? duration;

      if (text.contains(':')) {
        final parts = text.split(':');
        if (parts.length == 2) {
          final hours = int.tryParse(parts[0]);
          final minutes = int.tryParse(parts[1]);
          if (hours != null && minutes != null) {
            duration = Duration(hours: hours, minutes: minutes);
          }
        }
      } else {
        // Try parsing as plain minutes (strip "min" suffix if present)
        final cleanText = text.replaceAll(RegExp(r'[^0-9.]'), '');
        final minutes = double.tryParse(cleanText);
        if (minutes != null && minutes > 0) {
          duration = Duration(minutes: minutes.floor());
        }
      }

      if (duration != null && duration.inMinutes > 0) {
        widget.onDurationChanged!(duration);
      } else {
        _controller.text = widget.value;
      }
    } else if (widget.onChanged != null) {
      // Parse pace format (min:sec or decimal)
      double? paceValue;

      if (text.contains(':')) {
        final parts = text.split(':');
        if (parts.length == 2) {
          final minutes = int.tryParse(parts[0]);
          final seconds = int.tryParse(parts[1]);
          if (minutes != null && seconds != null) {
            paceValue = minutes + (seconds / 60.0);
          }
        }
      } else {
        paceValue = double.tryParse(text);
      }

      if (paceValue != null && paceValue > 0) {
        widget.onChanged!(paceValue);
      } else {
        _controller.text = widget.value;
      }
    }

    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: AppTextStyles.bodySmall.copyWith(
            color: widget.isDark ? AppColors.cream : AppColors.blackberry,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 46,
                decoration: BoxDecoration(
                  color: widget.isDark
                      ? AppColors.inputBackground
                      : AppColors.cream.withValues(alpha: 0.5),
                  borderRadius: AppRadius.inputRadius,
                ),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: widget.enabled && widget.isEditable,
                  keyboardType: widget.isEditable
                      ? const TextInputType.numberWithOptions(decimal: true)
                      : null,
                  textInputAction: TextInputAction.done,
                  textAlign: TextAlign.left,
                  style: AppTextStyles.inputText.copyWith(
                    color: widget.isDark ? AppColors.cream : AppColors.blackberry,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                  ),
                  inputFormatters: widget.isEditable
                      ? [
                          FilteringTextInputFormatter.allow(RegExp(r'^\d*:?\d*\.?\d*')),
                        ]
                      : null,
                  onSubmitted: (_) => _handleSubmit(),
                ),
              ),
            ),
            if (widget.unit != null) ...[
              const SizedBox(width: AppSpacing.sm),
              Text(
                widget.unit!.toLowerCase(),
                style: AppTextStyles.bodySmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
