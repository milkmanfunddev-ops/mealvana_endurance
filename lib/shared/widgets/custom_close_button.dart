import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_theme.dart';

/// Custom close button with white X and highlight 290 background
class CustomCloseButton extends StatelessWidget {
  const CustomCloseButton({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32.w,
        height: 32.h,
        decoration: BoxDecoration(
          color: AppTheme.primary900,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.close,
          color: AppTheme.baseWhite,
          size: 18.sp,
        ),
      ),
    );
  }
}