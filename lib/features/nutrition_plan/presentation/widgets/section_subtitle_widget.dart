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
    return Text(
      _getDynamicSubtitle(),
      style: AppTheme.noteStyle.copyWith(
        color: AppTheme.primary600,
        fontSize: 13.sp,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  /// Calculate totals for this section and generate subtitle
  String _getDynamicSubtitle() {
    final totals = _calculateSectionTotals();
    final carbs = totals['carbs']!;
    final protein = totals['protein']!;
    final fluids = totals['fluids']!;

    switch (section.title) {
      case 'Before Run':
        return 'Pre-run fueling (${carbs}g carbs, ${protein}g protein)';
      case 'During Run':
        return 'Total: ${carbs}g carbs, ${fluids}ml fluids';
      case 'After Run':
        return 'Recovery (${carbs}g carbs, ${protein}g protein)';
      default:
        return section.subtitle ?? '';
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