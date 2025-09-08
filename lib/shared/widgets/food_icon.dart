import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_theme.dart';

/// Food icon component for displaying food images from online URLs
/// Used in plan items and food selection
class FoodIcon extends StatelessWidget {
  const FoodIcon({
    super.key,
    this.imageUrl,
    this.size,
    this.backgroundColor,
    this.borderColor,
    this.borderWidth,
  });

  final String? imageUrl;
  final double? size;
  final Color? backgroundColor;
  final Color? borderColor;
  final double? borderWidth;

  @override
  Widget build(BuildContext context) {
    final iconSize = size ?? 48.w;
    
    // Debug logging
    if (imageUrl == null || imageUrl!.isEmpty) {
      print('   ⚠️  No image URL provided, showing fallback icon');
    }
    
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
        child: imageUrl != null && imageUrl!.isNotEmpty
            ? Image.network(
                imageUrl!,
                width: iconSize * 0.8,
                height: iconSize * 0.8,
                fit: BoxFit.cover,
                headers: const {
                  'User-Agent': 'Mozilla/5.0 (compatible; Flutter App)',
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) {
                    return child;
                  }
                  return Center(
                    child: CircularProgressIndicator(
                      value: loadingProgress.expectedTotalBytes != null
                          ? loadingProgress.cumulativeBytesLoaded /
                              loadingProgress.expectedTotalBytes!
                          : null,
                      strokeWidth: 2.0,
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primary600),
                    ),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  print('❌ FoodIcon: Failed to load image: $imageUrl');
                  print('   Error: $error');
                  print('   StackTrace: $stackTrace');
                  // Fallback icon if image fails to load
                  return Icon(
                    Icons.restaurant,
                    size: iconSize * 0.6,
                    color: AppTheme.baseGrey,
                  );
                },
              )
            : Icon(
                Icons.restaurant,
                size: iconSize * 0.6,
                color: AppTheme.baseGrey,
              ),
      ),
    );
  }
}