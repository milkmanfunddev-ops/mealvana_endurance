import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// A responsive wrapper that constrains content width on large screens (web/iPad).
///
/// On screens wider than [breakpoint], the content is centered and constrained
/// to [maxContentWidth]. On smaller screens, the content fills the available width.
///
/// This follows Material 3 responsive design guidelines:
/// - < 600px: Mobile (full width)
/// - 600-840px: Tablet portrait (constrained)
/// - > 840px: Tablet landscape / Desktop (constrained + centered)
///
/// Usage:
/// This widget is applied at the root level in MaterialApp.builder to affect
/// all screens without requiring individual screen modifications.
class ResponsiveContentWrapper extends StatelessWidget {
  const ResponsiveContentWrapper({
    super.key,
    required this.child,
    this.maxContentWidth = 750,
    this.breakpoint = 750,
    this.backgroundColor,
  });

  /// The child widget to wrap
  final Widget child;

  /// Maximum width of the content area on large screens.
  /// Default: 750px (optimal for mobile-designed content)
  final double maxContentWidth;

  /// Screen width above which to apply max-width constraint.
  /// Default: 750px (Material 3 compact/medium breakpoint)
  final double breakpoint;

  /// Background color for the area outside the content.
  /// If null, uses the scaffold background color from theme.
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    // Only apply constraints on web or when screen is large enough
    // Using LayoutBuilder instead of MediaQuery for proper constraint-based layout
    return LayoutBuilder(
      builder: (context, constraints) {
        final isLargeScreen = constraints.maxWidth > breakpoint;

        // On mobile-sized screens, return child as-is
        if (!isLargeScreen) {
          return child;
        }

        // On large screens, center the content with max-width constraint
        // Use scaffold background color to fill the sides
        final bgColor =
            backgroundColor ?? Theme.of(context).scaffoldBackgroundColor;

        return ColoredBox(
          color: bgColor,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth),
              child: child,
            ),
          ),
        );
      },
    );
  }
}

/// Extension to easily check if we're on a large screen
extension ResponsiveContext on BuildContext {
  /// Returns true if the screen width is greater than 750px
  bool get isLargeScreen => MediaQuery.sizeOf(this).width > 750;

  /// Returns true if the screen width is greater than 840px (tablet landscape+)
  bool get isExtraLargeScreen => MediaQuery.sizeOf(this).width > 840;

  /// Returns true if running on web platform
  bool get isWebPlatform => kIsWeb;
}
