import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    this.fontSize,
    this.trailing,
    this.padding = AppSpacing.buttonPadding,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isFullWidth;
  final IconData? icon;
  final double? height;

  /// The inset between the button's edge and its label. The default is the
  /// full-height button's; a shorter button passes less, because the label's
  /// line (16px at 1.2) does not shrink with the button and a 40px button
  /// under 24px of vertical padding clips its descenders.
  final EdgeInsets padding;

  /// Override the label size — for the compact, inline uses of the button
  /// (the plan bar's Review action), matching the prototype's
  /// `k-btn-primary--small`.
  final double? fontSize;

  /// Widget laid out after the label, inside the button — e.g. a price chip.
  /// It shares the label's centred row, so it never overlaps the text the way
  /// a stacked overlay does.
  final Widget? trailing;

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
          shape: RoundedRectangleBorder(borderRadius: AppRadius.buttonRadius),
          padding: padding,
          textStyle: AppTextStyles.buttonPrimary.copyWith(fontSize: fontSize),
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
                        fontSize: fontSize,
                      ),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
      ),
    );
  }
}

/// Small primary button variant.
///
/// 40px tall, so the label's line takes most of the height: the vertical
/// inset is [AppSpacing.xs] rather than the full-height button's
/// [AppSpacing.sm], which left 16px for a 19.2px line and cut the label's
/// descenders off ("Approve" on Shop with Kroger, 2026-09-16).
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xl,
        vertical: AppSpacing.xs,
      ),
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
          shape: RoundedRectangleBorder(borderRadius: AppRadius.circularRadius),
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
            : Icon(icon, size: size * 0.5, color: AppColors.textLight),
      ),
    );
  }
}
