import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mealvana_endurance/shared/domain/activity_type.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/inputs/duration_pace_toggle.dart'
    show DurationPaceMode;
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_spacing.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_text_styles.dart';

/// Workout Details Widget
///
/// CF-6 (RULED Xuan, 2026-09-03) — spec:
/// docs/ssot/spec/design/surfaces/create-flow-fueling-controls.md, reference
/// rendering prototypes/create-activity-plan/v1.html.
///
/// Distance on top; below it the pace ⇄ duration dual-field row. There is no
/// By Duration / By Pace toggle — BOTH fields are always visible. One side is
/// HELD (the side the athlete last edited: solid border, pin glyph) and the
/// other DERIVED (dashed border, italic dimmed text, `EST.` badge). Editing a
/// side — or tapping into a derived field — makes it the held side (reported
/// via [onModeChanged]); the derived value always renders live from the held
/// one through the controller linkage ([estimatedDuration] / [pace] props).
///
/// The `your usual · <pace>` chip below the pace field applies the athlete's
/// usual pace ([usualPace], falling back to the ruled sport base — run
/// 9:00 /mi). When distance > 0 and the effective pace sits outside the ruled
/// sport band, the derived side turns dragonfruit and a guard line plus a
/// tappable "Use your usual … → …" fix renders below the row (closes the
/// F-27 4:30/mi class).
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
    this.usualPace,
    this.enabled = true,
  });

  final ActivityType sport;
  final double distance;
  final String distanceUnit;

  /// Which side is HELD: [DurationPaceMode.byPace] holds pace (duration is
  /// derived), [DurationPaceMode.byDuration] holds duration (pace derived).
  final DurationPaceMode mode;
  final Duration? estimatedDuration;
  final double? pace;
  final String paceUnit;
  final ValueChanged<double> onDistanceChanged;
  final ValueChanged<DurationPaceMode> onModeChanged;
  final ValueChanged<double> onPaceChanged;
  final ValueChanged<Duration>? onDurationChanged;

  /// CF-6: the athlete's saved usual pace/speed in sport units (min/mi,
  /// mph, min/100m). Null falls back to the ruled sport base below.
  final double? usualPace;
  final bool enabled;

  // --- CF-6 sport table (prototype `details()` — exact values) -------------
  // run:  base 540 s/mi  (9:00 /mi), band [270, 900] s
  // bike: base 14.0 mph,             band [8, 30] mph
  // swim: base 120 s/100m (2:00),    band [60, 210] s
  bool get _isSpeed => sport == ActivityType.cycling;

  double get _sportBasePace {
    switch (sport) {
      case ActivityType.cycling:
        return 14.0; // mph
      case ActivityType.swimming:
        return 2.0; // 120 s per 100m, in minutes
      default:
        return 9.0; // 540 s per mile, in minutes — the ruled run fallback
    }
  }

  /// Band in sport units (minutes for paces, mph for speed).
  (double, double) get _sportBand {
    switch (sport) {
      case ActivityType.cycling:
        return (8.0, 30.0);
      case ActivityType.swimming:
        return (1.0, 3.5); // [60, 210] s per 100m
      default:
        return (4.5, 15.0); // [270, 900] s per mile
    }
  }

  String get _sportWord {
    switch (sport) {
      case ActivityType.cycling:
        return 'ride';
      case ActivityType.swimming:
        return 'swim';
      default:
        return 'run';
    }
  }

  double get _usual => usualPace ?? _sportBasePace;

  /// Trailing unit for the pace pill and chip (`/mi`, `mph`, `/100m`, …).
  String get _unitLabel {
    final u = paceUnit.toLowerCase();
    if (u.contains('100m')) return '/100m';
    if (u.contains('km/h') || u.contains('kph')) return 'km/h';
    if (u == 'mph') return 'mph';
    if (u.contains('km')) return '/km';
    return '/mi';
  }

  static const double _kmPerMile = 1.609344;

  /// The effective pace converted into the band's units (the ruled table is
  /// imperial), so a metric athlete gets the same guard.
  double? get _paceInBandUnits {
    final p = pace;
    if (p == null || p <= 0) return null;
    final u = paceUnit.toLowerCase();
    if (u.contains('km/h') || u.contains('kph')) return p / _kmPerMile;
    if (u.contains('km')) return p * _kmPerMile;
    return p;
  }

  /// F-27 guard: distance entered and the pace/speed sits at-or-outside the
  /// sport band (the ruled example, 4:30 /mi, IS the run band edge — the
  /// bounds themselves trigger).
  bool get _guardActive {
    final p = _paceInBandUnits;
    if (distance <= 0 || p == null) return false;
    final (lo, hi) = _sportBand;
    return p <= lo || p >= hi;
  }

  String _formatPaceValue(double value) {
    if (_isSpeed) return value.toStringAsFixed(1);
    var mins = value.floor();
    var secs = ((value - mins) * 60).round();
    if (secs == 60) {
      mins += 1;
      secs = 0;
    }
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  /// Session duration at the usual pace for the current distance.
  Duration get _durationAtUsual {
    final double minutes;
    switch (sport) {
      case ActivityType.cycling:
        minutes = _usual > 0 ? (distance / _usual) * 60 : 0;
      case ActivityType.swimming:
        minutes = (distance / 100) * _usual;
      default:
        minutes = distance * _usual;
    }
    return Duration(minutes: minutes.round());
  }

  static String _formatHrMin(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h == 0) return '$m min';
    return '$h hr $m min';
  }

  void _applyUsual() {
    if (mode != DurationPaceMode.byPace) {
      onModeChanged(DurationPaceMode.byPace);
    }
    onPaceChanged(_usual);
  }

  /// Flip the hold to [side] (tap into / edit of a derived field).
  void _activate(DurationPaceMode side) {
    if (mode != side) onModeChanged(side);
  }

  /// The visible `your usual · 9:00 /mi ✏️` pill — visuals only; the tap
  /// surface wrapping it in [build] is what handles the gesture.
  Widget _buildUsualPacePill(bool isDark) {
    final chipColor =
        isDark ? AppColors.electrolyte : AppColors.electrolyteDark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.electrolyte.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.electrolyte.withValues(alpha: 0.6),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'your usual · ${_formatPaceValue(_usual)} $_unitLabel',
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.smallLabel.copyWith(
              fontSize: 11,
              color: chipColor,
            ),
          ),
          const SizedBox(width: 4),
          Icon(Icons.edit, size: 10, color: chipColor),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final paceHeld = mode == DurationPaceMode.byPace;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Title
        Text(
          key: const ValueKey('activity_create.details_heading'),
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
          key: const ValueKey('activity_create.distance_field'),
          distance: distance,
          distanceUnit: distanceUnit,
          onChanged: onDistanceChanged,
          enabled: enabled,
          isDark: isDark,
        ),

        const SizedBox(height: AppSpacing.md),

        // CF-6 dual-field row: pace on the left, duration on the right, both
        // always visible; the derived side wears the dashed/EST. treatment.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _PaceHalf(
                label: _isSpeed ? 'Avg Speed' : 'Avg Pace',
                pace: pace,
                isSpeed: _isSpeed,
                unitLabel: _unitLabel,
                held: paceHeld,
                guardActive: !paceHeld && _guardActive,
                enabled: enabled,
                onPaceChanged: onPaceChanged,
                onActivate: () => _activate(DurationPaceMode.byPace),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _DurationHalf(
                duration: estimatedDuration,
                held: !paceHeld,
                guardActive: paceHeld && _guardActive,
                enabled: enabled && onDurationChanged != null,
                onDurationChanged: onDurationChanged,
                onActivate: () => _activate(DurationPaceMode.byDuration),
              ),
            ),
          ],
        ),

        // `your usual · 9:00 /mi` chip — tapping ANYWHERE on it applies the
        // usual pace. The pill itself is ~21px tall, so the gesture surface
        // is opaque and vertically padded out to a ≥44px hit target (the
        // extra area is invisible; it replaces the old 8px gaps above/below,
        // so the pill barely moves) — bug 2026-09-04: on device only precise
        // taps (aimed at the pencil) landed inside the bare pill.
        Align(
          alignment: Alignment.centerLeft,
          child: GestureDetector(
            key: const ValueKey('activity_create.usual_pace_chip'),
            behavior: HitTestBehavior.opaque,
            onTap: enabled ? _applyUsual : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildUsualPacePill(isDark),
                ],
              ),
            ),
          ),
        ),
        // F-27 guard: absurd pace called out honestly, with a one-tap fix.
        if (_guardActive && pace != null) ...[
          Column(
            key: const ValueKey('activity_create.pace_guard'),
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "That's ${_formatPaceValue(pace!)} $_unitLabel — "
                'outside your $_sportWord range.',
                style: AppTextStyles.smallLabel.copyWith(
                  fontSize: 11,
                  color: AppColors.dragonfruit,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              GestureDetector(
                key: const ValueKey('activity_create.pace_guard_fix'),
                onTap: enabled ? _applyUsual : null,
                child: Text(
                  'Use your usual ${_formatPaceValue(_usual)} $_unitLabel '
                  '→ ${_formatHrMin(_durationAtUsual)}',
                  style: AppTextStyles.smallLabel.copyWith(
                    fontSize: 11,
                    color: isDark
                        ? AppColors.electrolyte
                        : AppColors.electrolyteDark,
                    fontWeight: FontWeight.w700,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

// =============================================================================
// CF-6 linked-field internals
// =============================================================================

/// Label row for one half of the dual-field block: the held side carries the
/// pin glyph, the derived side the `EST.` badge.
class _LinkedFieldLabel extends StatelessWidget {
  const _LinkedFieldLabel({required this.text, required this.held});

  final String text;
  final bool held;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Flexible(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.cream,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        const SizedBox(width: 4),
        if (held)
          Icon(
            Icons.push_pin,
            size: 10,
            color: AppColors.cream.withValues(alpha: 0.7),
          )
        else
          Container(
            key: const ValueKey('activity_create.est_badge'),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: AppColors.cream.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: AppColors.cream.withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              'EST.',
              style: AppTextStyles.smallLabel.copyWith(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: AppColors.cream,
              ),
            ),
          ),
      ],
    );
  }
}

/// Pill shell for a linked field. HELD: solid inputBackground + solid cream
/// border. DERIVED: dimmed background + dashed cream border (dragonfruit
/// while the F-27 guard is active).
class _LinkedFieldShell extends StatelessWidget {
  const _LinkedFieldShell({
    required this.held,
    required this.guardActive,
    required this.child,
  });

  final bool held;
  final bool guardActive;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (held) {
      return Container(
        height: 46,
        decoration: BoxDecoration(
          color: AppColors.inputBackground,
          borderRadius: AppRadius.inputRadius,
          border: Border.all(
            color: AppColors.cream.withValues(alpha: 0.75),
          ),
        ),
        child: child,
      );
    }
    final borderColor = guardActive
        ? AppColors.dragonfruit
        : AppColors.cream.withValues(alpha: 0.45);
    // The dash outline must trace the same rounded shape as the fill —
    // mismatched radii read as a double border.
    final radius = AppRadius.inputRadius.topLeft.x;
    return CustomPaint(
      foregroundPainter: _DashedBorderPainter(color: borderColor, radius: radius),
      child: Container(
        height: 46,
        decoration: BoxDecoration(
          color: AppColors.inputBackground.withValues(alpha: 0.45),
          borderRadius: AppRadius.inputRadius,
        ),
        child: child,
      ),
    );
  }
}

/// Flutter has no native dashed border — a small rounded-rect dash painter.
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  static const double strokeWidth = 1.0;
  static const double dashLength = 5.0;
  static const double gapLength = 3.0;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(strokeWidth / 2);
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(
            distance,
            math.min(distance + dashLength, metric.length),
          ),
          paint,
        );
        distance += dashLength + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

TextStyle _linkedTextStyle({required bool held, required bool guardActive}) {
  if (held) {
    return AppTextStyles.inputText.copyWith(
      color: AppColors.cream,
      fontWeight: FontWeight.w400,
    );
  }
  return AppTextStyles.inputText.copyWith(
    color: guardActive
        ? AppColors.dragonfruit
        : AppColors.cream.withValues(alpha: 0.65),
    fontWeight: FontWeight.w400,
    fontStyle: FontStyle.italic,
  );
}

/// Colon-free `M:SS` entry (bug 2026-09-04): the iOS numeric keypad has no
/// ':' key, so the athlete types digits only and the formatter places the
/// colon before the last two — 9 3 0 → `9:30`, 1 0 4 5 → `10:45`. Pasted
/// `9:30` collapses to the same digits and reformats identically, so the
/// blur-parse (`_PaceHalfState._parse`) semantics are unchanged. Presentation
/// concern only — no pace math lives here.
class _MmSsInputFormatter extends TextInputFormatter {
  static final _nonDigit = RegExp(r'\D');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var digits = newValue.text.replaceAll(_nonDigit, '');
    // Backspacing over the colon alone would otherwise reformat straight
    // back to the same text; treat it as deleting the digit in front of it.
    if (newValue.text.length < oldValue.text.length &&
        digits == oldValue.text.replaceAll(_nonDigit, '') &&
        digits.isNotEmpty) {
      final colonIndex = oldValue.text.indexOf(':');
      if (colonIndex > 0) {
        digits = digits.replaceRange(colonIndex - 1, colonIndex, '');
      }
    }
    // 2-digit minutes + 2-digit seconds is the widest parseable pace.
    if (digits.length > 4) digits = digits.substring(0, 4);
    final String formatted;
    if (digits.length <= 2) {
      formatted = digits;
    } else {
      final split = digits.length - 2;
      formatted = '${digits.substring(0, split)}:${digits.substring(split)}';
    }
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Left half: `Avg Pace` (`Avg Speed` for cycling) — a single pill field with
/// the trailing unit. Run/swim render `M:SS`; bike a decimal speed.
class _PaceHalf extends StatefulWidget {
  const _PaceHalf({
    required this.label,
    required this.pace,
    required this.isSpeed,
    required this.unitLabel,
    required this.held,
    required this.guardActive,
    required this.enabled,
    required this.onPaceChanged,
    required this.onActivate,
  });

  final String label;
  final double? pace;
  final bool isSpeed;
  final String unitLabel;
  final bool held;
  final bool guardActive;
  final bool enabled;
  final ValueChanged<double> onPaceChanged;
  final VoidCallback onActivate;

  @override
  State<_PaceHalf> createState() => _PaceHalfState();
}

class _PaceHalfState extends State<_PaceHalf> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  bool _isSyncingText = false;
  // The controller also notifies on selection changes (focus); only treat an
  // actual text change as an edit.
  String _lastText = '';

  String _format(double? value) {
    if (value == null || value <= 0) return '';
    if (widget.isSpeed) return value.toStringAsFixed(1);
    var mins = value.floor();
    var secs = ((value - mins) * 60).round();
    if (secs == 60) {
      mins += 1;
      secs = 0;
    }
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  double? _parse(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;
    if (widget.isSpeed) {
      final v = double.tryParse(t);
      return (v != null && v > 0) ? v : null;
    }
    // `M:SS`, `M:` or a bare `M`.
    final match = RegExp(r'^(\d{1,2})(?::([0-5]?\d)?)?$').firstMatch(t);
    if (match == null) return null;
    final mins = int.parse(match.group(1)!);
    final secs = int.tryParse(match.group(2) ?? '') ?? 0;
    final value = mins + secs / 60.0;
    return value > 0 ? value : null;
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _format(widget.pace));
    _lastText = _controller.text;
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChange);
    _controller.addListener(_handleLiveChange);
  }

  @override
  void didUpdateWidget(_PaceHalf oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pace == widget.pace) return;
    // While the field has focus, a pace change is usually this field's own
    // live commit (typing "9" commits 9.0) — rewriting the text to "9:00"
    // mid-keystroke would clobber the entry. But an EXTERNAL set (the
    // `your usual` chip) must show through even when focused: if the current
    // text already parses to the new value it was our own commit, otherwise
    // the change came from outside and the display must follow it
    // (bug 2026-09-04: chip applied 9:00 while the field kept showing 7:45).
    if (_focusNode.hasFocus && _parse(_controller.text) == widget.pace) {
      return;
    }
    _isSyncingText = true;
    _controller.text = _format(widget.pace);
    _lastText = _controller.text;
    _isSyncingText = false;
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
    if (_focusNode.hasFocus) {
      // Tapping into a derived field flips it to held.
      if (!widget.held) widget.onActivate();
      return;
    }
    // On blur, revert unparseable text to the current value.
    if (_parse(_controller.text) == null) {
      _isSyncingText = true;
      _controller.text = _format(widget.pace);
      _lastText = _controller.text;
      _isSyncingText = false;
    }
  }

  void _handleLiveChange() {
    if (_isSyncingText || !widget.enabled) return;
    if (_controller.text == _lastText) return;
    _lastText = _controller.text;
    final value = _parse(_controller.text);
    if (value == null) return;
    if (!widget.held) widget.onActivate();
    widget.onPaceChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LinkedFieldLabel(text: widget.label, held: widget.held),
        const SizedBox(height: AppSpacing.xs),
        _LinkedFieldShell(
          held: widget.held,
          guardActive: widget.guardActive,
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('activity_create.pace_field'),
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: widget.enabled,
                  // iOS numeric keypads carry no ':' — mm:ss paces take a
                  // plain digits pad and let the formatter place the colon
                  // (bug 2026-09-04).
                  keyboardType: widget.isSpeed
                      ? const TextInputType.numberWithOptions(decimal: true)
                      : TextInputType.number,
                  textInputAction: TextInputAction.done,
                  textAlign: TextAlign.left,
                  style: _linkedTextStyle(
                    held: widget.held,
                    guardActive: widget.guardActive,
                  ),
                  decoration: InputDecoration(
                    // The shell draws the border; kill every themed border
                    // state or the theme's pill outline paints inside it.
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                    filled: false,
                    hintText: widget.isSpeed ? '0.0' : '0:00',
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.sm,
                    ),
                  ),
                  inputFormatters: [
                    if (widget.isSpeed)
                      FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
                    else
                      _MmSsInputFormatter(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: Text(
                  widget.unitLabel,
                  style: AppTextStyles.smallLabel.copyWith(
                    fontSize: 11,
                    color: AppColors.cream.withValues(alpha: 0.65),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Right half: `Duration` — two small pill fields, `hr` | `min`.
class _DurationHalf extends StatefulWidget {
  const _DurationHalf({
    required this.duration,
    required this.held,
    required this.guardActive,
    required this.enabled,
    required this.onDurationChanged,
    required this.onActivate,
  });

  final Duration? duration;
  final bool held;
  final bool guardActive;
  final bool enabled;
  final ValueChanged<Duration>? onDurationChanged;
  final VoidCallback onActivate;

  @override
  State<_DurationHalf> createState() => _DurationHalfState();
}

class _DurationHalfState extends State<_DurationHalf> {
  late final TextEditingController _hrController;
  late final TextEditingController _minController;
  late final FocusNode _hrFocus;
  late final FocusNode _minFocus;
  bool _isSyncingText = false;
  // The controllers also notify on selection changes (focus); only treat an
  // actual text change as an edit.
  String _lastHrText = '';
  String _lastMinText = '';

  @override
  void initState() {
    super.initState();
    _hrController = TextEditingController();
    _minController = TextEditingController();
    _hrFocus = FocusNode();
    _minFocus = FocusNode();
    _hrFocus.addListener(_handleFocusChange);
    _minFocus.addListener(_handleFocusChange);
    _hrController.addListener(_handleLiveChange);
    _minController.addListener(_handleLiveChange);
    _syncControllers();
  }

  @override
  void didUpdateWidget(_DurationHalf oldWidget) {
    super.didUpdateWidget(oldWidget);
    final hasFocus = _hrFocus.hasFocus || _minFocus.hasFocus;
    if (!hasFocus && oldWidget.duration != widget.duration) {
      _syncControllers();
    }
  }

  @override
  void dispose() {
    _hrFocus.removeListener(_handleFocusChange);
    _minFocus.removeListener(_handleFocusChange);
    _hrController.removeListener(_handleLiveChange);
    _minController.removeListener(_handleLiveChange);
    _hrController.dispose();
    _minController.dispose();
    _hrFocus.dispose();
    _minFocus.dispose();
    super.dispose();
  }

  void _syncControllers() {
    _isSyncingText = true;
    final d = widget.duration;
    _hrController.text = d != null ? d.inHours.toString() : '';
    _minController.text = d != null
        ? d.inMinutes.remainder(60).toString().padLeft(2, '0')
        : '';
    _lastHrText = _hrController.text;
    _lastMinText = _minController.text;
    _isSyncingText = false;
  }

  Duration? _parse() {
    final hrText = _hrController.text.trim();
    final minText = _minController.text.trim();
    final hours = hrText.isEmpty ? 0 : int.tryParse(hrText);
    final minutes = minText.isEmpty ? 0 : int.tryParse(minText);
    if (hours == null || minutes == null) return null;
    if (hours < 0 || minutes < 0 || minutes >= 60) return null;
    if (hours == 0 && minutes == 0) return null;
    return Duration(hours: hours, minutes: minutes);
  }

  void _handleFocusChange() {
    if (_hrFocus.hasFocus || _minFocus.hasFocus) {
      // Tapping into a derived field flips it to held.
      if (!widget.held) widget.onActivate();
      return;
    }
    if (_parse() == null) _syncControllers();
  }

  void _handleLiveChange() {
    if (_isSyncingText || !widget.enabled) return;
    if (_hrController.text == _lastHrText &&
        _minController.text == _lastMinText) {
      return;
    }
    _lastHrText = _hrController.text;
    _lastMinText = _minController.text;
    final parsed = _parse();
    if (parsed == null) return;
    if (!widget.held) widget.onActivate();
    widget.onDurationChanged?.call(parsed);
  }

  Widget _segmentField({
    required Key key,
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required TextInputAction action,
    int? maxLength,
  }) {
    return _LinkedFieldShell(
      held: widget.held,
      guardActive: widget.guardActive,
      child: TextField(
        key: key,
        controller: controller,
        focusNode: focusNode,
        enabled: widget.enabled,
        keyboardType: TextInputType.number,
        textInputAction: action,
        textAlign: TextAlign.left,
        style: _linkedTextStyle(
          held: widget.held,
          guardActive: widget.guardActive,
        ),
        decoration: InputDecoration(
          // The shell draws the border; kill every themed border state.
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          filled: false,
          hintText: hint,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xs,
            vertical: AppSpacing.sm,
          ),
        ),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          if (maxLength != null) LengthLimitingTextInputFormatter(maxLength),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final unitStyle = AppTextStyles.smallLabel.copyWith(
      fontSize: 11,
      color: AppColors.cream.withValues(alpha: 0.65),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LinkedFieldLabel(text: 'Duration', held: widget.held),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Expanded(
              child: _segmentField(
                key: const ValueKey('activity_create.duration_hr_field'),
                controller: _hrController,
                focusNode: _hrFocus,
                hint: '0',
                action: TextInputAction.next,
              ),
            ),
            const SizedBox(width: 4),
            Text('hr', style: unitStyle),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: _segmentField(
                key: const ValueKey('activity_create.duration_mins_field'),
                controller: _minController,
                focusNode: _minFocus,
                hint: '00',
                action: TextInputAction.done,
                maxLength: 2,
              ),
            ),
            const SizedBox(width: 4),
            Text('min', style: unitStyle),
          ],
        ),
      ],
    );
  }
}

// =============================================================================
// Distance input (unchanged behavior)
// =============================================================================

/// Distance input field with unit display
class _DistanceInput extends StatefulWidget {
  const _DistanceInput({
    super.key,
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
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.done,
                  textAlign: TextAlign.left,
                  style: AppTextStyles.inputText.copyWith(
                    color: widget.isDark
                        ? AppColors.cream
                        : AppColors.blackberry,
                    fontWeight: FontWeight.w600,
                  ),
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
