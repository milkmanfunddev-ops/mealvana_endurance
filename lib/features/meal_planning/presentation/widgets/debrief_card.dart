import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../domain/vana_part.dart';
import 'vana_tag.dart';

/// `debrief` part (plan Phase 3.3): "4 of 5 meals happened", the skip
/// reason when there was one, then the distilled memories as kind-tagged
/// rows — what Vana will carry into next week's first proposal. Drawn
/// locally; the celebration register lives in Vana's text, not here.
class DebriefCard extends ConsumerWidget {
  const DebriefCard({super.key, required this.part});

  final VanaDebriefPart part;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final secondary = textColor.withValues(alpha: 0.65);
    final surface = isDark ? AppColors.blackberryLight : AppColors.surfaceLight;

    return Container(
      key: const ValueKey('meal_planning.debrief_card'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: textColor.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ContentKeys.format(content.getValue(ContentKeys.mpDebriefLine), {
              'completed': part.completed,
              'planned': part.planned,
            }),
            key: const ValueKey('meal_planning.debrief_line'),
            style: AppTextStyles.sectionTitle.copyWith(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (part.skipReason case final reason? when reason.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              ContentKeys.format(
                content.getValue(ContentKeys.mpDebriefSkipReason),
                {'reason': reason},
              ),
              key: const ValueKey('meal_planning.debrief_skip_reason'),
              style: AppTextStyles.bodySmall.copyWith(color: secondary),
            ),
          ],
          if (part.memories.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              content.getValue(ContentKeys.mpDebriefRemembered).toUpperCase(),
              style: AppTextStyles.overline.copyWith(color: secondary),
            ),
            for (final memory in part.memories) ...[
              const SizedBox(height: AppSpacing.xs),
              Row(
                key: ValueKey('meal_planning.debrief_memory_${memory.id}'),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  VanaTag(label: memory.kind.wire),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      memory.fact,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: textColor,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}
