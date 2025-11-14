import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_spacing.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_text_styles.dart';


/// Macro targets table for Kyle's design system
/// Table with borders showing nutritional targets
class MacroTargetsTable extends ConsumerWidget {
  const MacroTargetsTable({
    super.key,
    required this.title,
    required this.macroData,
    this.onInfoPressed,
    this.backgroundColor,
  });

  final String title;
  final MacroTableData macroData;
  final VoidCallback? onInfoPressed;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Material(
        color: backgroundColor ?? Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.cardRadius,
        elevation: 0,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardRadius,
            border: Border.all(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(context),
              
              // Table
              _buildTable(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.sectionTitle.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          if (onInfoPressed != null)
            IconButton(
              icon: Icon(
                FontAwesomeIcons.circleInfo,
                color: AppColors.dragonfruit,
                size: AppIconSizes.controlIcon,
              ),
              onPressed: onInfoPressed,
            ),
        ],
      ),
    );
  }

  Widget _buildTable(BuildContext context) {
    return Column(
      children: [
        // Header row
        _buildTableRow(
          context,
          isHeader: true,
          cells: const ['PRE', 'DURING', 'POST'],
        ),
        
        // Data rows
        _buildTableRow(
          context,
          cells: [
            'CARBS',
            '${macroData.preCarbs}g',
            '${macroData.duringCarbs}g',
            '${macroData.postCarbs}g',
          ],
        ),
        
        _buildTableRow(
          context,
          cells: [
            'PROTEIN',
            '${macroData.preProtein}g',
            '${macroData.duringProtein}g',
            '${macroData.postProtein}g',
          ],
        ),
        
        _buildTableRow(
          context,
          cells: [
            'FLUIDS',
            '${macroData.preFluids}mL',
            '${macroData.duringFluids}mL',
            '${macroData.postFluids}mL',
          ],
        ),
        
        _buildTableRow(
          context,
          cells: [
            'SODIUM',
            '${macroData.preSodium}mg',
            '${macroData.duringSodium}mg',
            '${macroData.postSodium}mg',
          ],
        ),
      ],
    );
  }

  Widget _buildTableRow(
    BuildContext context, {
    required List<String> cells,
    bool isHeader = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: cells.asMap().entries.map((entry) {
          final index = entry.key;
          final cell = entry.value;
          final isLast = index == cells.length - 1;
          
          return Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(
                vertical: AppSpacing.sm,
                horizontal: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                border: Border(
                  right: isLast
                      ? BorderSide.none
                      : BorderSide(
                          color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                          width: 1,
                        ),
                ),
              ),
              child: isHeader
                  ? Text(
                      cell,
                      style: AppTextStyles.smallLabel.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    )
                  : index == 0
                      ? Text(
                          cell,
                          style: AppTextStyles.smallLabel.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : Text(
                          cell,
                          style: AppTextStyles.dataNumber.copyWith(
                            color: Theme.of(context).colorScheme.onSurface,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Macro table data class
class MacroTableData {
  const MacroTableData({
    required this.preCarbs,
    required this.duringCarbs,
    required this.postCarbs,
    required this.preProtein,
    required this.duringProtein,
    required this.postProtein,
    required this.preFluids,
    required this.duringFluids,
    required this.postFluids,
    required this.preSodium,
    required this.duringSodium,
    required this.postSodium,
  });

  final int preCarbs;
  final int duringCarbs;
  final int postCarbs;
  final int preProtein;
  final int duringProtein;
  final int postProtein;
  final int preFluids;
  final int duringFluids;
  final int postFluids;
  final int preSodium;
  final int duringSodium;
  final int postSodium;
}

/// Simple macro targets card for smaller spaces
class MacroTargetsCard extends ConsumerWidget {
  const MacroTargetsCard({
    super.key,
    required this.macroData,
    this.backgroundColor,
  });

  final MacroTableData macroData;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Material(
        color: backgroundColor ?? Theme.of(context).colorScheme.surface,
        borderRadius: AppRadius.cardRadius,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            borderRadius: AppRadius.cardRadius,
            border: Border.all(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          child: Column(
            children: [
              // Carbs
              _buildMacroRow(
                context,
                label: 'CARBS',
                value: '${macroData.preCarbs + macroData.duringCarbs + macroData.postCarbs}g',
                color: Colors.orange,
              ),

              const SizedBox(height: AppSpacing.sm),

              // Protein
              _buildMacroRow(
                context,
                label: 'PROTEIN',
                value: '${macroData.preProtein + macroData.duringProtein + macroData.postProtein}g',
                color: AppColors.electrolyte,
              ),

              const SizedBox(height: AppSpacing.sm),
              
              // Fluids
              _buildMacroRow(
                context,
                label: 'FLUIDS',
                value: '${macroData.preFluids + macroData.duringFluids + macroData.postFluids}mL',
                color: AppColors.dragonfruit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMacroRow(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.smallLabel.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          value,
          style: AppTextStyles.dataNumber.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 20,
          ),
        ),
      ],
    );
  }
}