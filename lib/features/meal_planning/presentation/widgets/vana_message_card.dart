import 'package:flutter/material.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../domain/vana_message.dart';
import 'part_entrance.dart';
import 'vana_avatar.dart';
import 'vana_bubble.dart';
import 'vana_part_renderer.dart';

/// One chat turn. User turns are right-aligned bubbles (with the "Edit"
/// affordance when [onEdit] is given); assistant turns are the Vana avatar
/// plus a text block (text first — planning parts order below prose, 05
/// §4) with each part through [VanaPartRenderer]. While streaming with no
/// prose yet, a typing indicator shows **even if parts have already
/// arrived** — [PartEntrance] holds them back until the prose lands (or
/// the stream ends), then cascades them in; the `status` line renders
/// under the prose when passed.
class VanaMessageCard extends StatelessWidget {
  const VanaMessageCard({
    super.key,
    required this.message,
    required this.callbacks,
    this.index = 0,
    this.isStreaming = false,
    this.statusTool,
    this.editLabel,
    this.onEdit,
  });

  final VanaMessage message;
  final VanaPartCallbacks callbacks;

  /// Position in the transcript — keys the edit affordance.
  final int index;
  final bool isStreaming;

  /// Resolved "Edit" copy and the rewind entry point for athlete turns
  /// (plan §5 Phase 6.1). Pass null to hide the affordance (streaming).
  final String? editLabel;
  final void Function(String messageId, String text)? onEdit;

  /// Resolved status copy for the active tool from the `status` stream line
  /// ("Finding meals that fit your week…").
  final String? statusTool;

  @override
  Widget build(BuildContext context) {
    if (message.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: VanaUserBubble(
          text: message.content,
          editLabel: editLabel,
          editKey: ValueKey('meal_planning.edit_message_$index'),
          onEdit: onEdit == null
              ? null
              : () => onEdit!(message.id, message.content),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final secondary = textColor.withValues(alpha: 0.65);
    final hasContent = message.content.isNotEmpty;
    final hasParts = message.parts.isNotEmpty;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xxs),
          child: VanaAvatar(size: 28, isPulsing: isStreaming),
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isStreaming && !hasContent)
                VanaBubble(child: _TypingDots(color: secondary))
              else if (hasContent) ...[
                VanaBubble(
                  squareBottomLeft: hasParts,
                  child: SelectableText(
                    message.content,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: textColor,
                      height: 1.6,
                    ),
                  ),
                ),
                if (isStreaming && statusTool != null) ...[
                  const SizedBox(height: 4),
                  // The S20 pattern: a mini pulsing avatar beside the named
                  // status ("Finding meals that fit your week…").
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const VanaAvatar(size: 16, isPulsing: true),
                      const SizedBox(width: AppSpacing.xxs),
                      Flexible(
                        child: Text(
                          statusTool!,
                          key: const ValueKey('meal_planning.status_line'),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: secondary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
              // Parts wait for the prose (or the end of the stream) before
              // they cascade in — see [PartEntrance].
              if (hasParts)
                PartEntrance(
                  show: hasContent || !isStreaming,
                  children: [
                    for (final part in message.parts)
                      VanaPartRenderer(part: part, callbacks: callbacks),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots({required this.color});

  final Color color;

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _controller,
          builder: (_, __) {
            final progress = (_controller.value - i * 0.2).clamp(0.0, 1.0);
            final alpha = (0.3 + 0.7 * (1.0 - (2 * (progress - 0.5)).abs()))
                .clamp(0.3, 1.0);
            return Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withValues(alpha: alpha),
              ),
            );
          },
        );
      }),
    );
  }
}
