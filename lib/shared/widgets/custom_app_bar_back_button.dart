import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_theme.dart';

/// Custom app bar back button with primary900 background
/// Provides a consistent back button design across the app
class CustomAppBarBackButton extends StatelessWidget {
  const CustomAppBarBackButton({
    super.key,
    this.onPressed,
  });

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(left: 12.w, top: 8.h, bottom: 8.h),
      child: Material(
        color: AppTheme.primary900,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed ?? () => Navigator.of(context).pop(),
          customBorder: const CircleBorder(),
          child: Container(
            width: 40.w,
            height: 40.h,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(right: 2.w),
                child: Icon(
                  Icons.arrow_back,
                  color: AppTheme.baseWhite,
                  size: 20.sp,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}