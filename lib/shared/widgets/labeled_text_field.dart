import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_theme.dart';

/// Labeled text input field component matching Alex's design
/// Used for distance, pace, and other form inputs
class LabeledTextField extends StatefulWidget {
  const LabeledTextField({
    super.key,
    required this.label,
    this.hint,
    this.controller,
    this.onChanged,
    this.keyboardType,
    this.suffixText,
    this.prefixIcon,
    this.validator,
    this.enabled = true,
    this.maxLines = 1,
  });

  final String label;
  final String? hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final TextInputType? keyboardType;
  final String? suffixText;
  final Widget? prefixIcon;
  final String? Function(String?)? validator;
  final bool enabled;
  final int maxLines;

  @override
  State<LabeledTextField> createState() => _LabeledTextFieldState();
}

class _LabeledTextFieldState extends State<LabeledTextField> {
  bool _isFocused = false;
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      setState(() {
        _isFocused = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Text(
          widget.label,
          style: AppTheme.noteStyle.copyWith(
            color: AppTheme.baseBlack,
            fontSize: 16.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 8.h),
        
        // Text Field
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: AppTheme.baseWhite,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: _isFocused
                  ? AppTheme.primary600
                  : AppTheme.baseGrey.withValues(alpha: 0.3),
              width: _isFocused ? 2 : 1,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: AppTheme.primary600.withValues(alpha: 0.1),
                      blurRadius: 8.r,
                      offset: Offset(0, 2.h),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4.r,
                      offset: Offset(0, 1.h),
                    ),
                  ],
          ),
          child: TextFormField(
            controller: widget.controller,
            focusNode: _focusNode,
            onChanged: widget.onChanged,
            keyboardType: widget.keyboardType,
            validator: widget.validator,
            enabled: widget.enabled,
            maxLines: widget.maxLines,
            style: AppTheme.textStyle.copyWith(
              color: AppTheme.baseBlack,
              fontSize: 16.sp,
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: AppTheme.textStyle.copyWith(
                color: AppTheme.baseGrey.withValues(alpha: 0.6),
                fontSize: 16.sp,
              ),
              suffixText: widget.suffixText,
              suffixStyle: AppTheme.textStyle.copyWith(
                color: AppTheme.baseGrey,
                fontSize: 14.sp,
              ),
              prefixIcon: widget.prefixIcon,
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16.w,
                vertical: 16.h,
              ),
            ),
          ),
        ),
      ],
    );
  }
}