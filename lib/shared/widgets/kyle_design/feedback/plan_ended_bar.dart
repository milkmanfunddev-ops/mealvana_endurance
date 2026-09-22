import 'package:flutter/material.dart';

import 'package:mealvana_endurance/shared/widgets/kyle_design/buttons/primary_button.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_spacing.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_text_styles.dart';

/// Design SSOT component — **Plan Ended Bar**.
///
/// Spec: `docs/ssot/spec/design/components/plan-ended-bar.md` v1
/// (PROPOSED, authored app-side, awaiting Xuan). Decision: mp-457 §3 — a
/// lapsed account opens read-only, and every screen carries a bar saying the
/// plan has ended, with a Subscribe button.
///
/// Presentation only (PEB-1): the caller decides when it shows and what
/// Subscribe does, and passes the copy from the content system. It draws
/// the full-width strip at the top of the screen, running up under the
/// status bar (PEB-2), one line of copy and the Subscribe pill (PEB-3), in
/// the brand's dark surface whatever the theme (PEB-4).
class PlanEndedBar extends StatelessWidget {
  const PlanEndedBar({
    super.key,
    required this.message,
    required this.subscribeLabel,
    required this.onSubscribe,
    this.topInset = 0,
  });

  /// "Your plan has ended…" — from the content system.
  final String message;

  /// The button's label — from the content system.
  final String subscribeLabel;

  /// Opens the paywall.
  final VoidCallback onSubscribe;

  /// The status-bar height the strip runs up under; its content starts
  /// below it.
  final double topInset;

  /// The Subscribe pill's height (PEB-3).
  static const double buttonHeight = 36;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.blackberry,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.md,
          topInset + AppSpacing.xs,
          AppSpacing.xs,
          AppSpacing.xs,
        ),
        child: Row(
          children: [
            Expanded(
              child: Semantics(
                liveRegion: true,
                child: Text(
                  message,
                  key: const ValueKey('plan_ended_bar.message'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.cream,
                    height: 1.3,
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            KylePrimaryButton(
              key: const ValueKey('plan_ended_bar.subscribe'),
              text: subscribeLabel,
              onPressed: onSubscribe,
              isFullWidth: false,
              height: buttonHeight,
              fontSize: 14,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            ),
          ],
        ),
      ),
    );
  }
}
