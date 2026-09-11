import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/services/preferences_service.dart';
import '../../../../shared/widgets/kyle_design/inputs/kyle_switch.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';

/// D-3 settings row (integrations-data-display.md, RATIFIED Xuan
/// 2026-09-11; goldens: tp-writeback-consent.goldens.yaml rows
/// `tp-row-toggle-on` / `premium-blocked`):
/// * bare toggle labeled "Write fuel plan to TrainingPeaks", PRE-SET ON
///   (opt-out default — Q-INT16 as amended);
/// * premium-blocked shows the ratified copy + Re-check and NO dead toggle.
/// Extracted from ConnectedAppsScreen so the golden suite renders the
/// exact row the screen composes.
class TpWritebackToggleRow extends ConsumerWidget {
  const TpWritebackToggleRow({super.key, required this.onRecheck});

  final VoidCallback onRecheck;

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    final prefs = ref.watch(preferencesServiceProvider);
    final enabled = prefs.tpWritebackEnabled;
    final premiumBlocked = prefs.tpWritebackPremiumBlocked;
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final onSurfaceVariant = Theme.of(context).colorScheme.onSurfaceVariant;

    // D-3 (integrations-data-display.md, RATIFIED 2026-09-11): bare toggle
    // with the ratified label (sublabel struck 2026-09-11); premium-blocked
    // shows the ratified copy + Re-check and NO dead toggle.
    if (premiumBlocked) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Unavailable for your TrainingPeaks plan. Your coach sees '
                'nothing from Mealvana until TrainingPeaks allows it.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            GestureDetector(
              key: const ValueKey('connected_apps.tp_writeback_recheck'),
              onTap: onRecheck,
              child: Text(
                'Re-check',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.dragonfruit,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Write fuel plan to TrainingPeaks',
              style: AppTextStyles.bodyMedium.copyWith(color: onSurface),
            ),
          ),
          KyleSwitch(
            key: const ValueKey('connected_apps.tp_writeback_toggle'),
            value: enabled,
            onChanged: (value) async {
              await prefs.setTpWritebackEnabled(value);
              // Force rebuild by invalidating the provider
              ref.invalidate(preferencesServiceProvider);
            },
            activeTrackColor: AppColors.success,
          ),
        ],
      ),
    );
    }
}
