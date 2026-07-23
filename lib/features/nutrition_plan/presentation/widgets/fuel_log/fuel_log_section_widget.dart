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
  // Callbacks take the full item: foodId + sectionId is not unique (the same
  // food can appear in a sub-phase group and the "Added" bucket), so the
  // controller needs the item's subPhaseType/isAdded to target one row.
  final void Function(FuelLogItem item) onIncrement;
  final void Function(FuelLogItem item) onDecrement;
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
          onIncrement: () => onIncrement(item),
          onDecrement: () => onDecrement(item),
          isViewOnly: isViewOnly,
        );
      }).toList(),
    );
  }

  Widget _buildSubPhaseItems(BuildContext context) {
    final entries = subPhaseGroups!.entries.toList();

    // Items whose sub-phase is null or doesn't match any rendered group
    // (e.g. foods added via ADD FOOD during logging). Without this bucket
    // they would be silently dropped: the write succeeds but the grouped
    // render never shows them (bug 3a3e3fdb).
    final ungroupedItems = items
        .where(
          (item) =>
              item.subPhaseType == null ||
              !subPhaseGroups!.containsKey(item.subPhaseType),
        )
        .toList();

    return Column(
      children: [
        ...entries.map((entry) {
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
                  onIncrement: () => onIncrement(item),
                  onDecrement: () => onDecrement(item),
                  isViewOnly: isViewOnly,
                ),
              ),
              if (entry.key != entries.last.key || ungroupedItems.isNotEmpty)
                Divider(
                  height: 1,
                  indent: AppSpacing.md,
                  endIndent: AppSpacing.md,
                  color: sectionColor.withValues(alpha: 0.1),
                ),
            ],
          );
        }),
        if (ungroupedItems.isNotEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // "Added" bucket header — mirrors the sub-phase header style
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.xxs,
                ),
                child: Text(
                  _addedBucketTitle,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ...ungroupedItems.map(
                (item) => FuelLogFoodRow(
                  item: item,
                  sectionColor: sectionColor,
                  onIncrement: () => onIncrement(item),
                  onDecrement: () => onDecrement(item),
                  isViewOnly: isViewOnly,
                ),
              ),
            ],
          ),
      ],
    );
  }

  /// Header for foods added during logging that don't belong to a sub-phase.
  /// Hardcoded to match sibling labels in this widget (see
  /// [_subPhaseDisplayTitle] and the 'Added' row label in FuelLogFoodRow).
  static const String _addedBucketTitle = 'Added';

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
