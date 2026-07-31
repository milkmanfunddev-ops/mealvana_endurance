import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_theme.dart';

class CompletionBar extends StatelessWidget {
  final double current;
  final double target;
  final String label;
  final String unit;

  const CompletionBar({
    super.key,
    required this.current,
    required this.target,
    required this.label,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final percentage = target > 0 ? (current / target).clamp(0.0, 1.0) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTheme.noteStyle.copyWith(
            color: AppTheme.primary900,
            fontSize: 14.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 8.h),
        LayoutBuilder(
          builder: (context, constraints) {
            return Stack(
              children: [
                Container(
                  height: 8.h,
                  decoration: BoxDecoration(
                    color: AppTheme.baseGrey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                ),
                Container(
                  height: 8.h,
                  width: constraints.maxWidth * percentage,
                  decoration: BoxDecoration(
                    color: AppTheme.primary600,
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                ),
              ],
            );
          },
        ),
        SizedBox(height: 4.h),
        Text(
          '${current.toStringAsFixed(0)}/${target.toStringAsFixed(0)} $unit',
          style: AppTheme.noteStyle.copyWith(
            color: AppTheme.baseGrey,
            fontSize: 12.sp,
          ),
        ),
      ],
    );
  }
}
