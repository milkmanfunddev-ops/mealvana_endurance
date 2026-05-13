import 'package:flutter/material.dart';
import '../../../../theme/kyle_design/app_colors.dart';

/// Empty state widget shown when no activities are scheduled for the selected date.
///
/// Displays:
/// - Calendar icon (gray, 64px)
/// - "No fueling plans yet" - main title (gray, Apercu font)
/// - "Tap + to fuel your next workout" - orange subtitle (bold)
///
/// Follows Kyle design patterns with Apercu font throughout.
class NoFuelingPlansWidget extends StatelessWidget {
  const NoFuelingPlansWidget({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Calendar icon (gray, 64px)
        Icon(
          Icons.calendar_today,
          size: 64,
          color: isDark ? Colors.grey[500] : Colors.grey[400],
        ),
        const SizedBox(height: 16),

        // Main title: "No fueling plans yet" (Apercu font, not Compadre)
        Text(
          key: const ValueKey('calendar.empty_title'),
          'No fueling plans yet',
          style: TextStyle(
            fontFamily: 'Apercu',
            fontSize: 18,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
            height: 1.3,
          ),
        ),
        const SizedBox(height: 8),

        // Orange subtitle: "Tap + to fuel your next workout" (larger, bolder)
        Text(
          key: const ValueKey('calendar.empty_subtitle'),
          'Tap + to fuel your next workout',
          style: const TextStyle(
            fontFamily: 'Apercu',
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.orange,
            height: 1.3,
          ),
        ),
      ],
    );
  }
}
