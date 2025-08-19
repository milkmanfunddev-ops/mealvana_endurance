import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';

/// Primary button component matching Alex's blue button design
/// Used for main actions like "Generate Plan", "Submit", etc.
class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.isLoading = false,
    this.width,
    this.height,
    this.fontSize,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double? width;
  final double? height;
  final double? fontSize;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: widget.width ?? 280.w,
        height: widget.height ?? 56.h,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: widget.onPressed == null
                ? [Colors.grey.shade300, Colors.grey.shade400]
                : _isPressed
                    ? [AppTheme.primary900.withValues(alpha: 0.8), AppTheme.primary900]
                    : [AppTheme.primary900, AppTheme.primary900],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(28.r),
          boxShadow: _isPressed || widget.onPressed == null
              ? []
              : [
                  BoxShadow(
                    color: AppTheme.primary900.withValues(alpha: 0.3),
                    blurRadius: 12.r,
                    offset: Offset(0, 4.h),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.isLoading ? null : widget.onPressed,
            borderRadius: BorderRadius.circular(28.r),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28.r),
              ),
              child: Center(
                child: widget.isLoading
                    ? SizedBox(
                        width: 24.w,
                        height: 24.h,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppTheme.baseWhite,
                          ),
                        ),
                      )
                    : Text(
                        widget.text,
                        style: AppTheme.subtitleStyle.copyWith(
                          color: AppTheme.highlight490,
                          fontSize: widget.fontSize ?? 18.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ).animate().scale(
        duration: 150.ms,
        curve: Curves.easeInOut,
      ),
    );
  }
}