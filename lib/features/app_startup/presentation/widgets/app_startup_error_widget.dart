import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../theme/app_theme.dart';
import '../../../../shared/widgets/primary_button.dart';

/// Error widget shown when app initialization fails
class AppStartupErrorWidget extends StatelessWidget {
  const AppStartupErrorWidget({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.baseCream,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Error icon
              Container(
                width: 120.w,
                height: 120.h,
                decoration: BoxDecoration(
                  color: AppTheme.highlight600.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(60.r),
                ),
                child: Icon(
                  Icons.error_outline,
                  size: 64.w,
                  color: AppTheme.highlight600,
                ),
              ),
              
              SizedBox(height: 32.h),
              
              // Error title
              Text(
                'Something went wrong',
                style: AppTheme.titleStyle.copyWith(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primary900,
                ),
                textAlign: TextAlign.center,
              ),
              
              SizedBox(height: 16.h),
              
              // Error message
              Text(
                message,
                style: AppTheme.textStyle.copyWith(
                  fontSize: 16.sp,
                  color: AppTheme.baseGrey,
                ),
                textAlign: TextAlign.center,
              ),
              
              SizedBox(height: 40.h),
              
              // Retry button
              PrimaryButton(
                text: 'Try Again',
                onPressed: onRetry,
                width: 200.w,
                height: 48.h,
              ),
              
              SizedBox(height: 24.h),
              
              // Help text
              Text(
                'If the problem persists, please check your internet connection.',
                style: AppTheme.noteStyle.copyWith(
                  fontSize: 14.sp,
                  color: AppTheme.baseGrey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}