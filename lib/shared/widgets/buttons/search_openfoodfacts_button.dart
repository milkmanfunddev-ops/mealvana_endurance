import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../theme/kyle_design/app_colors.dart';
import '../../../theme/kyle_design/app_spacing.dart';

/// Reusable button for triggering OpenFoodFacts search
///
/// Shows a prominent purple button with search icon and text.
/// Used across multiple screens for consistent UX when offering
/// optional external food database search.
class SearchOpenFoodFactsButton extends StatelessWidget {
  const SearchOpenFoodFactsButton({
    super.key,
    required this.onPressed,
    this.isVisible = true,
  });

  /// Callback when button is pressed
  final VoidCallback onPressed;

  /// Whether the button should be visible
  final bool isVisible;

  @override
  Widget build(BuildContext context) {
    if (!isVisible) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        const SizedBox(height: AppSpacing.md),
        Center(
          child: ElevatedButton.icon(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.electrolyte,
              foregroundColor: AppColors.blackberry,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
              elevation: 2,
            ),
            icon: const Icon(
              FontAwesomeIcons.magnifyingGlass,
              size: AppIconSizes.sm,
            ),
            label: const Text(
              'Search OpenFoodFacts for more results',
              style: TextStyle(
                fontFamily: 'Apercu',
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
