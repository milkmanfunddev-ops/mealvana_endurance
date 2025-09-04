import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_theme.dart';

/// Increment/Decrement widget for numeric input values
/// Features circular buttons with + and - for adjusting values
class IncrementDecrementWidget extends StatelessWidget {
  const IncrementDecrementWidget({
    super.key,
    required this.label,
    required this.value,
    required this.onIncrement,
    required this.onDecrement,
    this.formatValue,
  });

  final String label;
  final String value;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;
  final String Function(String)? formatValue;

  @override
  Widget build(BuildContext context) {
    final displayValue = formatValue?.call(value) ?? value;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      // mainAxisSize: MainAxisAlignment.start,
      children: [
        Text(
          label,
          textAlign: TextAlign.start,
          style: AppTheme.subtitleStyle.copyWith(
            fontSize: 18.sp,
            color: AppTheme.primary900,
          ),
        ),
        SizedBox(height: 16.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Decrement Button
            _IncrementDecrementButton(
              icon: Icons.remove,
              onPressed: onDecrement,
            ),
            SizedBox(width: 40.w),
            // Value Display
            SizedBox(
              width: 120.w,
              child: Text(
                displayValue,
                style: AppTheme.textStyle.copyWith(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary900,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(width: 40.w),
            // Increment Button
            _IncrementDecrementButton(
              icon: Icons.add,
              onPressed: onIncrement,
            ),
          ],
        ),
      ],
    );
  }
}

/// Individual increment/decrement button component
class _IncrementDecrementButton extends StatelessWidget {
  const _IncrementDecrementButton({
    required this.icon,
    required this.onPressed,
  });

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40.w,
      height: 40.h,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppTheme.highlight490,
          width: 1.5,
        ),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: AppTheme.highlight490.withValues(alpha: 0.1),
            blurRadius: 6.r,
            offset: Offset(0, 1.h),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(20.r),
          child: Icon(
            icon,
            size: 16.sp,
            color: AppTheme.primary900,
          ),
        ),
      ),
    );
  }
}