import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_theme.dart';

/// Food icon component for displaying food images consistently
/// Used in plan items and food selection
class FoodIcon extends StatelessWidget {
  const FoodIcon({
    super.key,
    required this.assetPath,
    this.size,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth,
  });

  final String assetPath;
  final double? size;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? borderWidth;

  @override
  Widget build(BuildContext context) {
    final iconSize = size ?? 48.w;
    
    return Container(
      width: iconSize,
      height: iconSize,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppTheme.baseWhite,
        shape: BoxShape.circle,
        border: borderColor != null
            ? Border.all(
                color: borderColor!,
                width: borderWidth ?? 2.0,
              )
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4.r,
            offset: Offset(0, 2.h),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.asset(
          assetPath,
          width: iconSize * 0.8,
          height: iconSize * 0.8,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            // Fallback icon if image fails to load
            return Icon(
              Icons.restaurant,
              size: iconSize * 0.6,
              color: AppTheme.baseGrey,
            );
          },
        ),
      ),
    );
  }
}