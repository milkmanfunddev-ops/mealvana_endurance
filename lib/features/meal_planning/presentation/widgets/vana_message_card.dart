import 'package:flutter/material.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../domain/vana_message.dart';
import 'vana_avatar.dart';
import 'vana_part_renderer.dart';

/// One chat turn. User turns are right-aligned bubbles; assistant turns
/// are the Vana avatar plus a text block (text first — planning parts order
/// below prose, 05 §4) with each part through [VanaPartRenderer]. While
/// streaming with no content yet, a typing indicator shows; the `status`
/// line renders under the prose when passed.
class VanaMessageCard extends StatelessWidget {
  const VanaMessageCard({
    super.key,
    required this.message,
    required this.callbacks,
    this.isStreaming = false,
    this.statusTool,
  });

  final VanaMessage message;
  final VanaPartCallbacks callbacks;
  final bool isStreaming;

  /// Active tool name from the `status` stream line ("Finding options…").
  final String? statusTool;

  @override
  Widget build(BuildContext context) {
    if (message.isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
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
            message.content,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.blackberry,
              height: 1.5,
            ),
          ),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final secondary = textColor.withValues(alpha: 0.65);
    final bubbleBg = isDark
        ? AppColors.blackberryLight
        : AppColors.surfaceLight;
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
              if (isStreaming && !hasContent && !hasParts)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: bubbleBg,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(AppSpacing.xxs),
                      topRight: Radius.circular(AppSpacing.lg),
                      bottomLeft: Radius.circular(AppSpacing.lg),
                      bottomRight: Radius.circular(AppSpacing.lg),
                    ),
                  ),
                  child: _TypingDots(color: secondary),
                )
              else if (hasContent) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: bubbleBg,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(AppSpacing.xxs),
                      topRight: const Radius.circular(AppSpacing.lg),
                      bottomLeft: Radius.circular(
                        hasParts ? AppSpacing.xxs : AppSpacing.lg,
                      ),
                      bottomRight: const Radius.circular(AppSpacing.lg),
                    ),
                  ),
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
                  Text(
                    statusTool!,
                    key: const ValueKey('meal_planning.status_line'),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: secondary,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
              if (hasParts) ...[
                const SizedBox(height: AppSpacing.xs),
                for (final part in message.parts) ...[
                  VanaPartRenderer(part: part, callbacks: callbacks),
                  const SizedBox(height: AppSpacing.xs),
                ],
              ],
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
