import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_spacing.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_text_styles.dart';

/// Secondary button for Kyle's design system
/// Outlined style with Orange or Blackberry borders
class KyleSecondaryButton extends ConsumerWidget {
  const KyleSecondaryButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.isFullWidth = true,
    this.icon,
    this.height,
    this.fontSize,
    this.variant = SecondaryButtonVariant.orange,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isFullWidth;
  final IconData? icon;
  final double? height;

  /// Override the label size — for the compact, inline uses of the button
  /// (the plan bar's Review action), matching the prototype's
  /// `k-btn-primary--small`.
  final double? fontSize;
  final SecondaryButtonVariant variant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = _getColorsForVariant(variant, context);

    return SizedBox(
      height: height ?? AppSizes.buttonHeightPrimary,
      width: isFullWidth ? double.infinity : null,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: colors.foreground,
          disabledForegroundColor: colors.foreground.withOpacity(0.4),
          side: BorderSide(color: colors.border, width: 2),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.buttonRadius),
          padding: AppSpacing.buttonPadding,
          textStyle: AppTextStyles.buttonPrimary.copyWith(fontSize: fontSize),
        ),
        child: isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(colors.foreground),
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
                      color: colors.foreground,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                  ],
                  Flexible(
                    child: Text(
                      text,
                      style: AppTextStyles.buttonPrimary.copyWith(
                        color: colors.foreground,
                        fontSize: fontSize,
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

  static _ButtonColors _getColorsForVariant(
    SecondaryButtonVariant variant,
    BuildContext context,
  ) {
    switch (variant) {
      case SecondaryButtonVariant.orange:
        return _ButtonColors(
          foreground: AppColors.orange,
          border: AppColors.orange,
        );
      case SecondaryButtonVariant.blackberry:
        return _ButtonColors(
          foreground: AppColors.textLight,
          border: AppColors.textLight,
        );
      case SecondaryButtonVariant.light:
        final onSurface = Theme.of(context).colorScheme.onSurface;
        return _ButtonColors(foreground: onSurface, border: onSurface);
      case SecondaryButtonVariant.dragonfruit:
        return _ButtonColors(
          foreground: AppColors.dragonfruitLight,
          border: AppColors.dragonfruit,
        );
    }
  }
}

/// Small secondary button variant
class KyleSecondaryButtonSmall extends ConsumerWidget {
  const KyleSecondaryButtonSmall({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.icon,
    this.variant = SecondaryButtonVariant.orange,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final IconData? icon;
  final SecondaryButtonVariant variant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return KyleSecondaryButton(
      text: text,
      onPressed: onPressed,
      isLoading: isLoading,
      isFullWidth: false,
      icon: icon,
      height: 44,
      variant: variant,
    );
  }
}

/// Icon-only secondary button
class KyleSecondaryIconButton extends ConsumerWidget {
  const KyleSecondaryIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.isLoading = false,
    this.size = AppSizes.buttonIconSize,
    this.variant = SecondaryButtonVariant.orange,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double size;
  final SecondaryButtonVariant variant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = KyleSecondaryButton._getColorsForVariant(variant, context);

    return SizedBox(
      width: size,
      height: size,
      child: OutlinedButton(
        onPressed: isLoading ? null : onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: colors.foreground,
          disabledForegroundColor: colors.foreground.withOpacity(0.4),
          side: BorderSide(color: colors.border, width: 2),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.circularRadius),
          padding: EdgeInsets.zero,
        ),
        child: isLoading
            ? SizedBox(
                width: size * 0.4,
                height: size * 0.4,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(colors.foreground),
                ),
              )
            : Icon(icon, size: size * 0.5, color: colors.foreground),
      ),
    );
  }
}

/// Secondary button variants
enum SecondaryButtonVariant {
  /// Orange outline for emphasis actions
  orange,

  /// Blackberry outline for neutral actions
  blackberry,

  /// Theme-aware outline that adapts to current brightness
  light,

  /// Dragonfruit outline for destructive actions (Remove, Delete).
  dragonfruit,
}

/// Helper class for button colors
class _ButtonColors {
  const _ButtonColors({required this.foreground, required this.border});

  final Color foreground;
  final Color border;
}
