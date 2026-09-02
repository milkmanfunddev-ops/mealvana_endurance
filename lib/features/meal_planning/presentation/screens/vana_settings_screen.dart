import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../application/vana_settings_controller.dart';
import '../widgets/memory_drawer.dart';

/// `/settings/vana` (05 §4): Batch cooking + Show macros switches and the
/// "What Vana knows" memory list with delete. Linked from the Settings hub.
class VanaSettingsScreen extends ConsumerWidget {
  const VanaSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final secondary = textColor.withValues(alpha: 0.65);
    final bg = isDark ? AppColors.blackberry : AppColors.cream;
    final state = ref.watch(vanaSettingsControllerProvider).value;

    return Scaffold(
      key: const ValueKey('meal_planning.vana_settings_screen'),
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: textColor),
        title: Text(
          content.getValue(ContentKeys.mpSettingsVanaTitle),
          style: AppTextStyles.sectionTitle.copyWith(color: textColor),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            SwitchListTile(
              key: const ValueKey('meal_planning.settings_batch'),
              value: state?.batchCooking ?? true,
              onChanged: (value) => ref
                  .read(vanaSettingsControllerProvider.notifier)
                  .setBatchCooking(value),
              title: Text(
                content.getValue(ContentKeys.mpSettingsBatch),
                style: AppTextStyles.bodyMedium.copyWith(color: textColor),
              ),
              subtitle: Text(
                content.getValue(ContentKeys.mpSettingsBatchSub),
                style: AppTextStyles.bodySmall.copyWith(color: secondary),
              ),
              activeThumbColor: AppColors.electrolyte,
            ),
            SwitchListTile(
              key: const ValueKey('meal_planning.settings_macros'),
              value: state?.showMacros ?? false,
              onChanged: (value) => ref
                  .read(vanaSettingsControllerProvider.notifier)
                  .setShowMacros(value),
              title: Text(
                content.getValue(ContentKeys.mpSettingsMacros),
                style: AppTextStyles.bodyMedium.copyWith(color: textColor),
              ),
              subtitle: Text(
                content.getValue(ContentKeys.mpSettingsMacrosSub),
                style: AppTextStyles.bodySmall.copyWith(color: secondary),
              ),
              activeThumbColor: AppColors.electrolyte,
            ),
            const SizedBox(height: AppSpacing.md),
            MemoryDrawer(
              memories: state?.memories,
              onDelete: (memory) => ref
                  .read(vanaSettingsControllerProvider.notifier)
                  .deleteMemory(memory.id),
            ),
          ],
        ),
      ),
    );
  }
}
