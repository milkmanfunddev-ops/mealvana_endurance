import 'package:flutter/material.dart';
import '../../../../theme/kyle_design/app_colors.dart';

/// Circular action button for floating navigation bar
///
/// A 42px circular button used in the floating action buttons bar.
/// Supports custom background colors and theme-aware icon colors.
///
/// Example:
/// ```dart
/// CircularActionButton(
///   icon: FontAwesomeIcons.calendar,
///   onPressed: () => _handleCalendarTap(),
///   backgroundColor: AppColors.kyleOrange,
/// )
/// ```
class CircularActionButton extends StatelessWidget {
  const CircularActionButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.semanticLabel,
    this.backgroundColor,
    this.iconColor,
    this.size = 42.0,
    this.iconSize = 20.0,
  });

  final IconData icon;
  final VoidCallback onPressed;

  /// Spoken label for screen readers and a long-press tooltip.
  /// Required so this button never ships unlabeled to assistive tech.
  final String semanticLabel;
  final Color? backgroundColor;
  final Color? iconColor;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final defaultBg = backgroundColor ?? Colors.transparent;
    final defaultIconColor = iconColor ??
        (isDark ? AppColors.cream : AppColors.blackberry);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: defaultBg,
        shape: BoxShape.circle,
      ),
      child: IconButton(
        icon: Icon(icon),
        iconSize: iconSize,
        color: defaultIconColor,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
        tooltip: semanticLabel,
      ),
    );
  }
}
