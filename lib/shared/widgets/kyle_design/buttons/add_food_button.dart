import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_spacing.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_text_styles.dart';

/// Add food button for Kyle's design system
/// Orange outlined button with plus icon
class KyleAddFoodButton extends ConsumerWidget {
  const KyleAddFoodButton({
    super.key,
    required this.onPressed,
    this.text = 'Add Food',
    this.backgroundColor,
    this.textColor,
  });

  final VoidCallback onPressed;
  final String text;
  final Color? backgroundColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bgColor = backgroundColor ?? Colors.transparent;
    final txtColor = textColor ?? Colors.orange;
    
    return Material(
      color: bgColor,
      borderRadius: AppRadius.buttonRadius,
      child: InkWell(
        onTap: onPressed,
        borderRadius: AppRadius.buttonRadius,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: AppRadius.buttonRadius,
            border: Border.all(
              color: Colors.orange,
              width: 2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                FontAwesomeIcons.plus,
                size: AppIconSizes.controlIcon,
                color: txtColor,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                text,
                style: AppTextStyles.buttonPrimary.copyWith(
                  color: txtColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Add food button with full width
class KyleAddFoodButtonFullWidth extends ConsumerWidget {
  const KyleAddFoodButtonFullWidth({
    super.key,
    required this.onPressed,
    this.text = 'Add Food',
    this.backgroundColor,
    this.textColor,
  });

  final VoidCallback onPressed;
  final String text;
  final Color? backgroundColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      child: KyleAddFoodButton(
        onPressed: onPressed,
        text: text,
        backgroundColor: backgroundColor,
        textColor: textColor,
      ),
    );
  }
}