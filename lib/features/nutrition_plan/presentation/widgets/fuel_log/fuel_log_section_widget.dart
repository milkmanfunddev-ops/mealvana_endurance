import 'package:flutter/material.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../domain/fuel_log_data.dart';
import 'fuel_log_food_row.dart';

/// Displays a phase section (Before/During/After) in fuel log mode.
class FuelLogSectionWidget extends StatelessWidget {
  const FuelLogSectionWidget({
    super.key,
    required this.sectionId,
    required this.title,
    required this.items,
    required this.sectionColor,
    required this.onIncrement,
    required this.onDecrement,
    required this.onAddFood,
    this.subPhaseGroups,
    this.isViewOnly = false,
  });

  final String sectionId;
  final String title;
  final List<FuelLogItem> items;
  final Color sectionColor;
  final void Function(String foodId, String sectionId) onIncrement;
  final void Function(String foodId, String sectionId) onDecrement;
  final VoidCallback onAddFood;
  final bool isViewOnly;

  /// Optional sub-phase grouping for before sections.
  /// Keys: 'meal', 'snack', 'top_up'. Values: list of items in that sub-phase.
  final Map<String, List<FuelLogItem>>? subPhaseGroups;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        borderRadius: AppRadius.cardRadius,
        border: Border.all(
          color: sectionColor.withValues(alpha: 0.3),
          width: 1.5,
        ),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          _buildHeader(context),

          // Divider
          Divider(height: 1, color: sectionColor.withValues(alpha: 0.15)),

          // Food items (grouped by sub-phase if applicable)
          if (subPhaseGroups != null && subPhaseGroups!.isNotEmpty)
            _buildSubPhaseItems(context)
          else
            _buildFlatItems(context),

          // Add food button
          if (!isViewOnly)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: TextButton.icon(
                onPressed: onAddFood,
                icon: Icon(Icons.add, color: sectionColor, size: 18),
                label: Text(
                  'ADD FOOD',
                  style: AppTextStyles.smallLabel.copyWith(
                    color: sectionColor,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: sectionColor.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(14.0),
          topRight: Radius.circular(14.0),
        ),
      ),
      child: Row(
        children: [
          Text(
            title.toUpperCase(),
            style: AppTextStyles.smallLabel.copyWith(
              color: sectionColor,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlatItems(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: Text(
            'No foods in this section',
            style: AppTextStyles.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    return Column(
      children: items.map((item) {
        return FuelLogFoodRow(
          item: item,
          sectionColor: sectionColor,
          onIncrement: () => onIncrement(item.foodId, sectionId),
          onDecrement: () => onDecrement(item.foodId, sectionId),
          isViewOnly: isViewOnly,
        );
      }).toList(),
    );
  }

  Widget _buildSubPhaseItems(BuildContext context) {
    final entries = subPhaseGroups!.entries.toList();

    return Column(
      children: entries.map((entry) {
        final subPhaseTitle = _subPhaseDisplayTitle(entry.key);
        final subItems = entry.value;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sub-phase header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.xxs,
              ),
              child: Text(
                subPhaseTitle,
                style: AppTextStyles.bodySmall.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ...subItems.map(
              (item) => FuelLogFoodRow(
                item: item,
                sectionColor: sectionColor,
                onIncrement: () => onIncrement(item.foodId, sectionId),
                onDecrement: () => onDecrement(item.foodId, sectionId),
                isViewOnly: isViewOnly,
              ),
            ),
            if (entry.key != entries.last.key)
              Divider(
                height: 1,
                indent: AppSpacing.md,
                endIndent: AppSpacing.md,
                color: sectionColor.withValues(alpha: 0.1),
              ),
          ],
        );
      }).toList(),
    );
  }

  String _subPhaseDisplayTitle(String subPhaseType) {
    switch (subPhaseType) {
      case 'meal':
        return 'Full Meal';
      case 'snack':
        return 'Pre-Workout Snack';
      case 'top_up':
        return 'Top-Off';
      default:
        return subPhaseType;
    }
  }
}
