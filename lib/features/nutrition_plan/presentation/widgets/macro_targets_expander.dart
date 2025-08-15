import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:mealvana_endurance/features/nutrition_plan/domain/nutrition_plan.dart';
import '../../../../theme/app_theme.dart';

/// Expandable macro targets section with + button
/// Shows calories, carbs, protein, fat breakdown
class MacroTargetsExpander extends StatefulWidget {
  const MacroTargetsExpander({
    super.key,
    required this.macroTargets,
    this.isExpanded = false,
  });

  final MacroTargets macroTargets;
  final bool isExpanded;

  @override
  State<MacroTargetsExpander> createState() => _MacroTargetsExpanderState();
}

class _MacroTargetsExpanderState extends State<MacroTargetsExpander>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _controller;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isExpanded;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    
    if (_isExpanded) {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleExpansion() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.baseWhite, // White background
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: AppTheme.primary900,
          width: 2.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4.r,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: Column(
          children: [
            // Header with + button
            InkWell(
              onTap: _toggleExpansion,
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Row(
                  children: [
                    // Title and subtitle
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Macro targets',
                            style: AppTheme.textStyle.copyWith(
                              color: AppTheme.primary900,
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    SizedBox(width: 12.w),
                    
                    // Plus icon (moved to right)
                    Container(
                      width: 32.w,
                      height: 32.h,
                      decoration: BoxDecoration(
                        color: AppTheme.highlight490, // Pink highlight color
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isExpanded ? Icons.remove : Icons.add,
                        color: AppTheme.primary900, // Dark blue icon
                        size: 20.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Expandable Content
            SizeTransition(
              sizeFactor: _expandAnimation,
              child: Container(
                width: double.infinity,
                color: AppTheme.baseCream.withValues(alpha: 0.3),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 20.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Divider
                      Container(
                        height: 1,
                        color: AppTheme.baseGrey.withValues(alpha: 0.2),
                        margin: EdgeInsets.only(bottom: 16.h),
                      ),
                      
                      // Alex's design macro items
                      _buildMacroItem(
                        'Carbs: ${widget.macroTargets.carbs} grams',
                        Icons.grain,
                        AppTheme.warning500,
                      ),
                      
                      SizedBox(height: 12.h),
                      
                      _buildMacroItem(
                        'Sodium: 800-1200mg',
                        Icons.local_fire_department,
                        AppTheme.highlight600Alt,
                      ),
                      
                      SizedBox(height: 12.h),
                      
                      _buildMacroItem(
                        'Fluids: 40-48 oz',
                        Icons.water_drop,
                        AppTheme.primary600,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMacroItem(String text, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          width: 32.w,
          height: 32.h,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: color,
            size: 18.sp,
          ),
        ),
        SizedBox(width: 12.w),
        Text(
          text,
          style: AppTheme.textStyle.copyWith(
            color: AppTheme.baseBlack,
            fontSize: 15.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

}