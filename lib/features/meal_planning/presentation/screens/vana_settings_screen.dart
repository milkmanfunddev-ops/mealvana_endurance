import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../application/vana_settings_controller.dart';
import '../widgets/memory_drawer.dart';
import '../widgets/vana_round_button.dart';

/// `/settings/vana` (05 §4): the Meal planning switches — batch cooking,
/// show-macros (the two Vana can flip from inside a conversation) and the
/// device-local check-in/debrief reminders — over "What Vana knows".
class VanaSettingsScreen extends ConsumerWidget {
  const VanaSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final secondary = textColor.withValues(alpha: 0.6);
    final bg = isDark ? AppColors.blackberry : AppColors.cream;
    final surface = isDark ? AppColors.blackberryLight : AppColors.surfaceLight;
    final state = ref.watch(vanaSettingsControllerProvider).value;
    final controller = ref.read(vanaSettingsControllerProvider.notifier);
    final showMacros = state?.showMacros ?? true;

    return Scaffold(
      key: const ValueKey('meal_planning.vana_settings_screen'),
      backgroundColor: bg,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.xxl,
          ),
          children: [
            Row(
              children: [
                VanaRoundButton.back(
                  context: context,
                  onTap: () => context.pop(),
                ),
                const SizedBox(width: 12),
                Text(
                  content.getValue(ContentKeys.mpSettingsVanaTitle),
                  style: AppTextStyles.sectionTitle.copyWith(
                    color: textColor,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              content
                  .getValue(ContentKeys.mpSettingsSectionMealPlanning)
                  .toUpperCase(),
              style: AppTextStyles.overline.copyWith(color: secondary),
            ),
            const SizedBox(height: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                children: [
                  _SettingRow(
                    rowKey: const ValueKey('meal_planning.settings_batch'),
                    title: content.getValue(ContentKeys.mpSettingsBatch),
                    subtitle: content.getValue(ContentKeys.mpSettingsBatchSub),
                    value: state?.batchCooking ?? true,
                    onChanged: controller.setBatchCooking,
                    showDivider: true,
                  ),
                  _SettingRow(
                    rowKey: const ValueKey('meal_planning.settings_macros'),
                    title: content.getValue(ContentKeys.mpSettingsMacros),
                    // The subtitle says what "off" actually means, so the
                    // switch is not the only signal.
                    subtitle: content.getValue(
                      showMacros
                          ? ContentKeys.mpSettingsMacrosOn
                          : ContentKeys.mpSettingsMacrosOff,
                    ),
                    value: showMacros,
                    onChanged: controller.setShowMacros,
                    showDivider: true,
                  ),
                  _SettingRow(
                    rowKey: const ValueKey('meal_planning.settings_reminders'),
                    title: content.getValue(ContentKeys.mpSettingsReminders),
                    subtitle: content.getValue(
                      ContentKeys.mpSettingsRemindersSub,
                    ),
                    value: state?.remindersEnabled ?? false,
                    onChanged: controller.setRemindersEnabled,
                    showDivider: false,
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              content.getValue(ContentKeys.mpSettingsMemories).toUpperCase(),
              style: AppTextStyles.overline.copyWith(color: secondary),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              content.getValue(ContentKeys.mpSettingsMemoriesBody),
              style: AppTextStyles.bodySmall.copyWith(color: secondary),
            ),
            const SizedBox(height: AppSpacing.sm),
            MemoryDrawer(
              memories: state?.memories,
              onDelete: (memory) => controller.deleteMemory(memory.id),
            ),
          ],
        ),
      ),
    );
  }
}

/// One 56pt settings row: title over its explanation, with the switch on the
/// trailing edge.
class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.rowKey,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.showDivider,
  });

  final Key rowKey;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final secondary = textColor.withValues(alpha: 0.6);

    return Container(
      key: rowKey,
      height: 56,
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(color: textColor.withValues(alpha: 0.1)),
              )
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.foodTitle.copyWith(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(color: secondary),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.blackberry,
            activeTrackColor: AppColors.electrolyte,
          ),
        ],
      ),
    );
  }
}
