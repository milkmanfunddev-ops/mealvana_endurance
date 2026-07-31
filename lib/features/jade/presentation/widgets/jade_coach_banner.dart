import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../shared/services/preferences_service.dart';
import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../providers/jade_banner_providers.dart';
import 'jade_avatar.dart';

/// Slim one-line banner that acts as Jade's persistent entry point on the
/// Nutrition Diary tab.
///
/// Layout:  [JadeAvatar(36)] | [eyebrow + copy, Expanded] | [chat-bubble icon]
///
/// Behaviour:
///   - Tapping anywhere opens `/jade`.
///   - When the user has no recent baseline logs, shows tutorial copy with an
///     optional × dismiss button.  Dismissal persists via [PreferencesService]
///     and the banner switches to the default copy (but never disappears).
///   - While [jadeHasBaselineProvider] is loading, the banner shows the
///     default copy (graceful degradation).
class JadeCoachBanner extends ConsumerWidget {
  const JadeCoachBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final contentService = ref.read(contentServiceProvider);
    final prefs = ref.watch(preferencesServiceProvider);

    // Resolve copy variant.
    final hasBaselineAsync = ref.watch(jadeHasBaselineProvider);
    // Treat loading and error as "has baseline" to show compact default copy.
    final hasBaseline = hasBaselineAsync.maybeWhen(
      data: (v) => v,
      orElse: () => true,
    );

    // Show tutorial variant only when: no baseline AND not yet dismissed.
    final showTutorial = !hasBaseline && !prefs.jadeBaselineTipDismissed;

    final copy = showTutorial
        ? contentService.getValue(
            'jade.banner_baseline_tip',
            defaultValue:
                'Log a few meals so I can learn your baseline — or just tell me what you eat.',
          )
        : contentService.getValue(
            'jade.banner_default',
            defaultValue: 'Tap to chat about your fueling.',
          );

    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final cardBg = isDark ? AppColors.blackberryLight : AppColors.cream;
    final borderColor = isDark
        ? AppColors.electrolyte.withValues(alpha: 0.18)
        : AppColors.electrolyte.withValues(alpha: 0.28);

    return BaseCard(
      key: const ValueKey('jade.coach_banner'),
      backgroundColor: cardBg,
      border: Border.all(color: borderColor, width: 1),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      onTap: () => context.push('/jade'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Avatar ────────────────────────────────────────────────────────
          const JadeAvatar(size: 36),
          const SizedBox(width: AppSpacing.sm),

          // ── Eyebrow + copy ────────────────────────────────────────────────
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'JADE · ENDURANCE COACH',
                  style: AppTextStyles.macroLabel.copyWith(
                    color: textColor.withValues(alpha: 0.5),
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  copy,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: textColor.withValues(alpha: 0.85),
                    fontSize: 13,
                    height: 1.3,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          const SizedBox(width: AppSpacing.xs),

          // ── Trailing: dismiss (tutorial only) or chat-bubble icon ─────────
          if (showTutorial)
            GestureDetector(
              key: const ValueKey('jade.banner_dismiss'),
              behavior: HitTestBehavior.opaque,
              onTap: () async {
                await ref
                    .read(preferencesServiceProvider)
                    .dismissJadeBaselineTip();
                // Force the banner to re-read preferences.
                ref.invalidate(preferencesServiceProvider);
              },
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.close,
                  size: 16,
                  color: textColor.withValues(alpha: 0.45),
                ),
              ),
            )
          else
            FaIcon(
              FontAwesomeIcons.commentDots,
              size: 16,
              color: AppColors.electrolyte.withValues(alpha: 0.85),
            ),
        ],
      ),
    );
  }
}
