import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../theme/app_theme.dart';

/// Hero image component with blue border effect
/// Displays the woman running image with app styling
class HeroImage extends StatelessWidget {
  const HeroImage({
    super.key,
    this.imagePath = 'assets/images/woman_running.png',
    this.height,
    this.width,
    this.borderRadius,
    this.showBorder = true,
    this.borderWidth,
    this.onTap,
  });

  final String imagePath;
  final double? height;
  final double? width;
  final double? borderRadius;
  final bool showBorder;
  final double? borderWidth;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final imageHeight = height ?? 200.h;
    final imageWidth = width ?? double.infinity;
    final radius = borderRadius ?? 16.r;
    final borderThickness = borderWidth ?? 3.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: imageWidth,
        height: imageHeight,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: showBorder
              ? Border.all(
                  color: AppTheme.primary600,
                  width: borderThickness,
                )
              : null,
          boxShadow: showBorder
              ? [
                  BoxShadow(
                    color: AppTheme.primary600.withValues(alpha: 0.15),
                    blurRadius: 20.r,
                    offset: Offset(0, 8.h),
                  ),
                  BoxShadow(
                    color: AppTheme.primary600.withValues(alpha: 0.05),
                    blurRadius: 40.r,
                    offset: Offset(0, 16.h),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 12.r,
                    offset: Offset(0, 4.h),
                  ),
                ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius - (showBorder ? borderThickness / 2 : 0)),
          child: Stack(
            children: [
              // Main Image
              Positioned.fill(
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      decoration: BoxDecoration(
                        color: AppTheme.baseCream,
                        borderRadius: BorderRadius.circular(radius - (showBorder ? borderThickness / 2 : 0)),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.directions_run,
                            size: 48.sp,
                            color: AppTheme.primary600,
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            'Image not found',
                            style: AppTheme.noteStyle.copyWith(
                              color: AppTheme.baseGrey,
                              fontSize: 14.sp,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              
              // Gradient overlay for better text visibility if needed
              if (showBorder)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(radius - (showBorder ? borderThickness / 2 : 0)),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.transparent,
                          AppTheme.primary600.withValues(alpha: 0.05),
                        ],
                      ),
                    ),
                  ),
                ),
              
              // Tap indicator
              if (onTap != null)
                Positioned(
                  top: 16.h,
                  right: 16.w,
                  child: Container(
                    width: 32.w,
                    height: 32.h,
                    decoration: BoxDecoration(
                      color: AppTheme.baseWhite.withValues(alpha: 0.9),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 4.r,
                          offset: Offset(0, 2.h),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.zoom_in,
                      size: 18.sp,
                      color: AppTheme.primary600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Large hero image variant for main screens
class LargeHeroImage extends StatelessWidget {
  const LargeHeroImage({
    super.key,
    this.imagePath = 'assets/images/woman.png',
    this.onTap,
  });

  final String imagePath;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 300.h,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20.r),
        child: Image.asset(
          imagePath,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              decoration: BoxDecoration(
                color: AppTheme.baseCream,
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.directions_run,
                    size: 48.sp,
                    color: AppTheme.primary600,
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Image not found',
                    style: AppTheme.noteStyle.copyWith(
                      color: AppTheme.baseGrey,
                      fontSize: 14.sp,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Compact hero image variant for cards
class CompactHeroImage extends StatelessWidget {
  const CompactHeroImage({
    super.key,
    this.onTap,
  });

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return HeroImage(
      height: 120.h,
      borderRadius: 12.r,
      borderWidth: 2.0,
      onTap: onTap,
    );
  }
}