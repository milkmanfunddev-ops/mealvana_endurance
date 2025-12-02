import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_theme.dart';

/// Custom app bar back button with primary900 background
/// Provides a consistent back button design across the app
/// Includes debouncing to prevent double-tap crashes
class CustomAppBarBackButton extends StatefulWidget {
  const CustomAppBarBackButton({
    super.key,
    this.onPressed,
  });

  final VoidCallback? onPressed;

  @override
  State<CustomAppBarBackButton> createState() => _CustomAppBarBackButtonState();
}

class _CustomAppBarBackButtonState extends State<CustomAppBarBackButton> {
  bool _isProcessing = false;

  void _handleTap() {
    // Prevent double-tap by checking if already processing
    if (_isProcessing) return;

    _isProcessing = true;

    // Execute the callback
    if (widget.onPressed != null) {
      widget.onPressed!();
    } else {
      Navigator.of(context).pop();
    }

    // Note: We don't reset _isProcessing because the widget will be
    // disposed after navigation. If navigation doesn't dispose the widget,
    // the button will remain disabled which is safer than allowing
    // repeated taps.
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(left: 12.w, top: 8.h, bottom: 8.h),
      child: Material(
        color: AppTheme.primary900,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: _handleTap,
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