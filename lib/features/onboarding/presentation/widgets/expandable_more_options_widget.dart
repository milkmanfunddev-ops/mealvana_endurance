import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../nutrition_plan/domain/food_item.dart';
import '../../../auth/domain/user_preferences.dart';
import '../../../../shared/widgets/food_preference_widget.dart';
import '../../../../theme/app_theme.dart';
import '../../../content/application/content_service.dart';
import '../../../content/domain/content_keys.dart';

/// Expandable widget that shows additional food options (show_in_preferences = false)
/// These foods default to "Avoid" preference and are collapsed by default
class ExpandableMoreOptionsWidget extends ConsumerStatefulWidget {
  const ExpandableMoreOptionsWidget({
    super.key,
    required this.additionalFoods,
    required this.selectedPreferences,
    required this.onPreferenceChanged,
  });

  final List<FoodItem> additionalFoods;
  final Map<String, FoodPreference> selectedPreferences;
  final Function(String foodName, FoodPreference preference) onPreferenceChanged;

  @override
  ConsumerState<ExpandableMoreOptionsWidget> createState() => _ExpandableMoreOptionsWidgetState();
}

class _ExpandableMoreOptionsWidgetState extends ConsumerState<ExpandableMoreOptionsWidget>
    with SingleTickerProviderStateMixin {
  bool _isExpanded = false;
  late AnimationController _animationController;
  late Animation<double> _expandAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _expandAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _toggleExpansion() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final content = ref.read(contentServiceProvider);

    // Get content-managed text labels (using fallback text for now)
    const showMoreText = 'Show more food options';
    const showLessText = 'Show less options';
    final likeLabel = content.getValue(
      ContentKeys.foodPreferencesOptionLike,
      defaultValue: 'Love',
    );
    final willingLabel = content.getValue(
      ContentKeys.foodPreferencesOptionWillingToTry,
      defaultValue: 'Willing to Try',
    );
    final dislikeLabel = content.getValue(
      ContentKeys.foodPreferencesOptionDislike,
      defaultValue: 'Avoid',
    );

    if (widget.additionalFoods.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        // Expandable header button
        Container(
          margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          decoration: BoxDecoration(
            color: AppTheme.baseWhite.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: AppTheme.primary100.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: InkWell(
            onTap: _toggleExpansion,
            borderRadius: BorderRadius.circular(12.r),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              child: Row(
                children: [
                  Icon(
                    Icons.restaurant_menu,
                    color: AppTheme.primary600,
                    size: 20.sp,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      _isExpanded ? showLessText : showMoreText,
                      style: AppTheme.textStyle.copyWith(
                        color: AppTheme.primary600,
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 300),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: AppTheme.primary600,
                      size: 24.sp,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Expandable content
        SizeTransition(
          sizeFactor: _expandAnimation,
          child: Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: Column(
              children: [
                SizedBox(height: 8.h),
                // Additional foods list
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: widget.additionalFoods.length,
                  separatorBuilder: (context, index) => SizedBox(height: 8.h),
                  itemBuilder: (context, index) {
                    final food = widget.additionalFoods[index];
                    final selected = widget.selectedPreferences[food.name] ??
                        FoodPreference.dislike; // Default to "Avoid" for additional foods

                    return FoodPreferenceChipItem(
                      food: food,
                      selected: selected,
                      likeLabel: likeLabel,
                      willingLabel: willingLabel,
                      dislikeLabel: dislikeLabel,
                      onChanged: (value) {
                        widget.onPreferenceChanged(food.name, value);
                      },
                    );
                  },
                ),
                SizedBox(height: 16.h),
              ],
            ),
          ),
        ),
      ],
    );
  }
}