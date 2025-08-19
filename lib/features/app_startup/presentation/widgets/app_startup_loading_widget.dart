import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../theme/app_theme.dart';

/// Loading widget shown during app initialization
class AppStartupLoadingWidget extends StatelessWidget {
  const AppStartupLoadingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.baseCream,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App logo/icon placeholder
            Container(
              width: 120.w,
              height: 120.h,
              decoration: BoxDecoration(
                color: AppTheme.primary900.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(60.r),
              ),
              child: Icon(
                Icons.run_circle,
                size: 64.w,
                color: AppTheme.primary900,
              ),
            ),
            
            SizedBox(height: 40.h),
            
            // App title
            Text(
              'Mealvana Endurance',
              style: AppTheme.titleStyle.copyWith(
                fontSize: 24.sp,
                fontWeight: FontWeight.bold,
                color: AppTheme.primary900,
              ),
              textAlign: TextAlign.center,
            ),
            
            SizedBox(height: 16.h),
            
            // Loading message
            Text(
              'Preparing your nutrition plans...',
              style: AppTheme.textStyle.copyWith(
                fontSize: 16.sp,
                color: AppTheme.baseGrey,
              ),
              textAlign: TextAlign.center,
            ),
            
            SizedBox(height: 40.h),
            
            // Loading indicator
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary900),
              strokeWidth: 3.0,
            ),
          ],
        ),
      ),
    );
  }
}