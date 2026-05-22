import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../theme/kyle_design/app_colors.dart';
import '../../../theme/kyle_design/app_spacing.dart';

/// Reusable button for triggering OpenFoodFacts search.
///
/// Styled as an outlined orange button. Always rendered by parent
/// when the search query is non-empty.
class SearchOpenFoodFactsButton extends StatelessWidget {
  const SearchOpenFoodFactsButton({
    super.key,
    required this.onPressed,
  });

  /// Callback when button is pressed
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: AppSpacing.md),
        Center(
          child: OutlinedButton.icon(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.orange,
              side: BorderSide(
                color: AppColors.orange.withValues(alpha: 0.3),
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 14,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
            ),
            icon: const FaIcon(
              FontAwesomeIcons.magnifyingGlass,
              size: AppIconSizes.sm,
            ),
            label: const Text(
              'Search Open Food Facts',
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
