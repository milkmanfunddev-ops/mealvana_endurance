import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../../../calendar/presentation/providers/calendar_selected_date_provider.dart';
import '../../../calendar/presentation/providers/calendar_view_provider.dart';
import '../../../calendar/presentation/widgets/calendar_view_toggle.dart'
    show CalendarViewMode;
import '../../../daily_macros/presentation/providers/daily_macros_controller.dart';
import '../fuel_timeline_type.dart';

/// The bespoke Fuel Timeline header matching the mockup: BY WEEK / BY MONTH
/// (Compadre Wide) + settings gear, the month nav, and a large-number week
/// strip with a cream pill on the selected day and teal data dots.
///
/// Replaces the generic calendar widgets for this screen so the typography and
/// scale match the design. Shares [calendarSelectedDateProvider] /
/// [calendarViewProvider] with the rest of the app.
class FuelTimelineDayHeader extends ConsumerWidget {
  const FuelTimelineDayHeader({super.key});

  static const _dot = AppColors.electrolyteDark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(calendarSelectedDateProvider);
    final mode = ref.watch(calendarViewProvider);
    final isWeek = mode == CalendarViewMode.week;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Foreground flips cream-on-dark / blackberry-on-light; the selected-day
    // pill fill is the foreground colour with its text as the inverse (the
    // background it's meant to contrast against).
    final onSurface = isDark ? AppColors.cream : AppColors.blackberry;
    final surfaceBg = isDark ? AppColors.blackberry : AppColors.cream;
    final dim = onSurface.withValues(alpha: 0.5);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _toggleRow(context, ref, isWeek, onSurface, dim),
        ),
        // More breathing room before the month nav (it was crowding BY WEEK).
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _monthNav(ref, selected, isWeek, onSurface),
        ),
        const SizedBox(height: 14),
        // Week strip spreads nearly edge-to-edge so the day numbers aren't
        // squished.
        if (isWeek)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _weekStrip(ref, selected, onSurface, surfaceBg),
          ),
        const SizedBox(height: 10),
        Container(height: 1, color: onSurface.withValues(alpha: 0.1)),
      ],
    );
  }

  Widget _toggleRow(
    BuildContext context,
    WidgetRef ref,
    bool isWeek,
    Color onSurface,
    Color dim,
  ) {
    void setMode(CalendarViewMode m) =>
        ref.read(calendarViewProvider.notifier).setView(m);

    Widget label(String text, bool active) {
      return GestureDetector(
        onTap: () => setMode(
          text == 'BY WEEK' ? CalendarViewMode.week : CalendarViewMode.month,
        ),
        child: Container(
          padding: const EdgeInsets.only(bottom: 5),
          decoration: active
              ? BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: onSurface, width: 2),
                  ),
                )
              : null,
          child: Text(
            text,
            style: FtType.byWeek.copyWith(color: active ? onSurface : dim),
          ),
        ),
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            label('BY WEEK', isWeek),
            const SizedBox(width: 26),
            label('BY MONTH', !isWeek),
          ],
        ),
        Positioned(
          right: 0,
          child: GestureDetector(
            key: const ValueKey('fuel_timeline.settings'),
            onTap: () => context.push('/settings'),
            child: Icon(Icons.settings_outlined, size: 20, color: onSurface),
          ),
        ),
      ],
    );
  }

  Widget _monthNav(
    WidgetRef ref,
    DateTime selected,
    bool isWeek,
    Color onSurface,
  ) {
    void shift(int dir) {
      final next = isWeek
          ? selected.add(Duration(days: 7 * dir))
          : DateTime(selected.year, selected.month + dir, selected.day);
      ref.read(calendarSelectedDateProvider.notifier).setDate(next);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () => shift(-1),
          child: Icon(Icons.chevron_left, size: 18, color: onSurface),
        ),
        const SizedBox(width: 18),
        Text(
          DateFormat('MMMM yyyy').format(selected),
          style: FtType.monthTitle.copyWith(color: onSurface),
        ),
        const SizedBox(width: 18),
        GestureDetector(
          onTap: () => shift(1),
          child: Icon(Icons.chevron_right, size: 18, color: onSurface),
        ),
      ],
    );
  }

  Widget _weekStrip(
    WidgetRef ref,
    DateTime selected,
    Color onSurface,
    Color surfaceBg,
  ) {
    final startOfWeek = selected.subtract(Duration(days: selected.weekday % 7));
    final week = ref.watch(dailyMacrosControllerProvider).asData?.value;
    final weekly = week?.weeklyMacros ?? const [];

    return Row(
      children: [
        for (var i = 0; i < 7; i++)
          Expanded(
            child: _dayColumn(
              ref,
              day: startOfWeek.add(Duration(days: i)),
              selected: selected,
              hasData: i < weekly.length && (weekly[i]?.isTrainingDay ?? false),
              onSurface: onSurface,
              surfaceBg: surfaceBg,
            ),
          ),
      ],
    );
  }

  Widget _dayColumn(
    WidgetRef ref, {
    required DateTime day,
    required DateTime selected,
    required bool hasData,
    required Color onSurface,
    required Color surfaceBg,
  }) {
    const letters = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    final isSelected =
        day.year == selected.year &&
        day.month == selected.month &&
        day.day == selected.day;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => ref.read(calendarSelectedDateProvider.notifier).setDate(day),
      child: Column(
        children: [
          Text(
            letters[day.weekday % 7],
            style: FtType.dayLetter.copyWith(
              color: onSurface.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 7),
          SizedBox(
            height: 34,
            child: Center(
              child: isSelected
                  ? Container(
                      width: 46,
                      height: 34,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: onSurface,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '${day.day}',
                          softWrap: false,
                          style: FtType.dayNumber.copyWith(color: surfaceBg),
                        ),
                      ),
                    )
                  : FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        '${day.day}',
                        softWrap: false,
                        style: FtType.dayNumber.copyWith(color: onSurface),
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 7),
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: hasData ? _dot : Colors.transparent,
            ),
          ),
        ],
      ),
    );
  }
}
