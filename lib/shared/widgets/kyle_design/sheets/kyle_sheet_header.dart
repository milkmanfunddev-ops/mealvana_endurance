import 'package:flutter/material.dart';

import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_text_styles.dart';

/// Design SSOT component — **Sheet Header** (title row + dismiss X).
///
/// Extracted as a library component per the data-integrations handoff's
/// component-reuse rule (Xuan, 2026-09-11): the ratified renderings compose
/// `MealvanaDS.SheetHeader`; the Flutter side mirrors that composition with
/// ONE header widget rather than per-sheet copies. First consumer: the TP
/// write-back consent sheet (`tp-writeback-consent@v1`). Proposed for a
/// `spec/design/components/sheet-header.md` stub — registered here so the
/// next sheet reuses it instead of inventing a parallel header.
///
/// The X is named for a screen reader with the platform's localized "Close"
/// (testing-wave 08-002: VoiceOver read it as a bare "button").
class KyleSheetHeader extends StatelessWidget {
  const KyleSheetHeader({super.key, required this.title, this.onClose});

  final String title;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontFamily: AppTextStyles.apercu,
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.cream,
            ),
          ),
        ),
        if (onClose != null)
          IconButton(
            key: const ValueKey('kyle_sheet_header.close'),
            onPressed: onClose,
            icon: Icon(
              Icons.close,
              semanticLabel: MaterialLocalizations.of(
                context,
              ).closeButtonTooltip,
              color: AppColors.cream.withValues(alpha: 0.7),
              size: 22,
            ),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }
}
