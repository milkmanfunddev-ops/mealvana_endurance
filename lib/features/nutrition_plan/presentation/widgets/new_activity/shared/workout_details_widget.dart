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

  static Duration _paceMinutesToDuration(double paceMinutes) {
    final totalSeconds = (paceMinutes * 60).round();
    return Duration(seconds: totalSeconds);
  }

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final useSplitDurationInput = mode == DurationPaceMode.byDuration;
    final useSplitPaceInput =
        mode == DurationPaceMode.byPace && sport != ActivityType.cycling;
    final paceDuration = pace != null && pace! > 0
        ? WorkoutDetailsWidget._paceMinutesToDuration(pace!)
        : null;

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
        if (useSplitDurationInput)
          _DualSegmentField(
            label: _secondaryFieldLabel,
            firstLabel: 'hr',
            secondLabel: 'mins',
            firstHint: '0',
            secondHint: '00',
            firstValue: estimatedDuration?.inHours,
            secondValue: estimatedDuration?.inMinutes.remainder(60),
            isDark: isDark,
            enabled: enabled,
            onChanged: onDurationChanged == null
                ? null
                : (hours, minutes) {
                    onDurationChanged!(
                      Duration(hours: hours, minutes: minutes),
                    );
                  },
          )
        else if (useSplitPaceInput)
          _DualSegmentField(
            label: _secondaryFieldLabel,
            firstLabel: 'min',
            secondLabel: 'sec',
            firstHint: '0',
            secondHint: '00',
            firstValue: paceDuration?.inMinutes,
            secondValue: paceDuration?.inSeconds.remainder(60),
            trailingUnit: paceUnit,
            isDark: isDark,
            enabled: enabled,
            onChanged: (minutes, seconds) {
              onPaceChanged(minutes + (seconds / 60.0));
            },
          )
        else
          _SingleValueField(
            label: _secondaryFieldLabel,
            value: pace?.toStringAsFixed(1) ?? '',
            unit: paceUnit,
            isDark: isDark,
            enabled: enabled,
            onChanged: onPaceChanged,
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
  bool _isSyncingText = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.distance.toStringAsFixed(1),
    );
    _focusNode = FocusNode();
    _controller.addListener(_handleLiveChange);
  }

  @override
  void didUpdateWidget(_DistanceInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.distance != widget.distance && !_focusNode.hasFocus) {
      _isSyncingText = true;
      _controller.text = widget.distance.toStringAsFixed(1);
      _isSyncingText = false;
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleLiveChange);
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

  void _handleLiveChange() {
    if (_isSyncingText) return;
    final value = double.tryParse(_controller.text);
    if (value != null && value > 0) {
      widget.onChanged(value);
    }
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
              child: _InputShell(
                isDark: widget.isDark,
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: widget.enabled,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.done,
                  textAlign: TextAlign.left,
                  style: _inputTextStyle(widget.isDark),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
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

/// Single value input used for cycling speed entry (mph/kph).
class _SingleValueField extends StatefulWidget {
  const _SingleValueField({
    required this.label,
    required this.value,
    this.unit,
    required this.isDark,
    required this.enabled,
    this.onChanged,
  });

  final String label;
  final String value;
  final String? unit;
  final bool isDark;
  final bool enabled;
  final ValueChanged<double>? onChanged;

  @override
  State<_SingleValueField> createState() => _SingleValueFieldState();
}

class _SingleValueFieldState extends State<_SingleValueField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _isSyncingText = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChange);
    _controller.addListener(_handleLiveChange);
  }

  @override
  void didUpdateWidget(_SingleValueField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value && !_focusNode.hasFocus) {
      _isSyncingText = true;
      _controller.text = widget.value;
      _isSyncingText = false;
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _controller.removeListener(_handleLiveChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (!_focusNode.hasFocus) {
      _handleSubmit();
    }
  }

  void _handleSubmit() {
    final text = _controller.text.trim();
    final value = double.tryParse(text);
    if (value != null && value > 0 && widget.onChanged != null) {
      widget.onChanged!(value);
    } else {
      _controller.text = widget.value;
    }

    _focusNode.unfocus();
  }

  void _handleLiveChange() {
    if (_isSyncingText) return;
    final value = double.tryParse(_controller.text.trim());
    if (value != null && value > 0 && widget.onChanged != null) {
      widget.onChanged!(value);
    }
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
              child: _InputShell(
                isDark: widget.isDark,
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: widget.enabled && widget.onChanged != null,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.done,
                  textAlign: TextAlign.left,
                  style: _inputTextStyle(widget.isDark),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
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

/// Reusable two-field input row for `hr/mins` and `min/sec` patterns.
class _DualSegmentField extends StatefulWidget {
  const _DualSegmentField({
    required this.label,
    required this.firstLabel,
    required this.secondLabel,
    required this.firstHint,
    required this.secondHint,
    required this.firstValue,
    required this.secondValue,
    required this.isDark,
    required this.enabled,
    this.trailingUnit,
    this.onChanged,
  });

  final String label;
  final String firstLabel;
  final String secondLabel;
  final String firstHint;
  final String secondHint;
  final int? firstValue;
  final int? secondValue;
  final String? trailingUnit;
  final bool isDark;
  final bool enabled;
  final void Function(int first, int second)? onChanged;

  @override
  State<_DualSegmentField> createState() => _DualSegmentFieldState();
}

class _DualSegmentFieldState extends State<_DualSegmentField> {
  late TextEditingController _firstController;
  late TextEditingController _secondController;
  late FocusNode _firstFocus;
  late FocusNode _secondFocus;
  bool _isSyncingText = false;

  @override
  void initState() {
    super.initState();
    _firstController = TextEditingController();
    _secondController = TextEditingController();
    _firstFocus = FocusNode();
    _secondFocus = FocusNode();
    _firstFocus.addListener(_handleFocusChange);
    _secondFocus.addListener(_handleFocusChange);
    _firstController.addListener(_handleLiveChange);
    _secondController.addListener(_handleLiveChange);
    _syncControllers(
      firstValue: widget.firstValue,
      secondValue: widget.secondValue,
    );
  }

  @override
  void didUpdateWidget(_DualSegmentField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final hasFocus = _firstFocus.hasFocus || _secondFocus.hasFocus;
    if (!hasFocus &&
        (oldWidget.firstValue != widget.firstValue ||
            oldWidget.secondValue != widget.secondValue)) {
      _syncControllers(
        firstValue: widget.firstValue,
        secondValue: widget.secondValue,
      );
    }
  }

  @override
  void dispose() {
    _firstFocus.removeListener(_handleFocusChange);
    _secondFocus.removeListener(_handleFocusChange);
    _firstController.removeListener(_handleLiveChange);
    _secondController.removeListener(_handleLiveChange);
    _firstController.dispose();
    _secondController.dispose();
    _firstFocus.dispose();
    _secondFocus.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (_firstFocus.hasFocus || _secondFocus.hasFocus) return;
    _handleSubmit();
  }

  void _syncControllers({required int? firstValue, required int? secondValue}) {
    _isSyncingText = true;
    _firstController.text = firstValue?.toString() ?? '';
    _secondController.text = secondValue != null
        ? secondValue.toString().padLeft(2, '0')
        : '';
    _isSyncingText = false;
  }

  ({int first, int second})? _parseSegments({required bool requireNonZero}) {
    final firstText = _firstController.text.trim();
    final secondText = _secondController.text.trim();
    final firstValue = firstText.isEmpty ? 0 : int.tryParse(firstText);
    final secondValue = secondText.isEmpty ? 0 : int.tryParse(secondText);

    if (firstValue == null || secondValue == null) {
      return null;
    }

    final isInvalid =
        firstValue < 0 ||
        secondValue < 0 ||
        secondValue >= 60 ||
        (requireNonZero && firstValue == 0 && secondValue == 0);

    if (isInvalid) {
      return null;
    }

    return (first: firstValue, second: secondValue);
  }

  void _handleLiveChange() {
    if (_isSyncingText) return;
    if (!widget.enabled || widget.onChanged == null) {
      return;
    }

    final parsed = _parseSegments(requireNonZero: true);
    if (parsed == null) {
      return;
    }

    widget.onChanged!(parsed.first, parsed.second);
  }

  void _handleSubmit() {
    if (!widget.enabled || widget.onChanged == null) {
      return;
    }

    final parsed = _parseSegments(requireNonZero: true);
    if (parsed == null) {
      _syncControllers(
        firstValue: widget.firstValue,
        secondValue: widget.secondValue,
      );
      return;
    }

    widget.onChanged!(parsed.first, parsed.second);
    _firstFocus.unfocus();
    _secondFocus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              widget.label,
              style: AppTextStyles.bodySmall.copyWith(
                color: widget.isDark ? AppColors.cream : AppColors.blackberry,
                fontWeight: FontWeight.w400,
              ),
            ),
            if (widget.trailingUnit != null) ...[
              const SizedBox(width: AppSpacing.xs),
              Text(
                '(${widget.trailingUnit!.toLowerCase()})',
                style: AppTextStyles.bodySmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: _InputShell(
                isDark: widget.isDark,
                child: TextField(
                  controller: _firstController,
                  focusNode: _firstFocus,
                  enabled: widget.enabled && widget.onChanged != null,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  textAlign: TextAlign.left,
                  style: _inputTextStyle(widget.isDark),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: widget.firstHint,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                  ),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onSubmitted: (_) => _secondFocus.requestFocus(),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              widget.firstLabel,
              style: AppTextStyles.bodySmall.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _InputShell(
                isDark: widget.isDark,
                child: TextField(
                  controller: _secondController,
                  focusNode: _secondFocus,
                  enabled: widget.enabled && widget.onChanged != null,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  textAlign: TextAlign.left,
                  style: _inputTextStyle(widget.isDark),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: widget.secondHint,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.sm,
                    ),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(2),
                  ],
                  onSubmitted: (_) => _handleSubmit(),
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              widget.secondLabel,
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

class _InputShell extends StatelessWidget {
  const _InputShell({required this.isDark, required this.child});

  final bool isDark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.inputBackground
            : AppColors.cream.withValues(alpha: 0.5),
        borderRadius: AppRadius.inputRadius,
      ),
      child: child,
    );
  }
}

TextStyle _inputTextStyle(bool isDark) {
  return AppTextStyles.inputText.copyWith(
    color: isDark ? AppColors.cream : AppColors.blackberry,
    fontWeight: FontWeight.w600,
  );
}
