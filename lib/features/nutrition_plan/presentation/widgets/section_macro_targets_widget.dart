import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/nutrition_plan.dart';

/// Widget to display macro targets for a specific plan section
/// Shows the nutrition targets for each section (Before/During/After)
class SectionMacroTargetsWidget extends StatelessWidget {
  const SectionMacroTargetsWidget({
    super.key,
    required this.section,
    this.showTargets = true,
  });

  final PlanSection section;
  final bool showTargets;

  @override
  Widget build(BuildContext context) {
    if (!showTargets || !_hasTargets) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: AppTheme.baseCream.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: AppTheme.baseGrey.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Target Macros',
            style: AppTheme.noteStyle.copyWith(
              fontWeight: FontWeight.w600,
              color: AppTheme.primary600,
            ),
          ),
          SizedBox(height: 6.h),
          Wrap(spacing: 12.w, runSpacing: 4.h, children: _buildTargetChips()),
        ],
      ),
    );
  }

  bool get _hasTargets =>
      section.carbsTarget != null ||
      section.proteinTarget != null ||
      section.fatTarget != null ||
      section.sodiumTarget != null ||
      section.fluidsTarget != null;

  List<Widget> _buildTargetChips() {
    final List<Widget> chips = [];

    if (section.carbsTarget != null && section.carbsTarget! > 0) {
      chips.add(
        _buildTargetChip(
          'Carbs',
          '${section.carbsTarget!.toInt()}g',
          AppTheme.carbsColor,
        ),
      );
    }

    if (section.proteinTarget != null && section.proteinTarget! > 0) {
      chips.add(
        _buildTargetChip(
          'Protein',
          '${section.proteinTarget!.toInt()}g',
          AppTheme.proteinColor,
        ),
      );
    }

    if (section.fatTarget != null && section.fatTarget! > 0) {
      chips.add(
        _buildTargetChip(
          'Fat',
          '${section.fatTarget!.toInt()}g',
          AppTheme.fatsColor,
        ),
      );
    }

    if (section.sodiumTarget != null && section.sodiumTarget! > 0) {
      chips.add(
        _buildTargetChip(
          'Sodium',
          '${section.sodiumTarget!.toInt()}mg',
          AppTheme.sodiumColor,
        ),
      );
    }

    if (section.fluidsTarget != null && section.fluidsTarget! > 0) {
      chips.add(
        _buildTargetChip(
          'Fluids',
          '${(section.fluidsTarget! / 1000).toStringAsFixed(1)}L',
          AppTheme.fluidsColor,
        ),
      );
    }

    return chips;
  }

  Widget _buildTargetChip(String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTheme.noteStyle.copyWith(
              fontSize: 10.sp,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
          SizedBox(width: 4.w),
          Text(
            value,
            style: AppTheme.noteStyle.copyWith(
              fontSize: 10.sp,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
