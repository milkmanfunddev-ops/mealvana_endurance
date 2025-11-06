import 'package:flutter/material.dart';
import 'package:mealvana_endurance/theme/app_theme.dart';
import '../../domain/event.dart';

/// A beautiful segmented control for selecting sport categories
///
/// Displays icons and labels for each sport type in a horizontally
/// scrollable row with clear visual feedback for selection.
class SportCategorySelector extends StatelessWidget {
  const SportCategorySelector({
    super.key,
    required this.selectedCategory,
    required this.onCategoryChanged,
  });

  final EventType selectedCategory;
  final ValueChanged<EventType> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Sport Category',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: EventType.values.map((category) {
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _SportCategoryChip(
                  category: category,
                  isSelected: selectedCategory == category,
                  onTap: () => onCategoryChanged(category),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

/// Individual chip for a sport category
class _SportCategoryChip extends StatelessWidget {
  const _SportCategoryChip({
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  final EventType category;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.highlight600 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.highlight600 : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.highlight600.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Text(
              category.icon,
              style: const TextStyle(fontSize: 28),
            ),
            const SizedBox(height: 4),
            // Label
            Text(
              category.displayName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
