import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../shared/widgets/kyle_design/feedback/mealvana_snackbar.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../application/vana_settings_controller.dart';
import '../../domain/user_memory.dart';
import 'dashed_box.dart';
import 'vana_tag.dart';

/// "What Vana knows" — the memory list: each row is the memory's kind as a
/// tag, the fact and when it was last confirmed, and a delete (a local-first
/// tombstone through [VanaSettingsController]). The section label and body
/// belong to the settings screen; this is the card.
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

    if (list.isEmpty) {
      return DashedBox(
        child: Text(
          content.getValue(ContentKeys.mpSettingsMemoriesEmpty),
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(color: secondary),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          for (final (i, memory) in list.indexed)
            DecoratedBox(
              decoration: BoxDecoration(
                border: i == list.length - 1
                    ? null
                    : Border(
                        bottom: BorderSide(
                          color: textColor.withValues(alpha: 0.1),
                        ),
                      ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      VanaTag(label: memory.kind.wire),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              memory.fact,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: textColor,
                              ),
                            ),
                            Text(
                              provenanceLine(content, memory),
                              key: ValueKey(
                                'meal_planning.memory_provenance_${memory.id}',
                              ),
                              style: AppTextStyles.bodySmall.copyWith(
                                color: secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        key: ValueKey(
                          'meal_planning.memory_delete_${memory.id}',
                        ),
                        tooltip: content.getValue(
                          ContentKeys.mpSettingsDeleteMemory,
                        ),
                        onPressed: () {
                          if (onDelete != null) {
                            onDelete!(memory);
                            return;
                          }
                          ref
                              .read(vanaSettingsControllerProvider.notifier)
                              .deleteMemory(memory.id);
                          MealvanaSnackbar.showInfo(
                            context,
                            content.getValue(
                              ContentKeys.mpMemoryDeletedToast,
                            ),
                          );
                        },
                        icon: const FaIcon(
                          FontAwesomeIcons.trash,
                          size: 16,
                          color: AppColors.dragonfruitLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// "from a conversation · 4/19/2026" — the memory's provenance (plan
  /// Phase 2.4) over its confirmed date; rows with no source (written before
  /// the column existed) keep the date-only line.
  static String provenanceLine(ContentService content, UserMemory memory) {
    final source = sourceLabel(content, memory.source);
    final date = _confirmedDate(memory);
    if (source == null) {
      return ContentKeys.format(
        content.getValue(ContentKeys.mpSettingsMemoryConfirmed),
        {'date': date},
      );
    }
    return ContentKeys.format(
      content.getValue(ContentKeys.mpSettingsMemoryProvenance),
      {'source': source, 'date': date},
    );
  }

  /// The athlete-facing label for a `Memory.source`; `null` for an unknown
  /// or missing source so the caller falls back to the date alone.
  static String? sourceLabel(ContentService content, String? source) =>
      switch (source) {
        'conversation' => content.getValue(
          ContentKeys.mpMemorySourceConversation,
        ),
        'onboarding' => content.getValue(ContentKeys.mpMemorySourceOnboarding),
        'settings' => content.getValue(ContentKeys.mpMemorySourceSettings),
        'debrief' => content.getValue(ContentKeys.mpMemorySourceDebrief),
        _ => null,
      };

  /// The stored `lastConfirmedAt` as a plain local date.
  static String _confirmedDate(UserMemory memory) {
    final at = DateTime.tryParse(memory.lastConfirmedAt);
    if (at == null) return memory.lastConfirmedAt;
    return DateFormat.yMd().format(at.toLocal());
  }
}
