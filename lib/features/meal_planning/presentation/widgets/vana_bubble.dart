import 'package:flutter/material.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';

/// Vana's chat bubble — the raised surface with a squared-off top-left
/// corner that marks a turn as hers (prototype `.k-bubble-ai`). Used for
/// every assistant turn and for the "ask Vana instead" prompts that borrow
/// the same shape outside the conversation.
class VanaBubble extends StatelessWidget {
  const VanaBubble({
    super.key,
    this.text,
    this.child,
    this.squareBottomLeft = false,
    this.compact = false,
  }) : assert(
         text != null || child != null,
         'give the bubble something to say',
       );

  /// Plain text content. Ignored when [child] is given.
  final String? text;
  final Widget? child;

  /// Square off the bottom-left corner too — used when parts hang below the
  /// bubble and should read as one block.
  final bool squareBottomLeft;

  /// Tighter padding and 13pt text, for the bubble used as a call to action.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final bg = isDark ? AppColors.blackberryLight : AppColors.surfaceLight;

    return Container(
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
          : const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(AppSpacing.xxs),
          topRight: const Radius.circular(AppSpacing.lg),
          bottomLeft: Radius.circular(
            squareBottomLeft ? AppSpacing.xxs : AppSpacing.lg,
          ),
          bottomRight: const Radius.circular(AppSpacing.lg),
        ),
      ),
      child:
          child ??
          Text(
            text!,
            style: TextStyle(
              fontSize: compact ? 13 : 14,
              height: 1.6,
              color: textColor,
            ),
          ),
    );
  }
}

/// The athlete's bubble — right-aligned on electrolyte with a squared-off
/// bottom-right corner (prototype `.k-bubble-user`), plus the tertiary
/// "Edit" affordance beneath it (plan §5 Phase 6.1). [onEdit] is null
/// while a turn is streaming or the host cannot rewind, and the affordance
/// then does not render; [editLabel] is the resolved content string.
class VanaUserBubble extends StatelessWidget {
  const VanaUserBubble({
    super.key,
    required this.text,
    this.editLabel,
    this.onEdit,
    this.editKey,
  });

  final String text;
  final String? editLabel;
  final VoidCallback? onEdit;

  /// Key for the edit affordance (`meal_planning.edit_message_<index>`).
  final Key? editKey;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = (isDark ? AppColors.cream : AppColors.blackberry).withValues(
      alpha: 0.55,
    );
    final showEdit = onEdit != null && editLabel != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          constraints: const BoxConstraints(maxWidth: 320),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: const BoxDecoration(
            color: AppColors.electrolyte,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(AppSpacing.lg),
              topRight: Radius.circular(AppSpacing.lg),
              bottomLeft: Radius.circular(AppSpacing.lg),
              bottomRight: Radius.circular(AppSpacing.xxs),
            ),
          ),
          child: SelectableText(
            text,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.blackberry,
              height: 1.5,
            ),
          ),
        ),
        if (showEdit)
          // A text-only tertiary: tall enough to hit, quiet enough to skip.
          InkWell(
            key: editKey,
            onTap: onEdit,
            borderRadius: BorderRadius.circular(AppSpacing.sm),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                AppSpacing.xxs,
                AppSpacing.xxs,
                AppSpacing.xxs,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit_outlined, size: 13, color: muted),
                  const SizedBox(width: AppSpacing.xxs),
                  Text(
                    editLabel!,
                    style: AppTextStyles.bodySmall.copyWith(color: muted),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
