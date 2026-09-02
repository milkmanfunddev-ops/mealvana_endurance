import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../domain/vana_part.dart';

/// Inline card shown in chat right after `confirm_plan` / a
/// `shopping_list` part: item count, a note about skipped items, and a link
/// to the Shopping tab (05 §3).
class ConfirmedCard extends ConsumerWidget {
  const ConfirmedCard({super.key, required this.part, required this.onView});

  final VanaShoppingListPart part;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.electrolyte : AppColors.electrolyteDark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final secondary = textColor.withValues(alpha: 0.65);

    return Container(
      key: const ValueKey('meal_planning.confirmed_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        border: Border.all(color: accent.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FaIcon(FontAwesomeIcons.circleCheck, color: accent, size: 18),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: Text(
                  ContentKeys.format(
                    content.getValue(ContentKeys.mpShoppingItemCount),
                    {'n': part.itemCount},
                  ),
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (part.skipped.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              ContentKeys.format(content.getValue(ContentKeys.mpShoppingAddBack), {
                'items': part.skipped.join(', '),
              }),
              style: AppTextStyles.bodySmall.copyWith(color: secondary),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          GestureDetector(
            onTap: onView,
            child: Text(
              content.getValue(ContentKeys.mpReviewShoppingLink),
              style: AppTextStyles.bodySmall.copyWith(
                color: accent,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
