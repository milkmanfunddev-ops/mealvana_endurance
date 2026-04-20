import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';

import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../calendar/presentation/providers/calendar_selected_date_provider.dart';

/// Shared date navigation header: < Today, Mar 25 >
class DateNavigationHeader extends ConsumerWidget {
  const DateNavigationHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(calendarSelectedDateProvider);
    final today = DateTime.now();
    final isToday = selectedDate.year == today.year &&
        selectedDate.month == today.month &&
        selectedDate.day == today.day;

    final dateFormat = DateFormat('EEE, MMM d');
    final dateString = isToday ? 'Today, ${DateFormat('MMM d').format(selectedDate)}' : dateFormat.format(selectedDate);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: () {
            ref.read(calendarSelectedDateProvider.notifier).setDate(
              selectedDate.subtract(const Duration(days: 1)),
            );
          },
          icon: FaIcon(
            FontAwesomeIcons.chevronLeft,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        GestureDetector(
          onTap: () {
            // Tapping date label goes back to today
            ref.read(calendarSelectedDateProvider.notifier).setDate(
              DateTime.now(),
            );
          },
          child: Text(
            dateString,
            style: AppTextStyles.subtitle.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        IconButton(
          onPressed: () {
            ref.read(calendarSelectedDateProvider.notifier).setDate(
              selectedDate.add(const Duration(days: 1)),
            );
          },
          icon: FaIcon(
            FontAwesomeIcons.chevronRight,
            size: 16,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
