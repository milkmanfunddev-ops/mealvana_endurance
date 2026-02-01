import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_text_styles.dart';

/// Standardized input field widget matching Figma design specifications
///
/// Design specs:
/// - Background: AppColors.blackberryLight (solid, not transparent)
/// - Border radius: 12px
/// - Height: 48px
/// - Text: Apercu 16px, cream color
/// - Hint: Apercu 16px, 50% opacity
/// - Suffix: Lowercase, 50% opacity, right-aligned
class KyleInputField extends StatelessWidget {
  const KyleInputField({
    super.key,
    required this.controller,
    this.focusNode,
    this.hintText,
    this.suffixText,
    this.enabled = true,
    this.keyboardType,
    this.textInputAction = TextInputAction.done,
    this.inputFormatters,
    this.onSubmitted,
    this.onChanged,
    this.textAlign = TextAlign.left,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? hintText;
  final String? suffixText;
  final bool enabled;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: AppColors.inputBackground, // Brighter purple for better visibility
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              enabled: enabled,
              keyboardType: keyboardType,
              textInputAction: textInputAction,
              inputFormatters: inputFormatters,
              onSubmitted: onSubmitted,
              onChanged: onChanged,
              textAlign: textAlign,
              style: AppTextStyles.inputText.copyWith(
                color: AppColors.cream,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: hintText,
                hintStyle: AppTextStyles.inputText.copyWith(
                  color: AppColors.cream.withValues(alpha: 0.5),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                // No border when focused (matches Figma)
                focusedBorder: InputBorder.none,
                enabledBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
              ),
            ),
          ),
          if (suffixText != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Text(
                suffixText!.toLowerCase(), // Always lowercase per Figma spec
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.cream.withValues(alpha: 0.4),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
