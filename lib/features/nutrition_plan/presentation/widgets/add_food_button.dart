import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../theme/app_theme.dart';

class AddFoodButton extends StatelessWidget {
  final VoidCallback onPressed;

  const AddFoodButton({
    super.key,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(20.r),
      child: Container(
        width: 40.w,
        height: 40.w,
        decoration: BoxDecoration(
          color: AppTheme.highlight100,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.add,
          color: AppTheme.primary900,
          size: 24.sp,
        ),
      ),
    );
  }
}