import 'package:flutter/material.dart';
import '../../../../theme/app_theme.dart';

/// Simplified day tabs matching screenshot design
/// Three tabs: Day -2 (Begin), Day -1 (Peak), Race Day (Fuel)
class CarbLoadingDayTabs extends StatelessWidget {
  final int selectedDay;
  final Function(int) onDaySelected;

  const CarbLoadingDayTabs({
    super.key,
    required this.selectedDay,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _DayTab(
            day: -2,
            label: 'Day -2',
            subtitle: 'Begin',
            isSelected: selectedDay == -2,
            onTap: () => onDaySelected(-2),
          ),
          const SizedBox(width: 8),
          _DayTab(
            day: -1,
            label: 'Day -1',
            subtitle: 'Peak',
            isSelected: selectedDay == -1,
            onTap: () => onDaySelected(-1),
          ),
          const SizedBox(width: 8),
          _DayTab(
            day: 0,
            label: 'Race Day',
            subtitle: 'Fuel',
            isSelected: selectedDay == 0,
            onTap: () => onDaySelected(0),
          ),
        ],
      ),
    );
  }
}

/// Individual day tab widget
class _DayTab extends StatelessWidget {
  final int day;
  final String label;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _DayTab({
    required this.day,
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: isSelected
              ? AppTheme.primary900
              : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                ? AppTheme.primary900
                : Colors.grey[300]!,
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: isSelected ? Colors.white : Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isSelected
                    ? Colors.white.withValues(alpha: 0.9)
                    : Colors.grey[600],
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}