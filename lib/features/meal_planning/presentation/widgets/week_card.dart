import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../shared/widgets/kyle_design/buttons/tertiary_button.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../../domain/vana_part.dart';
import 'slot_chip.dart';
import 'vana_tag.dart';

/// `week` part (plan Phase 8): the confirmed collection laid across the
/// week — one read-only row per `day` part (label · date, then each filled
/// slot as a chip + meal name) and a tertiary "Open Plan tab" action. The
/// Plan tab owns the editing; this is the receipt in the transcript.
class WeekCard extends ConsumerWidget {
  const WeekCard({super.key, required this.part, this.onOpenPlan});

  final VanaWeekPart part;
  final VoidCallback? onOpenPlan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final secondary = textColor.withValues(alpha: 0.65);
    final surface = isDark ? AppColors.blackberryLight : AppColors.surfaceLight;

    return Container(
      key: const ValueKey('meal_planning.week_card'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: AppColors.electrolyte.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            content.getValue(ContentKeys.mpWeekTitle),
            style: AppTextStyles.sectionTitle.copyWith(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          for (final (i, day) in part.days.indexed) ...[
            SizedBox(height: i == 0 ? AppSpacing.xs : AppSpacing.sm),
            _DayRow(day: day, textColor: textColor, secondary: secondary),
          ],
          if (onOpenPlan != null) ...[
            const SizedBox(height: AppSpacing.xs),
            KyleTertiaryButton(
              key: const ValueKey('meal_planning.week_open_plan'),
              text: content.getValue(ContentKeys.mpWeekOpenPlan),
              alignment: MainAxisAlignment.start,
              onPressed: onOpenPlan,
            ),
          ],
        ],
      ),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({
    required this.day,
    required this.textColor,
    required this.secondary,
  });

  final VanaDayPart day;
  final Color textColor;
  final Color secondary;

  /// "Mon, Sep 7" for the row's date; the raw string when unparseable.
  static String dateLabel(String iso) {
    final d = DateTime.tryParse(iso);
    return d == null ? iso : DateFormat('EEE, MMM d').format(d);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      key: ValueKey('meal_planning.week_day_${day.date}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (day.label.isNotEmpty) ...[
              VanaTag(label: day.label),
              const SizedBox(width: 8),
            ],
            Text(
              dateLabel(day.date),
              style: AppTextStyles.bodySmall.copyWith(color: secondary),
            ),
          ],
        ),
        for (final slot in day.slots.filled) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              SlotChip(type: slot, short: true),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  day.slots.slotFor(slot)?.name ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySmall.copyWith(color: textColor),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
