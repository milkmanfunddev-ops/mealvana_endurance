import 'package:flutter/material.dart';
import '../../../theme/kyle_design/app_colors.dart';

/// Navigation footer matching Figma onboarding design
///
/// Features:
/// - Optional circular back button with semi-transparent orange background
/// - Full-width continue/save button with customizable text
/// - Matches Figma design specification exactly
class FigmaOnboardingFooter extends StatelessWidget {
  const FigmaOnboardingFooter({
    super.key,
    required this.onContinue,
    this.onBack,
    this.canContinue = true,
    this.isLoading = false,
    this.buttonText = 'Continue',
    this.showBackButton = true,
  });

  /// Called when the continue button is pressed
  final VoidCallback? onContinue;

  /// Called when the back button is pressed (optional)
  final VoidCallback? onBack;

  /// Whether the continue button is enabled
  final bool canContinue;

  /// Whether the continue button is in loading state
  final bool isLoading;

  /// Text to show on the main button (e.g., "Continue", "Save")
  final String buttonText;

  /// Whether to show the back button (default: true)
  final bool showBackButton;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 25),
      child: Row(
        children: [
          // Circular back button (48x48) with semi-transparent orange background
          if (showBackButton && onBack != null) ...[
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.orange.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(28),
              ),
              child: IconButton(
                onPressed: isLoading ? null : onBack,
                icon: const Icon(
                  Icons.arrow_back,
                  size: 28,
                  color: AppColors.orange,
                ),
                padding: EdgeInsets.zero,
              ),
            ),
            const SizedBox(width: 12),
          ],

          // Continue/Save button takes remaining space
          Expanded(
            child: SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: canContinue && !isLoading ? onContinue : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canContinue && !isLoading
                      ? AppColors.orange
                      : AppColors.orange.withValues(alpha: 0.5),
                  foregroundColor: AppColors.blackberry,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  elevation: 0,
                ),
                child: isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.blackberry,
                          ),
                        ),
                      )
                    : Text(
                        buttonText,
                        style: const TextStyle(
                          fontFamily: 'Sansita',
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.192,
                        ),
                        textAlign: TextAlign.center,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
