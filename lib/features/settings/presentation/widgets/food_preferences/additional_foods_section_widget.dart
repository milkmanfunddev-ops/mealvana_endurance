import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../../shared/widgets/kyle_design/kyle_design.dart';

/// An expandable section for displaying additional food options
///
/// Shows:
/// - Collapsible header with icon and label
/// - Expandable content area
/// - Chevron indicator (up/down)
class AdditionalFoodsSectionWidget extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onToggle;
  final List<Widget> children;

  const AdditionalFoodsSectionWidget({
    super.key,
    required this.isExpanded,
    required this.onToggle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Expandable header
        InkWell(
          onTap: onToggle,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.blackberry.withOpacity(0.2)
                  : Theme.of(context).colorScheme.surface.withOpacity(0.5),
              borderRadius: AppRadius.cardRadius,
              border: Border.all(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.restaurant_menu,
                  color: Theme.of(context).colorScheme.onSurface,
                  size: AppIconSizes.controlIcon,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    isExpanded
                        ? 'Show fewer food options'
                        : 'Show more food options',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  isExpanded
                      ? FontAwesomeIcons.chevronUp.data
                      : FontAwesomeIcons.chevronDown.data,
                  color: Theme.of(context).colorScheme.onSurface,
                  size: AppIconSizes.chevron,
                ),
              ],
            ),
          ),
        ),

        // Expandable content
        if (isExpanded) ...[
          const SizedBox(height: AppSpacing.md),
          ...children,
        ],
      ],
    );
  }
}
