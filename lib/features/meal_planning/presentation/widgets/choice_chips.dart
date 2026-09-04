import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart' show AppSpacing;
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../domain/vana_part.dart';
import 'choice_chip_button.dart';

/// `choices` part — an optional question plus 2–4 options. Tapping an
/// option sends its label as the next user message (02 §3).
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
