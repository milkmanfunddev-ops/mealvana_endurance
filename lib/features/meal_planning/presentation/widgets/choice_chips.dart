import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart' show AppSpacing;
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../domain/vana_part.dart';
import 'choice_chip_button.dart';

/// `choices` part — an optional question plus 2–4 options. Tapping an
/// option hands its label to the screen: a label with one fixed meaning
/// (the batch-cooking and coverage answers, "Same as last time", "Open
/// shopping list", "Lay it across the week"; `VanaFixedChip`) acts at once
/// with no model turn (mp-464), and any other label is the next user
/// message (02 §3). The widget never knows which: the label is the whole
/// contract.
///
/// Always the compact [Wrap] of [ChoiceChipButton]s: the labels carry the
/// meaning on their own, and a trade-off `details` line (spec §2.3) is not
/// rendered — the server is asked for label-only options.
class ChoiceChips extends ConsumerWidget {
  const ChoiceChips({super.key, required this.part, required this.onTap});

  final VanaChoicesPart part;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (part.question != null && part.question!.isNotEmpty) ...[
          Text(
            part.question!,
            style: AppTextStyles.bodyMedium.copyWith(
              color: isDark ? AppColors.cream : AppColors.blackberry,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        Wrap(
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            for (final option in part.options)
              ChoiceChipButton(label: option, onTap: () => onTap(option)),
          ],
        ),
      ],
    );
  }
}
