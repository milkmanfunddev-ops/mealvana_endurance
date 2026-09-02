import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../shared/widgets/kyle_design/feedback/mealvana_snackbar.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../application/vana_settings_controller.dart';
import '../../domain/user_memory.dart';

/// "What Vana knows" — the memory list with per-row delete (local-first
/// tombstone through [VanaSettingsController]). Used by the Vana settings
/// screen; title/body/labels resolve from content keys.
class MemoryDrawer extends ConsumerWidget {
  const MemoryDrawer({super.key, this.memories, this.onDelete});

  /// Optional override; defaults to the settings controller's list.
  final List<UserMemory>? memories;

  /// Optional delete hook; defaults to the settings controller.
  final ValueChanged<UserMemory>? onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final secondary = textColor.withValues(alpha: 0.65);
    final surface = isDark
        ? AppColors.blackberryLight
        : AppColors.surfaceLight;

    final list =
        memories ??
        ref.watch(vanaSettingsControllerProvider).value?.memories ??
        const <UserMemory>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          content.getValue(ContentKeys.mpSettingsMemories),
          style: AppTextStyles.sectionTitle.copyWith(color: textColor),
        ),
        Text(
          content.getValue(ContentKeys.mpSettingsMemoriesBody),
          style: AppTextStyles.bodySmall.copyWith(color: secondary),
        ),
        const SizedBox(height: AppSpacing.xs),
        if (list.isEmpty)
          Text(
            content.getValue(ContentKeys.mpConvEmpty),
            style: AppTextStyles.bodySmall.copyWith(color: secondary),
          )
        else
          for (final memory in list)
            Container(
              margin: const EdgeInsets.only(bottom: AppSpacing.xs),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(AppSpacing.xs),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      memory.fact,
                      style: AppTextStyles.bodySmall.copyWith(color: textColor),
                    ),
                  ),
                  GestureDetector(
                    key: ValueKey('meal_planning.memory_delete_${memory.id}'),
                    onTap: () {
                      if (onDelete != null) {
                        onDelete!(memory);
                        return;
                      }
                      ref
                          .read(vanaSettingsControllerProvider.notifier)
                          .deleteMemory(memory.id);
                      MealvanaSnackbar.showInfo(
                        context,
                        content.getValue(ContentKeys.mpMemoryDeletedToast),
                      );
                    },
                    child: Text(
                      content.getValue(ContentKeys.mpSettingsDeleteMemory),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.dragonfruit,
                      ),
                    ),
                  ),
                ],
              ),
            ),
      ],
    );
  }
}
