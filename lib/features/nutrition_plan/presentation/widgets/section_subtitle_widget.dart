import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/nutrition_plan.dart';

/// Separate widget for section subtitles that can be updated independently
/// Takes the plan as a parameter to calculate totals without watching controller
class SectionSubtitleWidget extends StatelessWidget {
  const SectionSubtitleWidget({
    super.key,
    required this.section,
    required this.plan,
  });

  final PlanSection section;
  final NutritionPlan plan;

  @override
  Widget build(BuildContext context) {
    return _buildColorizedSubtitle();
  }

  /// Build colorized subtitle with individual ratio colors
  Widget _buildColorizedSubtitle() {
    final totals = _calculateSectionTotals();
    final carbs = totals['carbs']!;
    final protein = totals['protein']!;
    final fluids = totals['fluids']!;
    final sodium = totals['sodium']!;
    
    List<InlineSpan> spans = [];
    
    switch (section.title) {
      case 'Before Run':
        final carbsTarget = plan.sections[0].carbsTarget?.toInt() ?? 0;
        final proteinTarget = plan.sections[0].proteinTarget?.toInt() ?? 0;
        final fluidsTarget = plan.sections[0].fluidsTarget?.toInt() ?? 0;
        final sodiumTarget = plan.sections[0].sodiumTarget?.toInt() ?? 0;
        
        spans = [
          _buildColorizedRatio(carbs, carbsTarget, 'g carbs'),
          const TextSpan(text: ', '),
          _buildColorizedRatio(protein, proteinTarget, 'g protein'),
          const TextSpan(text: ', '),
          _buildColorizedRatio(fluids, fluidsTarget, 'ml fluids'),
          const TextSpan(text: ', '),
          _buildColorizedRatio(sodium, sodiumTarget, 'mg sodium'),
        ];
        break;
        
      case 'During Run':
        final carbsTarget = plan.sections[1].carbsTarget?.toInt() ?? 0;
        final fluidsTarget = plan.sections[1].fluidsTarget?.toInt() ?? 0;
        final sodiumTarget = plan.sections[1].sodiumTarget?.toInt() ?? 0;
        
        spans = [
          _buildColorizedRatio(carbs, carbsTarget, 'g carbs'),
          const TextSpan(text: ', '),
          _buildColorizedRatio(fluids, fluidsTarget, 'ml fluids'),
          const TextSpan(text: ', '),
          _buildColorizedRatio(sodium, sodiumTarget, 'mg sodium'),
        ];
        break;
        
      case 'After Run':
        final carbsTarget = plan.sections[2].carbsTarget?.toInt() ?? 0;
        final proteinTarget = plan.sections[2].proteinTarget?.toInt() ?? 0;
        final fluidsTarget = plan.sections[2].fluidsTarget?.toInt() ?? 0;
        final sodiumTarget = plan.sections[2].sodiumTarget?.toInt() ?? 0;
        
        spans = [
          _buildColorizedRatio(carbs, carbsTarget, 'g carbs'),
          const TextSpan(text: ', '),
          _buildColorizedRatio(protein, proteinTarget, 'g protein'),
          const TextSpan(text: ', '),
          _buildColorizedRatio(fluids, fluidsTarget, 'ml fluids'),
          const TextSpan(text: ', '),
          _buildColorizedRatio(sodium, sodiumTarget, 'mg sodium'),
        ];
        break;
        
      default:
        return Text(
          section.subtitle ?? '',
          style: AppTheme.noteStyle.copyWith(
            color: AppTheme.primary600,
            fontSize: 13.sp,
            fontWeight: FontWeight.w500,
          ),
        );
    }
    
    return RichText(
      text: TextSpan(
        style: AppTheme.noteStyle.copyWith(
          color: AppTheme.primary600,
          fontSize: 13.sp,
          fontWeight: FontWeight.w500,
        ),
        children: spans,
      ),
    );
  }
  
  /// Build a colorized ratio text span (e.g. "25/30g carbs")
  TextSpan _buildColorizedRatio(int current, int target, String unit) {
    final color = _getColorForProgress(current, target);
    
    return TextSpan(
      text: '$current/$target$unit',
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.w600,
      ),
    );
  }
  
  /// Get color based on progress towards target using theme colors
  /// Green: 80-120% of target (close to target)
  /// Yellow: 120-150% of target (significantly over)
  /// Red: <80% or >150% of target (way off)
  Color _getColorForProgress(int current, int target) {
    if (target <= 0) return AppTheme.baseGrey;
    
    final ratio = current / target;
    
    if (ratio >= 0.8 && ratio <= 1.2) {
      // Close to target (80-120%) - Success Green
      return AppTheme.primary600;
    } else if (ratio > 1.2 && ratio <= 1.5) {
      // Significantly over (120-150%) - Warning Yellow
      return AppTheme.warning500;
    } else {
      // Way off (<80% or >150%) - Error Red
      return AppTheme.highlight400;
    }
  }

  /// Calculate totals for this section
  Map<String, int> _calculateSectionTotals() {
    int totalCarbs = 0;
    int totalProtein = 0;
    int totalCalories = 0;
    int totalSodium = 0;
    int totalFluids = 0;

    for (final foodItem in section.foodItems) {
      final nutrition = foodItem.nutritionalInfo;
      if (nutrition != null) {
        totalCarbs += nutrition.carbs ?? 0;
        totalProtein += nutrition.protein ?? 0;
        totalCalories += nutrition.calories ?? 0;
        totalSodium += nutrition.sodium ?? 0;
        totalFluids += (nutrition.fluids ?? 0).toInt();
      }
    }

    return {
      'carbs': totalCarbs,
      'protein': totalProtein,
      'calories': totalCalories,
      'sodium': totalSodium,
      'fluids': totalFluids,
    };
  }
}