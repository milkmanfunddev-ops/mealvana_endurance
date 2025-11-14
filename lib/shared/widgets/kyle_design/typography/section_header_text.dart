import 'package:flutter/material.dart';
import '../../../../theme/kyle_design/app_colors.dart';

/// Section header text widget matching Kyle's design
///
/// Displays section titles like "Today's Activities" and "Upcoming Events"
/// with Kyle's design system specifications.
///
/// Specifications:
/// - Font: Sansita Bold, 17px
/// - Color: Cream (dark mode) or Blackberry (light mode)
/// - Top padding: 24px
/// - Bottom padding: 12px
///
/// Example:
/// ```dart
/// SectionHeaderText(
///   text: "Today's Activities",
/// )
/// ```
class SectionHeaderText extends StatelessWidget {
  const SectionHeaderText({
    super.key,
    required this.text,
    this.topPadding = 24.0,
    this.bottomPadding = 12.0,
  });

  final String text;
  final double topPadding;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        top: topPadding,
        bottom: bottomPadding,
        left: 16,
        right: 16,
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Sansita',
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: isDark ? AppColors.cream : AppColors.blackberry,
          height: 1.2,
        ),
      ),
    );
  }
}
