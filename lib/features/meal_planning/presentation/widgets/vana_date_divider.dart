import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../features/content/application/content_service.dart';
import '../../../../features/content/domain/content_keys.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';

/// A centred day marker between transcript turns when a conversation
/// spans days (plan §5 Phase 6.4): "Today" / "Yesterday" / "Mon 1 Sep".
class VanaDateDivider extends ConsumerWidget {
  const VanaDateDivider({super.key, required this.date, this.now});

  final DateTime date;

  /// Injectable clock for tests; defaults to `DateTime.now()`.
  final DateTime? now;

  /// True when [a] and [b] fall on different local calendar days — the
  /// screen inserts a divider before the later message when so.
  static bool crossesDay(DateTime a, DateTime b) {
    final la = a.toLocal();
    final lb = b.toLocal();
    return la.year != lb.year || la.month != lb.month || la.day != lb.day;
  }

  /// The label for [date] relative to [now]: Today, Yesterday, else the
  /// short weekday + day + month. Pure so the copy selection is testable.
  static String labelFor(ContentService content, DateTime date, DateTime now) {
    final d = date.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final delta = today.difference(day).inDays;
    if (delta == 0) return content.getValue(ContentKeys.mpDividerToday);
    if (delta == 1) return content.getValue(ContentKeys.mpDividerYesterday);
    return DateFormat('EEE d MMM').format(d);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final content = ref.read(contentServiceProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = (isDark ? AppColors.cream : AppColors.blackberry).withValues(
      alpha: 0.5,
    );
    final line = muted.withValues(alpha: 0.15);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        children: [
          Expanded(child: Divider(color: line, height: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text(
              labelFor(content, date, now ?? DateTime.now()),
              style: AppTextStyles.bodySmall.copyWith(
                color: muted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
          ),
          Expanded(child: Divider(color: line, height: 1)),
        ],
      ),
    );
  }
}
