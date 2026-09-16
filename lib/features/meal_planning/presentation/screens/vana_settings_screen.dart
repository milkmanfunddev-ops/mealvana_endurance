import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../application/vana_settings_controller.dart';
import '../../domain/week_start.dart';
import '../widgets/memory_drawer.dart';
import '../widgets/stepper.dart';
import '../widgets/vana_round_button.dart';

/// `/settings/vana` (05 §4): the Meal planning settings — batch cooking,
/// show-macros (the two Vana can flip from inside a conversation), the day
/// a plan week starts and how many days it runs (mp-269), and the
/// device-local check-in/debrief reminders — over "What Vana knows".
class VanaSettingsScreen extends ConsumerWidget {
  const VanaSettingsScreen({super.key});

  /// The localized weekday name for `DateTime.monday` … `DateTime.sunday`.
  static String weekdayName(int weekday) =>
      // 2026-09-13 is a Sunday; weekday % 7 counts days after it.
      DateFormat('EEEE').format(DateTime(2026, 9, 13 + weekday % 7));

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
    final period = state?.period ?? const PlanPeriod();

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
                    trailing: _SettingSwitch(
                      value: state?.batchCooking ?? true,
                      onChanged: controller.setBatchCooking,
                    ),
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
                    trailing: _SettingSwitch(
                      value: showMacros,
                      onChanged: controller.setShowMacros,
                    ),
                    showDivider: true,
                  ),
                  _SettingRow(
                    rowKey: const ValueKey('meal_planning.settings_week_start'),
                    title: content.getValue(ContentKeys.mpSettingsWeekStart),
                    subtitle: content.getValue(
                      ContentKeys.mpSettingsWeekStartSub,
                    ),
                    trailing: _WeekStartPicker(
                      weekday: period.startWeekday,
                      onChanged: controller.setWeekStart,
                    ),
                    showDivider: true,
                  ),
                  _SettingRow(
                    rowKey: const ValueKey(
                      'meal_planning.settings_period_days',
                    ),
                    title: content.getValue(ContentKeys.mpSettingsPeriodDays),
                    subtitle: ContentKeys.format(
                      content.getValue(ContentKeys.mpPeriodDays),
                      {'n': period.days},
                    ),
                    trailing: ServingsStepper(
                      key: const ValueKey(
                        'meal_planning.settings_period_days_stepper',
                      ),
                      value: period.days,
                      min: PlanPeriod.minDays,
                      max: PlanPeriod.maxDays,
                      dense: true,
                      onChanged: controller.setPeriodDays,
                    ),
                    showDivider: true,
                  ),
                  _SettingRow(
                    rowKey: const ValueKey('meal_planning.settings_reminders'),
                    title: content.getValue(ContentKeys.mpSettingsReminders),
                    subtitle: content.getValue(
                      ContentKeys.mpSettingsRemindersSub,
                    ),
                    trailing: _SettingSwitch(
                      value: state?.remindersEnabled ?? false,
                      onChanged: controller.setRemindersEnabled,
                    ),
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

/// One 56pt settings row: title over its explanation, with the control on
/// the trailing edge.
class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.rowKey,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.showDivider,
  });

  final Key rowKey;
  final String title;
  final String subtitle;
  final Widget trailing;
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
          trailing,
        ],
      ),
    );
  }
}

class _SettingSwitch extends StatelessWidget {
  const _SettingSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Switch(
    value: value,
    onChanged: onChanged,
    activeThumbColor: AppColors.blackberry,
    activeTrackColor: AppColors.electrolyte,
  );
}

/// The start day as its name with a chevron; tapping opens the seven days,
/// Sunday first (the `week_start` wire order).
class _WeekStartPicker extends StatelessWidget {
  const _WeekStartPicker({required this.weekday, required this.onChanged});

  final int weekday;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final accent = isDark ? AppColors.electrolyte : AppColors.electrolyteDark;
    return PopupMenuButton<int>(
      key: const ValueKey('meal_planning.settings_week_start_picker'),
      initialValue: weekday,
      onSelected: onChanged,
      color: isDark ? AppColors.blackberryLight : AppColors.cream,
      itemBuilder: (_) => [
        for (final wire in PlanPeriod.weekdayWires)
          PopupMenuItem<int>(
            key: ValueKey('meal_planning.settings_week_start_$wire'),
            value: PlanPeriod.weekdayFromWire(wire),
            child: Text(
              VanaSettingsScreen.weekdayName(PlanPeriod.weekdayFromWire(wire)!),
              style: AppTextStyles.bodyMedium.copyWith(color: textColor),
            ),
          ),
      ],
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            VanaSettingsScreen.weekdayName(weekday),
            style: AppTextStyles.bodyMedium.copyWith(
              color: accent,
              fontWeight: FontWeight.w600,
            ),
          ),
          Icon(Icons.keyboard_arrow_down, color: accent, size: 20),
        ],
      ),
    );
  }
}
