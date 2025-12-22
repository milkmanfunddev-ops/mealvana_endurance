import 'package:flutter/material.dart';
import 'package:mealvana_endurance/shared/widgets/kyle_design/kyle_design.dart';

/// Navigation footer for onboarding screens with back and continue buttons
///
/// Provides consistent navigation across all onboarding screens with:
/// - Optional back button (hidden on first screen)
/// - Primary continue button with loading state
/// - Optional skip button for skippable screens
class OnboardingNavigationFooter extends StatelessWidget {
  const OnboardingNavigationFooter({
    super.key,
    required this.onContinue,
    this.onBack,
    this.onSkip,
    this.continueText = 'Continue',
    this.backText = 'Back',
    this.skipText = 'Skip',
    this.showBack = true,
    this.showSkip = false,
    this.isLoading = false,
    this.canContinue = true,
  });

  /// Called when the continue button is pressed
  final VoidCallback? onContinue;

  /// Called when the back button is pressed (if shown)
  final VoidCallback? onBack;

  /// Called when the skip button is pressed (if shown)
  final VoidCallback? onSkip;

  /// Text for the continue button
  final String continueText;

  /// Text for the back button
  final String backText;

  /// Text for the skip button
  final String skipText;

  /// Whether to show the back button
  final bool showBack;

  /// Whether to show the skip button
  final bool showSkip;

  /// Whether the continue button is in loading state
  final bool isLoading;

  /// Whether the continue button is enabled
  final bool canContinue;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Main navigation row
            Row(
              children: [
                // Back button (left side)
                if (showBack && onBack != null)
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: isLoading ? null : onBack,
                        icon: Icon(
                          Icons.arrow_back_ios,
                          size: 16,
                          color: AppColors.textLight,
                        ),
                        label: Text(
                          backText,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textLight,
                          ),
                        ),
                      ),
                    ),
                  )
                else if (showBack)
                  const Expanded(child: SizedBox()),

                // Continue button (right side)
                Expanded(
                  flex: showBack ? 1 : 2,
                  child: _ContinueButton(
                    text: continueText,
                    onPressed: canContinue && !isLoading ? onContinue : null,
                    isLoading: isLoading,
                  ),
                ),
              ],
            ),

            // Skip button (below, centered)
            if (showSkip && onSkip != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: TextButton(
                  onPressed: isLoading ? null : onSkip,
                  child: Text(
                    skipText,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textLightSecondary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ContinueButton extends StatelessWidget {
  const _ContinueButton({
    required this.text,
    required this.onPressed,
    required this.isLoading,
  });

  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null && !isLoading;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isEnabled ? AppColors.orange : AppColors.inactive,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xl,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: AppRadius.buttonRadius,
          ),
          elevation: isEnabled ? 2 : 0,
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    text,
                    style: AppTextStyles.buttonPrimary.copyWith(
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                  ),
                ],
              ),
      ),
    );
  }
}
