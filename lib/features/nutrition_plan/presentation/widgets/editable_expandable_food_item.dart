import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/food_item_data.dart';
import '../../../../shared/widgets/food_icon.dart';
import '../../../../shared/services/logging_service.dart';

/// Expandable food item with quantity editing capabilities
/// Shows food icon, name, quantity with collapsible details and quantity controls
class EditableExpandableFoodItem extends StatefulWidget {
  const EditableExpandableFoodItem({
    super.key,
    required this.foodItem,
    required this.category,
    this.onQuantityChanged,
    this.onTap,
    this.isExpanded = false,
  });

  final FoodItemData foodItem;
  final String category;
  final Function(double newQuantity)? onQuantityChanged;
  final VoidCallback? onTap;
  final bool isExpanded;

  @override
  State<EditableExpandableFoodItem> createState() => _EditableExpandableFoodItemState();
}

class _EditableExpandableFoodItemState extends State<EditableExpandableFoodItem>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _controller;
  late Animation<double> _expandAnimation;
  late double _currentQuantity;
  late double _originalQuantity;
  Timer? _debounceTimer;
  bool _hasLocalChanges = false;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.isExpanded;
    _currentQuantity = _extractQuantityFromString(widget.foodItem.quantity);
    _originalQuantity = _currentQuantity;
    
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
    _debounceTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(EditableExpandableFoodItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only update local quantity if there are no local changes
    // This prevents losing local edits when parent state updates
    if (!_hasLocalChanges && oldWidget.foodItem.quantity != widget.foodItem.quantity) {
      final newQuantity = _extractQuantityFromString(widget.foodItem.quantity);
      setState(() {
        _currentQuantity = newQuantity;
        _originalQuantity = newQuantity;
      });
    }
  }

  /// Extract the numeric quantity from the quantity string (e.g., "2.5 cups" -> 2.5)
  double _extractQuantityFromString(String quantityString) {
    final match = RegExp(r'^([\d.]+)').firstMatch(quantityString);
    return match != null ? double.tryParse(match.group(1)!) ?? 1.0 : 1.0;
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

  void _incrementQuantity() {
    setState(() {
      _currentQuantity += 0.5;
      _hasLocalChanges = true;
    });
    _debouncedUpdateQuantity();
  }

  void _decrementQuantity() {
    if (_currentQuantity > 0.5) {
      setState(() {
        _currentQuantity -= 0.5;
        _hasLocalChanges = true;
      });
      _debouncedUpdateQuantity();
    }
  }

  void _debouncedUpdateQuantity() {
    // Cancel the previous timer if it's still running
    _debounceTimer?.cancel();
    
    // Start a new timer
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _updateQuantity();
    });
  }

  void _updateQuantity() {
    if (!_hasLocalChanges) return;
    
    AppLogger.instance.userAction('User updated food quantity',
      action: 'quantity_change',
      screen: 'current_plan',
      data: {
        'foodId': widget.foodItem.id,
        'foodName': widget.foodItem.name,
        'oldQuantity': _originalQuantity,
        'newQuantity': _currentQuantity,
        'category': widget.category,
      },
    );
    
    _hasLocalChanges = false;
    
    // Call the callback to sync to backend
    widget.onQuantityChanged?.call(_currentQuantity);
  }

  /// Get the appropriate display name based on quantity (singular vs plural)
  String _getDisplayName() {
    final isPlural = _currentQuantity != 1.0;

    // Priority: displayOverride > displayName/displayNamePlural > name
    if (widget.foodItem.displayOverride?.isNotEmpty == true) {
      return widget.foodItem.displayOverride!;
    }

    if (isPlural && widget.foodItem.displayNamePlural?.isNotEmpty == true) {
      return widget.foodItem.displayNamePlural!;
    }

    if (widget.foodItem.displayName?.isNotEmpty == true) {
      return widget.foodItem.displayName!;
    }

    return widget.foodItem.name;
  }

  /// Generate updated quantity display for the current quantity
  String _generateUpdatedQuantityDisplay() {
    final parts = widget.foodItem.quantity.split(' ');
    if (parts.length > 1) {
      final quantityStr = _currentQuantity == _currentQuantity.toInt() ?
          _currentQuantity.toInt().toString() :
          _currentQuantity.toStringAsFixed(1);
      final unit = parts.skip(1).join(' '); // e.g., "tablets", "bagel", "fl oz"
      final foodName = _getDisplayName().toLowerCase();

      // Check if the unit already contains the food name (to avoid duplication)
      if (unit.toLowerCase().contains(foodName) || foodName.contains(unit.toLowerCase())) {
        // Unit already contains food name (e.g., "bagel" contains "bagel")
        return '$quantityStr $unit';
      } else {
        // Unit doesn't contain food name, add it (e.g., "tablets" + "electrolyte tablet")
        return '$quantityStr $unit $foodName';
      }
    }
    return '${_currentQuantity == _currentQuantity.toInt() ? _currentQuantity.toInt().toString() : _currentQuantity.toStringAsFixed(1)} ${_getDisplayName().toLowerCase()}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Color(0xFFD6E0FF), // Correct light blue from design
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: AppTheme.primary900,
        ),
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
                    FoodIcon(
                      imageUrl: widget.foodItem.imageUrl,
                      size: 40.w,
                    ),
                    
                    SizedBox(width: 12.w),
                    
                    // Food Info
                    Expanded(
                      child: Text(
                        _generateUpdatedQuantityDisplay(),
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
                      
                      // Quantity Controls (from swap food screen)
                      Container(
                        padding: EdgeInsets.all(8.w),
                        decoration: BoxDecoration(
                          color: AppTheme.primary50.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Row(
                          children: [
                            Text(
                              'Quantity:',
                              style: AppTheme.textStyle.copyWith(
                                color: AppTheme.primary900,
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Spacer(),
                            // Decrement button
                            Container(
                              width: 36.w,
                              height: 36.w,
                              decoration: BoxDecoration(
                                color: AppTheme.primary900,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: Icon(
                                  Icons.remove,
                                  color: Colors.white,
                                  size: 18.sp,
                                ),
                                onPressed: _decrementQuantity,
                              ),
                            ),
                            // SizedBox(width: 16.w),
                            // Quantity display
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppTheme.primary100),
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                              child: Text(
                                _currentQuantity == _currentQuantity.toInt() 
                                    ? _currentQuantity.toInt().toString()
                                    : _currentQuantity.toStringAsFixed(1),
                                style: AppTheme.textStyle.copyWith(
                                  color: AppTheme.baseBlack,
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            // SizedBox(width: 16.w),
                            // Increment button
                            Container(
                              width: 36.w,
                              height: 36.w,
                              decoration: BoxDecoration(
                                color: AppTheme.primary900,
                                shape: BoxShape.circle,
                              ),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                icon: Icon(
                                  Icons.add,
                                  color: Colors.white,
                                  size: 18.sp,
                                ),
                                onPressed: _incrementQuantity,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      SizedBox(height: 16.h),
                      
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
                      
                      // Nutritional Info (dynamically calculated based on current quantity)
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
    // Use the original quantity for scaling calculations
    final scaleFactor = _currentQuantity / _originalQuantity;
    
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppTheme.baseWhite,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: AppTheme.baseGrey.withValues(alpha: 0.2),
        ),
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
                  '${(nutrition.calories! * scaleFactor).round()}',
                  AppTheme.caloriesColor,
                ),
              
              if (nutrition.carbs != null)
                _buildNutritionItem(
                  'Carbs',
                  '${(nutrition.carbs! * scaleFactor).round()}g',
                  AppTheme.carbsColor,
                ),
              
              if (nutrition.protein != null)
                _buildNutritionItem(
                  'Protein',
                  '${(nutrition.protein! * scaleFactor).round()}g',
                  AppTheme.proteinColor,
                ),
              
              if (nutrition.fat != null)
                _buildNutritionItem(
                  'Fat',
                  '${(nutrition.fat! * scaleFactor).round()}g',
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
          border: Border.all(
            color: color.withValues(alpha: 0.3),
          ),
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