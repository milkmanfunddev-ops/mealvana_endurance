import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';

/// Brick Macro Summary Widget
///
/// Displays combined macro totals for an entire brick workout.
/// Shows total carbohydrates, protein, fat, sodium, and hydration across all phases.
///
/// Design specs from /docs/brick/ui-flow.md:
/// - Carbs, Protein, Fat, Sodium, Hydration rows
/// - Edit button for each macro type (pencil icon)
/// - Optional info button for explanation (question mark)
class BrickMacroSummary extends StatelessWidget {
  const BrickMacroSummary({
    super.key,
    required this.totalCarbsG,
    required this.totalProteinG,
    required this.totalFatG,
    required this.totalSodiumMg,
    required this.totalHydrationMl,
    this.onEditCarbs,
    this.onEditProtein,
    this.onEditFat,
    this.onEditSodium,
    this.onEditHydration,
    this.onInfoPressed,
  });

  final int totalCarbsG;
  final int totalProteinG;
  final int totalFatG;
  final int totalSodiumMg;
  final int totalHydrationMl;
  final VoidCallback? onEditCarbs;
  final VoidCallback? onEditProtein;
  final VoidCallback? onEditFat;
  final VoidCallback? onEditSodium;
  final VoidCallback? onEditHydration;
  final VoidCallback? onInfoPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 17),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with title and info button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TOTAL MACRO TARGETS',
                style: AppTextStyles.sectionTitle.copyWith(
                  fontSize: 12,
                  letterSpacing: 1.2,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              if (onInfoPressed != null)
                GestureDetector(
                  onTap: onInfoPressed,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                    ),
                    child: Icon(
                      FontAwesomeIcons.circleQuestion,
                      size: 12,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // Macro rows
          _buildMacroRow(
            context: context,
            icon: '🥖',
            label: 'Carbohydrates',
            value: '${totalCarbsG}g',
            onEdit: onEditCarbs,
          ),
          const SizedBox(height: 12),
          _buildMacroRow(
            context: context,
            icon: '🥩',
            label: 'Protein',
            value: '${totalProteinG}g',
            onEdit: onEditProtein,
          ),
          const SizedBox(height: 12),
          _buildMacroRow(
            context: context,
            icon: '🧈',
            label: 'Fat',
            value: '${totalFatG}g',
            onEdit: onEditFat,
          ),
          const SizedBox(height: 12),
          _buildMacroRow(
            context: context,
            icon: '🧂',
            label: 'Sodium',
            value: '${totalSodiumMg}mg',
            onEdit: onEditSodium,
          ),
          const SizedBox(height: 12),
          _buildMacroRow(
            context: context,
            icon: '💧',
            label: 'Hydration',
            value: '${totalHydrationMl}ml',
            onEdit: onEditHydration,
          ),
        ],
      ),
    );
  }

  Widget _buildMacroRow({
    required BuildContext context,
    required String icon,
    required String label,
    required String value,
    VoidCallback? onEdit,
  }) {
    return Row(
      children: [
        // Icon
        Text(
          icon,
          style: const TextStyle(fontSize: 20),
        ),
        const SizedBox(width: 12),

        // Label
        Expanded(
          child: Text(
            label,
            style: AppTextStyles.bodyLarge.copyWith(
              fontFamily: 'Apercu',
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),

        // Value
        Text(
          value,
          style: AppTextStyles.bodyLarge.copyWith(
            fontFamily: 'Compadre',
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(width: 12),

        // Edit button
        if (onEdit != null)
          GestureDetector(
            onTap: onEdit,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                FontAwesomeIcons.pencil,
                size: 14,
                color: AppColors.orange,
              ),
            ),
          ),
      ],
    );
  }
}
