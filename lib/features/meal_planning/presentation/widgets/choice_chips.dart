import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart' show AppRadius, AppSpacing;
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../domain/vana_part.dart';

/// `choices` part — an optional question plus 2–3 option chips. Tapping a
/// chip sends its label as the next user message (02 §3).
class ChoiceChips extends ConsumerWidget {
  const ChoiceChips({super.key, required this.part, required this.onTap});

  final VanaChoicesPart part;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.electrolyte : AppColors.electrolyteDark;

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
              _ChoiceChip(label: option, accent: accent, onTap: () => onTap(option)),
          ],
        ),
      ],
    );
  }
}

class _ChoiceChip extends StatelessWidget {
  const _ChoiceChip({
    required this.label,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          border: Border.all(color: accent.withValues(alpha: 0.7)),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          color: accent.withValues(alpha: 0.1),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: accent,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
