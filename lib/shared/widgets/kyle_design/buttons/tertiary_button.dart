import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_spacing.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_text_styles.dart';


/// Tertiary button for Kyle's design system
/// Text only with Dragonfruit color
class KyleTertiaryButton extends ConsumerWidget {
  const KyleTertiaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.alignment = MainAxisAlignment.center,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final MainAxisAlignment alignment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton(
      onPressed: isLoading ? null : onPressed,
      style: TextButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.dragonfruit,
        disabledForegroundColor: AppColors.dragonfruit.withOpacity(0.4),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.smRadius,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        textStyle: AppTextStyles.buttonTertiary,
      ),
      child: isLoading
          ? SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(
                strokeWidth: 1.5,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.dragonfruit),
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: alignment,
              children: [
                if (icon != null) ...[
                  Icon(
                    icon,
                    size: AppIconSizes.sm,
                    color: AppColors.dragonfruit,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                ],
                Text(
                  text,
                  style: AppTextStyles.buttonTertiary.copyWith(
                    color: AppColors.dragonfruit,
                  ),
                ),
              ],
            ),
    );
  }
}

/// Tertiary button with underline
class KyleTertiaryButtonUnderlined extends ConsumerWidget {
  const KyleTertiaryButtonUnderlined({
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
    return InkWell(
      onTap: isLoading ? null : onPressed,
      borderRadius: AppRadius.smRadius,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
        child: isLoading
            ? SizedBox(
                height: 16,
                width: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.dragonfruit),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: AppIconSizes.sm,
                      color: AppColors.dragonfruit,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  Text(
                    text,
                    style: AppTextStyles.buttonTertiary.copyWith(
                      color: AppColors.dragonfruit,
                      decoration: TextDecoration.underline,
                      decorationColor: AppColors.dragonfruit,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Small tertiary button for tight spaces
class KyleTertiaryButtonSmall extends ConsumerWidget {
  const KyleTertiaryButtonSmall({
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
    return TextButton(
      onPressed: isLoading ? null : onPressed,
      style: TextButton.styleFrom(
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.dragonfruit,
        disabledForegroundColor: AppColors.dragonfruit.withOpacity(0.4),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.smRadius,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xxs,
        ),
        textStyle: AppTextStyles.smallLabel,
      ),
      child: isLoading
          ? SizedBox(
              height: 12,
              width: 12,
              child: CircularProgressIndicator(
                strokeWidth: 1,
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.dragonfruit),
              ),
            )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(
                      icon,
                      size: AppIconSizes.xs,
                      color: AppColors.dragonfruit,
                    ),
                    const SizedBox(width: AppSpacing.xxs),
                  ],
                  Text(
                    text,
                    style: AppTextStyles.smallLabel.copyWith(
                      color: AppColors.dragonfruit,
                    ),
                  ),
                ],
              ),
    );
  }
}

/// Icon-only tertiary button
class KyleTertiaryIconButton extends ConsumerWidget {
  const KyleTertiaryIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.isLoading = false,
    this.size = AppIconSizes.md,
    this.padding,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double size;
  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: padding ?? const EdgeInsets.all(AppSpacing.sm),
      child: InkWell(
        onTap: isLoading ? null : onPressed,
        borderRadius: AppRadius.circularRadius,
        child: isLoading
            ? SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.dragonfruit),
                ),
              )
            : Icon(
                icon,
                size: size,
                color: AppColors.dragonfruit,
              ),
      ),
    );
  }
}