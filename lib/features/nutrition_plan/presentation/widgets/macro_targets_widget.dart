import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../theme/app_theme.dart';
import '../../../../shared/widgets/completion_bar.dart';
import '../../domain/nutrition_plan.dart';
import '../../domain/macro_targets.dart' as targets_model;

class MacroTargetsWidget extends StatelessWidget {
  final NutritionPlan plan;
  final targets_model.MacroTargets? targets;
  
  const MacroTargetsWidget({
    super.key,
    required this.plan,
    this.targets,
  });
  
  @override
  Widget build(BuildContext context) {
    // Calculate current values from plan
    double currentCarbs = 0;
    double currentSodium = 0;
    double currentFluids = 0;
    
    print('DEBUG: Calculating current nutrition from plan...');
    
    for (final section in plan.sections) {
      print('  Section: ${section.title} (${section.foodItems.length} items)');
      for (final item in section.foodItems) {
        // Use the nutritionalInfo from FoodItemData
        if (item.nutritionalInfo != null) {
          final itemCarbs = (item.nutritionalInfo!.carbs ?? 0).toDouble();
          final itemSodium = (item.nutritionalInfo!.sodium ?? 0).toDouble();
          final itemFluids = (item.nutritionalInfo!.fluids ?? 0).toDouble();
          
          print('    - ${item.name}: ${itemCarbs}g carbs, ${itemSodium}mg sodium, ${itemFluids}ml fluids');
          
          currentCarbs += itemCarbs;
          currentSodium += itemSodium;
          currentFluids += itemFluids;
        } else {
          print('    - ${item.name}: NO NUTRITION INFO');
        }
      }
    }
    
    print('  TOTAL CURRENT: ${currentCarbs}g carbs, ${currentSodium}mg sodium, ${currentFluids}ml fluids');
    
    // Get target values from all phases (pre, during, post)
    double targetCarbs = 90.0; // default
    double targetSodium = 1000.0; // default  
    double targetFluids = 1.5; // default in liters
    
    if (targets != null) {
      // Sum up carbs from all phases
      targetCarbs = targets!.preRun.carbsG + 
                    targets!.duringRun.carbTotalG + 
                    targets!.postRun.carbsG;
      
      // Sum up sodium from all phases
      targetSodium = targets!.preRun.sodiumMg + 
                     targets!.duringRun.sodiumTotalMg + 
                     targets!.postRun.sodiumMg;
      
      // Sum up fluids from all phases (convert ml to L)
      targetFluids = (targets!.preRun.fluidsMl + 
                      targets!.duringRun.fluidTotalMl + 
                      targets!.postRun.fluidsMl) / 1000;

      print('🐛 DEBUG MacroTargetsWidget:');
      print('  Raw fluid values:');
      print('    Pre-run fluids: ${targets!.preRun.fluidsMl} ml');
      print('    During-run fluids: ${targets!.duringRun.fluidTotalMl} ml');
      print('    Post-run fluids: ${targets!.postRun.fluidsMl} ml');
      print('  Target carbs: ${targetCarbs}g (${targets!.preRun.carbsG} + ${targets!.duringRun.carbTotalG} + ${targets!.postRun.carbsG})');
      print('  Target sodium: ${targetSodium}mg (${targets!.preRun.sodiumMg} + ${targets!.duringRun.sodiumTotalMg} + ${targets!.postRun.sodiumMg})');
      print('  Target fluids: ${targetFluids}L (${targets!.preRun.fluidsMl} + ${targets!.duringRun.fluidTotalMl} + ${targets!.postRun.fluidsMl} ml)');
      print('  Current carbs: ${currentCarbs}g');
      print('  Current sodium: ${currentSodium}mg');
      print('  Current fluids: ${currentFluids}ml');
      print('  CompletionBar will show: current=${(currentFluids / 1000).toStringAsFixed(0)}, target=${targetFluids.toStringAsFixed(0)}');
    }
    
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: AppTheme.baseWhite,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: AppTheme.primary900,
          width: 2.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Macro targets',
            style: AppTheme.subtitleStyle.copyWith(
              color: AppTheme.primary900,
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 16.h),
          CompletionBar(
            current: currentCarbs,
            target: targetCarbs,
            label: 'Carbohydrates',
            unit: 'g',
          ),
          SizedBox(height: 16.h),
          CompletionBar(
            current: currentSodium,
            target: targetSodium,
            label: 'Sodium',
            unit: 'mg',
          ),
          SizedBox(height: 16.h),
          CompletionBar(
            current: currentFluids / 1000, // Convert ml to L
            target: targetFluids,
            label: 'Fluids',
            unit: 'L',
          ),
        ],
      ),
    );
  }
}