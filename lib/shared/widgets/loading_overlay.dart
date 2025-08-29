import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_theme.dart';

/// Simple reusable loading overlay with a spinner in the middle of the screen
/// Can be used anywhere in the app when showing loading state
class LoadingOverlay extends StatelessWidget {
  final Color? backgroundColor;
  final Color? spinnerColor;
  
  const LoadingOverlay({
    super.key,
    this.backgroundColor,
    this.spinnerColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: backgroundColor ?? AppTheme.baseBlack.withValues(alpha: 0.3),
      child: Center(
        child: Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: AppTheme.baseWhite,
            borderRadius: BorderRadius.circular(12.r),
            boxShadow: [
              BoxShadow(
                color: AppTheme.baseBlack.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(
              spinnerColor ?? AppTheme.primary600,
            ),
          ),
        ),
      ),
    );
  }
}