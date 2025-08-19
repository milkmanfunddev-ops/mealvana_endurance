import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../theme/app_theme.dart';
import '../../domain/feedback_data.dart';

/// App feedback options component with radio buttons
/// Extracted from feedback drawer for reusability and improved height
class AppFeedbackOptions extends StatelessWidget {
  const AppFeedbackOptions({
    super.key,
    required this.selectedOption,
    required this.onOptionChanged,
    required this.suggestionsController,
  });

  final AppFeedbackOption? selectedOption;
  final Function(AppFeedbackOption) onOptionChanged;
  final TextEditingController suggestionsController;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ...AppFeedbackOption.values.map((option) {
          return Column(
            children: [
              _buildRadioOption(option),
              // Show text field for "has potential" option
              if (option == AppFeedbackOption.hasPotential && 
                  selectedOption == AppFeedbackOption.hasPotential)
                Padding(
                  padding: EdgeInsets.only(left: 32.w, top: 8.h),
                  child: TextField(
                    controller: suggestionsController,
                    style: TextStyle(
                      color: AppTheme.baseBlack,
                      fontSize: 16.sp,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Type your suggestions',
                      hintStyle: AppTheme.noteStyle.copyWith(
                        color: AppTheme.baseGrey,
                      ),
                      filled: true,
                      fillColor: AppTheme.baseWhite,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 12.h,
                      ),
                    ),
                    maxLines: 3,
                  ),
                ),
              SizedBox(height: 12.h), // Increased spacing for better height
            ],
          );
        }),
      ],
    );
  }

  Widget _buildRadioOption(AppFeedbackOption option) {
    final isSelected = selectedOption == option;
    
    return GestureDetector(
      onTap: () => onOptionChanged(option),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w), // Added padding for taller appearance
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary50.withValues(alpha: 0.3) : Colors.transparent,
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Row(
          children: [
            Container(
              width: 24.w,
              height: 24.h,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.primary900,
                  width: 2.0,
                ),
                color: isSelected ? AppTheme.primary900 : Colors.transparent,
              ),
              child: isSelected
                  ? Icon(
                      Icons.check,
                      color: AppTheme.baseWhite,
                      size: 16.sp,
                    )
                  : null,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                option.label,
                style: AppTheme.textStyle.copyWith(
                  color: AppTheme.baseBlack,
                  fontSize: 16.sp,
                  fontWeight: FontWeight.w500, // Slightly bolder
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}