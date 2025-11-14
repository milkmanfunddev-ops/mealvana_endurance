import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_spacing.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_text_styles.dart';

/// Primary button for Kyle's design system
/// Orange background with fully rounded corners (100px radius from Figma)
class KylePrimaryButton extends ConsumerWidget {
  const KylePrimaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isFullWidth = true,
    this.icon,
    this.height,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isFullWidth;
  final IconData? icon;
  final double? height;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      height: height ?? AppSizes.buttonHeightPrimary,
      width: isFullWidth ? double.infinity : null,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: AppColors.textLight,
          disabledBackgroundColor: Colors.orange.withOpacity(0.4),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.buttonRadius,
          ),
          padding: AppSpacing.buttonPadding,
          textStyle: AppTextStyles.buttonPrimary,
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.textLight,
                  ),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: AppIconSizes.button,
                      color: AppColors.textLight,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  Flexible(
                    child: Text(
                      text,
                      style: AppTextStyles.buttonPrimary.copyWith(
                        color: AppColors.textLight,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Small primary button variant
class KylePrimaryButtonSmall extends ConsumerWidget {
  const KylePrimaryButtonSmall({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return KylePrimaryButton(
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      isFullWidth: false,
      icon: icon,
      height: 40,
    );
  }
}

/// Icon-only primary button
class KylePrimaryIconButton extends ConsumerWidget {
  const KylePrimaryIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.isLoading = false,
    this.size = AppSizes.buttonIconSize,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: size,
      height: size,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.orange,
          foregroundColor: AppColors.textLight,
          disabledBackgroundColor: AppColors.orange.withOpacity(0.4),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.circularRadius,
          ),
          padding: EdgeInsets.zero,
        ),
        child: isLoading
            ? SizedBox(
                width: size * 0.4,
                height: size * 0.4,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppColors.textLight,
                  ),
                ),
              )
            : Icon(
                icon,
                size: size * 0.5,
                color: AppColors.textLight,
              ),
      ),
    );
  }
}