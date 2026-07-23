import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_theme.dart';

/// Secondary button component with transparent background and primary900 text
/// Used for secondary actions like "Cancel", "Skip", etc.
class SecondaryButton extends StatefulWidget {
  const SecondaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.width,
    this.height,
    this.fontSize,
  });

  final String text;
  final VoidCallback? onPressed;
  final double? width;
  final double? height;
  final double? fontSize;

  @override
  State<SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<SecondaryButton> {
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
          color: _isPressed
              ? AppTheme.highlight490.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(28.r),
          border: Border.all(color: AppTheme.highlight490, width: 1),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onPressed,
            borderRadius: BorderRadius.circular(28.r),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28.r),
              ),
              child: Center(
                child: Text(
                  widget.text,
                  style: AppTheme.subtitleStyle.copyWith(
                    color: AppTheme.primary900,
                    fontSize: widget.fontSize ?? 18.sp,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),
      ).animate().scale(duration: 150.ms, curve: Curves.easeInOut),
    );
  }
}
