import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../domain/ai_coach_ui_part.dart';
import '../providers/ai_coach_chat_controller.dart';

// ---------------------------------------------------------------------------
// AiCoachChoiceButtons
// ---------------------------------------------------------------------------

/// Renders a [AiCoachChoicesPart] as a question label + tappable option buttons.
///
/// Tapping an option sends the option text as the user's next message via
/// [AiCoachChatController.send] and marks this group as answered (disabling all
/// buttons for the remainder of the session).
///
/// When loaded from history (after app restart or conversation reload) the
/// buttons render in their default enabled appearance — tapping one simply
/// sends the text again as a new message, which is harmless and lets the
/// user revisit a choice if they want to change course.
class AiCoachChoiceButtons extends ConsumerStatefulWidget {
  const AiCoachChoiceButtons({super.key, required this.part});

  final AiCoachChoicesPart part;

  @override
  ConsumerState<AiCoachChoiceButtons> createState() =>
      _AiCoachChoiceButtonsState();
}

class _AiCoachChoiceButtonsState extends ConsumerState<AiCoachChoiceButtons> {
  /// Which option index was tapped (null = not yet answered this session).
  int? _answeredIndex;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final isStreaming = ref.watch(
      aiCoachChatControllerProvider.select(
        (s) => s.value?.isStreaming ?? false,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Question label
        Text(
          widget.part.question,
          style: AppTextStyles.bodyMedium.copyWith(
            color: textColor.withValues(alpha: 0.85),
            height: 1.5,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),

        // Option buttons — wrap so they reflow on narrow screens
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: List.generate(widget.part.options.length, (index) {
            final option = widget.part.options[index];
            final isAnswered = _answeredIndex != null;
            final isThisAnswer = _answeredIndex == index;

            // Disable all buttons while Mealvana AI is streaming a reply or after
            // the user has already answered this session.
            final isEnabled = !isStreaming && !isAnswered;

            return _ChoiceButton(
              label: option,
              isEnabled: isEnabled,
              isSelected: isThisAnswer,
              isDark: isDark,
              onTap: () => _onOptionTapped(index, option),
            );
          }),
        ),
      ],
    );
  }

  void _onOptionTapped(int index, String option) {
    if (_answeredIndex != null) return; // already answered this session

    setState(() {
      _answeredIndex = index;
    });

    ref.read(aiCoachChatControllerProvider.notifier).send(option);
  }
}

// ---------------------------------------------------------------------------
// _ChoiceButton
// ---------------------------------------------------------------------------

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.label,
    required this.isEnabled,
    required this.isSelected,
    required this.isDark,
    required this.onTap,
  });

  final String label;
  final bool isEnabled;
  final bool isSelected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Visual states:
    //   selected  — electrolyte fill, blackberry text (confirms the pick)
    //   enabled   — electrolyte border, electrolyte-tinted text
    //   disabled  — faint border, muted text
    final Color borderColor;
    final Color bgColor;
    final Color labelColor;

    if (isSelected) {
      borderColor = AppColors.electrolyte;
      bgColor = AppColors.electrolyte;
      labelColor = AppColors.blackberry;
    } else if (isEnabled) {
      borderColor = AppColors.electrolyte.withValues(alpha: 0.6);
      bgColor = AppColors.electrolyte.withValues(alpha: isDark ? 0.1 : 0.07);
      labelColor = isDark ? AppColors.electrolyte : AppColors.electrolyteDark;
    } else {
      // Not selected and not enabled (either streaming or sibling was picked)
      borderColor = isDark
          ? AppColors.cream.withValues(alpha: 0.15)
          : AppColors.blackberry.withValues(alpha: 0.1);
      bgColor = Colors.transparent;
      labelColor = isDark
          ? AppColors.cream.withValues(alpha: 0.3)
          : AppColors.blackberry.withValues(alpha: 0.3);
    }

    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppRadius.circular),
          border: Border.all(color: borderColor, width: 1),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: labelColor,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
