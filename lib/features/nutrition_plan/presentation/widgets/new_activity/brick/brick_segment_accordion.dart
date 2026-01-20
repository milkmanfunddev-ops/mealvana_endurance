import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../../../../../theme/kyle_design/app_spacing.dart';
import '../../../../../../theme/kyle_design/app_text_styles.dart';
import '../../../../../../theme/kyle_design/app_colors.dart';

/// Brick Segment Accordion
///
/// An expandable accordion container for brick segment inputs.
/// Displays:
/// - Drag handle (≡) on the left
/// - Order number and sport name in header
/// - Expand/collapse icon on the right
/// - Sport-specific input fields when expanded
///
/// Design:
/// ```
/// ┌────────────────────────────────────────────┐
/// │ ≡ 1. Swimming                          ▼   │
/// └────────────────────────────────────────────┘
/// ```
///
/// When expanded, child widget is shown below the header.
class BrickSegmentAccordion extends StatelessWidget {
  const BrickSegmentAccordion({
    super.key,
    required this.sport,
    required this.order,
    required this.expanded,
    required this.onToggle,
    required this.child,
  });

  /// Sport name (e.g., "Swimming", "Cycling", "Running")
  final String sport;

  /// Segment order number (1-based)
  final int order;

  /// Whether the accordion is expanded
  final bool expanded;

  /// Callback when header is tapped to expand/collapse
  final VoidCallback onToggle;

  /// Sport-specific input fields to show when expanded
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.blackberry.withValues(alpha: 0.3)
            : AppColors.cream.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? AppColors.cream.withValues(alpha: 0.2)
              : AppColors.blackberry.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header with drag handle, title, and expand/collapse icon
          InkWell(
            onTap: onToggle,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
              child: Row(
                children: [
                  // Drag handle (≡)
                  Icon(
                    FontAwesomeIcons.gripVertical,
                    size: 20,
                    color: isDark
                        ? AppColors.cream.withValues(alpha: 0.5)
                        : AppColors.blackberry.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: AppSpacing.md),

                  // Order number and sport name
                  Expanded(
                    child: Text(
                      '$order. $sport',
                      style: AppTextStyles.descriptor.copyWith(
                        color: isDark ? AppColors.cream : AppColors.blackberry,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                  ),

                  // Expand/collapse icon
                  Icon(
                    expanded
                        ? FontAwesomeIcons.chevronUp
                        : FontAwesomeIcons.chevronDown,
                    size: 16,
                    color: isDark
                        ? AppColors.cream.withValues(alpha: 0.7)
                        : AppColors.blackberry.withValues(alpha: 0.7),
                  ),
                ],
              ),
            ),
          ),

          // Content (shown when expanded)
          if (expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: child,
            ),
          ],
        ],
      ),
    );
  }
}
