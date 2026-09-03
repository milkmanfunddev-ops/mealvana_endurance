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
/// * **CF-1** — −/+ in 15-min steps; label `N HOUR[S] M MIN`; the MAXIMUM is
///   the ruled clamp `min(table cap 240, time-until-start)` (passed in as
///   [maxMinutes]) — values above it are unreachable, not disabled-but-
///   visible. Persistence of a manual change (`preRunMinutesManuallySet`)
///   is the owning controller's contract.
/// * **CF-2** — when the clamp binds, the control opens AT the clamp and
///   stepping up is inert (the + affordance disables): the athlete sees the
///   real ceiling, never a window implying a feeding in the past.
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

  /// Test-key prefix — `<prefix>_minus` / `<prefix>_value` / `<prefix>_plus`.
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

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final canIncrement = minutes + FuelingWindowLimits.stepMinutes <=
        maxMinutes;
    final canDecrement = minutes - FuelingWindowLimits.stepMinutes >=
        FuelingWindowLimits.minMinutes;

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
                  ? () =>
                      onChanged(minutes - FuelingWindowLimits.stepMinutes)
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
                  ? () =>
                      onChanged(minutes + FuelingWindowLimits.stepMinutes)
                  : null,
            ),
          ],
        ),
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
    final borderColor =
        enabled ? AppColors.orange : AppColors.orange.withValues(alpha: 0.4);

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
