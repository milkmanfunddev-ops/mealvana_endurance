import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../application/cooking_session_controller.dart';

/// One parsed cooking timer: label, live countdown, start/pause and reset
/// (02 §7 `findDurations` output). Ringing state is styled, not sounded —
/// the screen owns notification + vibration.
class TimerChip extends ConsumerWidget {
  const TimerChip({
    super.key,
    required this.state,
    required this.onToggle,
    required this.onReset,
  });

  final StepTimerState state;
  final VoidCallback onToggle;
  final VoidCallback onReset;

  String get _label {
    final m = state.remainingSeconds ~/ 60;
    final s = state.remainingSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final accent = state.rang
        ? AppColors.dragonfruit
        : state.running
        ? AppColors.electrolyte
        : AppColors.orange;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(100),
        border: state.rang ? Border.all(color: accent, width: 1.5) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${state.timer.label} · $_label',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: accent,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          _IconBtn(
            icon: FaIcon(
              state.running ? FontAwesomeIcons.pause : FontAwesomeIcons.play,
              size: 13,
            ),
            tooltip: state.running
                ? content.getValue(ContentKeys.mpCookTimerPause)
                : content.getValue(ContentKeys.mpCookTimerStart),
            onPressed: onToggle,
          ),
          _IconBtn(
            icon: const FaIcon(FontAwesomeIcons.arrowRotateLeft, size: 13),
            tooltip: content.getValue(ContentKeys.mpCookTimerReset),
            onPressed: onReset,
          ),
        ],
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  const _IconBtn({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final Widget icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
      padding: EdgeInsets.zero,
      icon: icon,
    );
  }
}
