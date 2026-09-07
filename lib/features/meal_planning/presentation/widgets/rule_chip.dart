import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../domain/plan_rule.dart';
import '../../domain/vana_part.dart';

/// `rule` part — a proposed standing rule ("quiet Sundays — lighter
/// dinner"). Renders as a chip with the rule text; accepting is routed by
/// the chat screen through `accept_rule`.
class RuleChip extends ConsumerWidget {
  const RuleChip({super.key, required this.part, required this.onAccept});

  final VanaRulePart part;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.electrolyte : AppColors.electrolyteDark;
    final secondary = (isDark ? AppColors.cream : AppColors.blackberry)
        .withValues(alpha: 0.65);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.sm),
        border: Border.all(color: accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              part.rule.rule,
              style: AppTextStyles.bodySmall.copyWith(color: secondary),
            ),
          ),
          if (!part.rule.accepted) ...[
            const SizedBox(width: AppSpacing.xs),
            GestureDetector(
              onTap: onAccept,
              child: Text(
                '✓',
                style: AppTextStyles.bodySmall.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Day label for a [PlanRuleDay] — used by the chat screen when it accepts
/// a rule and needs to show what it remembered.
String planRuleDayLabel(PlanRuleDay day) => switch (day) {
  PlanRuleDay.mon => 'Mon',
  PlanRuleDay.tue => 'Tue',
  PlanRuleDay.wed => 'Wed',
  PlanRuleDay.thu => 'Thu',
  PlanRuleDay.fri => 'Fri',
  PlanRuleDay.sat => 'Sat',
  PlanRuleDay.sun => 'Sun',
};
