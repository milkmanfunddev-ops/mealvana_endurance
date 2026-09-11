import 'package:flutter/material.dart';

import 'package:mealvana_endurance/shared/widgets/kyle_design/buttons/primary_button.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/buttons/secondary_button.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/sheets/kyle_sheet_header.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_text_styles.dart';

/// Design SSOT component — **TP write-back consent sheet** (opt-out notice).
///
/// Spec: `docs/ssot/spec/design/surfaces/integrations-data-display.md` D-3
/// (RATIFIED Xuan 2026-09-11; Q-INT16 AMENDED to opt-out — sharing defaults
/// ON). Rendering:
/// `docs/ssot/spec/design/renderings/tp-writeback-consent@v1.html` (the
/// opt-out iteration — the only ratified one). Goldens:
/// `docs/ssot/conformance/design/tp-writeback-consent.goldens.yaml`.
///
/// Contracts held here:
/// * This is a NOTICE, not a consent gate: sharing is already ON when it
///   appears. Dismiss (X / scrim) leaves sharing ON — the footer says so.
/// * Fires after every successful TP connect, and exactly ONCE on first
///   launch for athletes who were already pushing before the amendment
///   (notice-once semantics, DI-10).
/// * "Turn Off Sharing" must be FULLY visible without scrolling on the
///   smallest supported screen (ratified layout constraint — the export
///   artboards clipped it), so the sheet is a fixed column, never a
///   scrollable.
/// * The EXAMPLE block quotes the amended TP-5 register: carbs g/hr,
///   water ml/hr, sodium mg/hr.
class TpWritebackConsentSheet extends StatelessWidget {
  const TpWritebackConsentSheet({super.key});

  /// Shows the sheet. Resolves `true` for Keep Sharing, `false` for
  /// Turn Off Sharing, and `null` for any dismiss (X, scrim) — which the
  /// caller must treat as KEEP ON (the ratified dismiss semantics).
  static Future<bool?> show(BuildContext context) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const TpWritebackConsentSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cardLine = AppColors.cream.withValues(alpha: 0.12);
    return SafeArea(
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.blackberry,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Grabber (rendering: 40x4 rounded bar, centered)
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: cardLine,
                ),
              ),
            ),
            const SizedBox(height: 14),
            KyleSheetHeader(
              title: 'Your fuel plan goes to your coach',
              onClose: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 8),
            Text(
              'Mealvana writes your plan to each TrainingPeaks workout so '
              'your coach can review it. You can turn it off here or in '
              'Settings.',
              style: TextStyle(
                fontFamily: AppTextStyles.apercu,
                fontSize: 15,
                height: 1.4,
                color: AppColors.cream.withValues(alpha: 0.8),
              ),
            ),
            const SizedBox(height: 16),
            // EXAMPLE preview block
            Container(
              key: const ValueKey('tp_writeback_consent.example'),
              decoration: BoxDecoration(
                color: AppColors.blackberryDark,
                border: Border.all(color: cardLine),
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'EXAMPLE',
                    style: TextStyle(
                      fontFamily: AppTextStyles.apercu,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                      color: AppColors.cream.withValues(alpha: 0.45),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Fuel plan · Mealvana',
                    style: TextStyle(
                      fontFamily: AppTextStyles.apercu,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.cream,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '60 g carbs/hr · 500 ml/hr · 400 mg sodium/hr',
                    style: TextStyle(
                      fontFamily: AppTextStyles.apercu,
                      fontSize: 14,
                      color: AppColors.cream.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Keep Sharing (filled) + Turn Off Sharing (equal-size outline).
            KylePrimaryButton(
              key: const ValueKey('tp_writeback_consent.keep_sharing'),
              text: 'Keep Sharing',
              onPressed: () => Navigator.of(context).pop(true),
            ),
            const SizedBox(height: 10),
            KyleSecondaryButton(
              key: const ValueKey('tp_writeback_consent.turn_off'),
              text: 'Turn Off Sharing',
              onPressed: () => Navigator.of(context).pop(false),
            ),
            const SizedBox(height: 12),
            Center(
              child: Text(
                'Closing this leaves sharing on.',
                style: TextStyle(
                  fontFamily: AppTextStyles.apercu,
                  fontSize: 12,
                  color: AppColors.cream.withValues(alpha: 0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
