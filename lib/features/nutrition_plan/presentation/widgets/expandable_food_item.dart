import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/food_item_data.dart';
import '../../../../shared/widgets/food_icon.dart';

/// Expandable food item component matching Alex's design
/// Shows food icon, name, quantity with collapsible details
class ExpandableFoodItem extends StatefulWidget {
  const ExpandableFoodItem({
    super.key,
    required this.foodItem,
    this.onTap,
    this.isExpanded = false,
  });

  final FoodItemData foodItem;
  final VoidCallback? onTap;
  final bool isExpanded;

  @override
  State<ExpandableFoodItem> createState() => _ExpandableFoodItemState();
}

class _ExpandableFoodItemState extends State<ExpandableFoodItem>
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
    widget.onTap?.call();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFFD6E0FF), // Correct light blue from Alex's design
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: AppTheme.primary900),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary600.withValues(alpha: 0.1),
            blurRadius: 4.r,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: Column(
          children: [
            // Main item row
            InkWell(
              onTap: _toggleExpansion,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 6.h),
                child: Row(
                  children: [
                    // Food Icon
                    FoodIcon(imageUrl: widget.foodItem.imageUrl, size: 40.w),

                    SizedBox(width: 12.w),

                    // Food Info
                    Expanded(
                      child: Text(
                        widget
                            .foodItem
                            .quantity, // Now contains full description like "1 cup cooked oatmeal"
                        style: AppTheme.textStyle.copyWith(
                          color: AppTheme.primary900,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    // Expand/Collapse Icon
                    AnimatedRotation(
                      turns: _isExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: AppTheme.primary900,
                        size: 24.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Expandable Details
            SizeTransition(
              sizeFactor: _expandAnimation,
              child: Container(
                width: double.infinity,
                color: AppTheme.primary50.withValues(alpha: 0.8),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Divider
                      Container(
                        height: 1,
                        color: AppTheme.baseGrey.withValues(alpha: 0.2),
                        margin: EdgeInsets.only(bottom: 16.h),
                      ),

                      // Description
                      if (widget.foodItem.description != null) ...[
                        Text(
                          widget.foodItem.description!,
                          style: AppTheme.textStyle.copyWith(
                            color: AppTheme.baseBlack,
                            fontSize: 14.sp,
                          ),
                        ),
                        SizedBox(height: 12.h),
                      ],

                      // Instructions
                      if (widget.foodItem.instructions != null) ...[
                        Container(
                          padding: EdgeInsets.all(12.w),
                          decoration: BoxDecoration(
                            color: AppTheme.primary50,
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 16.sp,
                                color: AppTheme.primary600,
                              ),
                              SizedBox(width: 8.w),
                              Expanded(
                                child: Text(
                                  widget.foodItem.instructions!,
                                  style: AppTheme.noteStyle.copyWith(
                                    color: AppTheme.primary600,
                                    fontSize: 13.sp,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: 12.h),
                      ],

                      // Nutritional Info
                      if (widget.foodItem.nutritionalInfo != null)
                        _buildNutritionInfo(),
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

  Widget _buildNutritionInfo() {
    final nutrition = widget.foodItem.nutritionalInfo!;

    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppTheme.baseWhite,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: AppTheme.baseGrey.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Nutrition Facts',
            style: AppTheme.subtitleStyle.copyWith(
              color: AppTheme.baseBlack,
              fontSize: 14.sp,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8.h),

          Row(
            children: [
              if (nutrition.calories != null)
                _buildNutritionItem(
                  'Calories',
                  '${nutrition.calories}',
                  AppTheme.caloriesColor,
                ),

              if (nutrition.carbs != null)
                _buildNutritionItem(
                  'Carbs',
                  '${nutrition.carbs}g',
                  AppTheme.carbsColor,
                ),

              if (nutrition.protein != null)
                _buildNutritionItem(
                  'Protein',
                  '${nutrition.protein}g',
                  AppTheme.proteinColor,
                ),

              if (nutrition.fat != null)
                _buildNutritionItem(
                  'Fat',
                  '${nutrition.fat}g',
                  AppTheme.fatsColor,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNutritionItem(String label, String value, Color color) {
    return Expanded(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 2.w),
        padding: EdgeInsets.symmetric(vertical: 6.h, horizontal: 8.w),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(6.r),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: AppTheme.textStyle.copyWith(
                color: color,
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              label,
              style: AppTheme.noteStyle.copyWith(
                color: color.withValues(alpha: 0.8),
                fontSize: 10.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
