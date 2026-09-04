/// Design SSOT component — **Fueling Window Control** (the pre-workout
/// window stepper).
///
/// Spec: `docs/ssot/spec/design/surfaces/create-flow-fueling-controls.md`
/// **v1** (RATIFIED Xuan, 2026-09-03). Math authority:
/// `docs/ssot/spec/fueling/food-recommendation.md` §3/§3a (table default +
/// early-start + clamp) — the DEFAULT value this control opens at is the
/// controllers' §3a derivation (`fueling_window_authority.dart`), never
/// computed here.
///
/// Contracts held here:
/// * **CF-1** — −/+ walk the 15-min GRID (00/15/30/45 anchors — RULED Xuan,
///   2026-09-03: a clamp-seeded off-grid value snaps onto the grid on the
///   first step, it does not propagate its offset); label `N HOUR[S] M MIN`;
///   the MAXIMUM is the ruled clamp `min(table cap 240, time-until-start)`
///   (passed in as [maxMinutes]) — values above it are unreachable, and the
///   ceiling itself IS reachable from below even when off-grid (it is the
///   real one, CF-2). Persistence of a manual change
///   (`preRunMinutesManuallySet`) is the owning controller's contract.
/// * **CF-2** — when the clamp binds, the control opens AT the clamp and
///   stepping up is inert (the + affordance disables): the athlete sees the
///   real ceiling, never a window implying a feeding in the past. The
///   clamp-bound state carries its explanation via [caption]
///   ("Capped: session in …" — RULED Xuan, 2026-09-03; copy provisional
///   pending the D-02 artboard).
/// * **Q-CF1** — the class caption ("3 h — long session") renders under the
///   stepper while the value is the §3a default; text supplied by the
///   owning controller (`fuelingWindowCaption`), never derived here.
/// * **CF-5** (surface's copy register) — the [label] is sport-dynamic
///   (`Pre-Run` / `Pre-Ride` / `Pre-Swim` / `Pre-Activity`), supplied by the
///   mounting tab.
///
/// Promoted from the running tab's private `_TimeBeforeRunControl`
/// (food-recommendation@v1): the four sports previously split between that
/// bespoke control and a raw-minutes `KylePlusMinusControl` — one component
/// now carries the contract for all four mounts.
library;

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../features/nutrition_plan/domain/fueling_window_limits.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';

// (Visual language carried verbatim from the running tab's original control:
// AppSizes.controlSize outline buttons in AppColors.orange, cream in dark.)

class FuelingWindowControl extends StatelessWidget {
  const FuelingWindowControl({
    super.key,
    required this.label,
    required this.minutes,
    required this.maxMinutes,
    required this.onChanged,
    this.caption,
    this.keyPrefix = 'activity_create.fueling_window',
  });

  /// Sport-dynamic header (CF-5): e.g. `Pre-Run Fueling Window`.
  final String label;

  /// Current window in minutes.
  final int minutes;

  /// The ruled clamp: `min(240, max(15, minutes-until-start))` (CF-1/CF-2),
  /// computed by the owning controller.
  final int maxMinutes;

  final ValueChanged<int> onChanged;

  /// Q-CF1 class caption / CF-2 clamp explanation, from the owning
  /// controller's `fuelingWindowCaption`; hidden when null.
  final String? caption;

  /// Test-key prefix — `<prefix>_minus` / `<prefix>_value` / `<prefix>_plus`
  /// / `<prefix>_caption`.
  final String keyPrefix;

  /// CF-1 label: `N HOUR[S] M MIN` (minutes-only below the hour).
  static String formatWindow(int minutes) {
    if (minutes == 0) return '0 MINUTES';
    if (minutes < 60) return '$minutes MINUTES';
    final hours = minutes ~/ 60;
    final remaining = minutes % 60;
    final hourWord = hours == 1 ? 'HOUR' : 'HOURS';
    if (remaining == 0) return '$hours $hourWord';
    return '$hours $hourWord $remaining MIN';
  }

  /// Largest 15-min grid value strictly below [m] (CF-1 grid rule): a
  /// clamp-seeded 63 steps to 60, not 48.
  static int _snapDown(int m) {
    final snapped =
        ((m - 1) ~/ FuelingWindowLimits.stepMinutes) *
        FuelingWindowLimits.stepMinutes;
    return snapped < FuelingWindowLimits.minMinutes
        ? FuelingWindowLimits.minMinutes
        : snapped;
  }

  /// Smallest 15-min grid value strictly above [m], capped at [maxMinutes]:
  /// the off-grid ceiling stays reachable (it is the real one, CF-2).
  int _snapUp(int m) {
    final next =
        (m ~/ FuelingWindowLimits.stepMinutes + 1) *
        FuelingWindowLimits.stepMinutes;
    return next > maxMinutes ? maxMinutes : next;
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final canIncrement = minutes < maxMinutes;
    final canDecrement = minutes > FuelingWindowLimits.minMinutes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.descriptor.copyWith(
            color: onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _StepButton(
              key: ValueKey('${keyPrefix}_minus'),
              icon: FontAwesomeIcons.minus.data,
              enabled: canDecrement,
              onPressed: canDecrement
                  ? () => onChanged(_snapDown(minutes))
                  : null,
            ),
            const SizedBox(width: AppSpacing.xl),
            Expanded(
              child: Text(
                key: ValueKey('${keyPrefix}_value'),
                formatWindow(minutes),
                style: AppTextStyles.dataNumber.copyWith(
                  color: onSurface,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(width: AppSpacing.xl),
            // CF-2: inert at the clamp — disabled, no phantom headroom.
            _StepButton(
              key: ValueKey('${keyPrefix}_plus'),
              icon: FontAwesomeIcons.plus.data,
              enabled: canIncrement,
              onPressed: canIncrement
                  ? () => onChanged(_snapUp(minutes))
                  : null,
            ),
          ],
        ),
        if (caption != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Center(
            child: Text(
              key: ValueKey('${keyPrefix}_caption'),
              caption!,
              style: AppTextStyles.descriptor.copyWith(
                color: onSurface.withValues(alpha: 0.65),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    super.key,
    required this.icon,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final enabledIconColor = isDark ? AppColors.cream : AppColors.orange;
    final disabledIconColor = enabledIconColor.withValues(alpha: 0.4);
    final borderColor = enabled
        ? AppColors.orange
        : AppColors.orange.withValues(alpha: 0.4);

    return SizedBox(
      width: AppSizes.controlSize,
      height: AppSizes.controlSize,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          elevation: 0,
          shadowColor: Colors.transparent,
          side: BorderSide(color: borderColor, width: 2),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.circularRadius),
          padding: EdgeInsets.zero,
        ),
        child: Icon(
          icon,
          size: AppIconSizes.controlIcon,
          color: enabled ? enabledIconColor : disabledIconColor,
        ),
      ),
    );
  }
}
