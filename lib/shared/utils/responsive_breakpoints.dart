import 'package:flutter/widgets.dart';

/// Material 3 responsive breakpoint constants.
///
/// Reference: https://m3.material.io/foundations/layout/applying-layout
class Breakpoints {
  Breakpoints._();

  /// Mobile phones (compact)
  static const double compact = 600;

  /// Tablets in portrait, small laptops (medium)
  static const double medium = 840;

  /// Tablets in landscape, desktops (expanded)
  static const double expanded = 1200;

  /// Large desktops (large)
  static const double large = 1600;

  /// Width at which we switch from bottom nav to NavigationRail.
  static const double navigationRail = 768;

  /// Height classes for compact-height behavior on small phones.
  static const double shortHeight = 700;
  static const double tallHeight = 900;
}

/// Canonical width size classes for responsive layout decisions.
enum ResponsiveSizeClass { compact, medium, expanded, large }

/// Canonical height classes for responsive spacing and hero sizing decisions.
enum ResponsiveHeightClass { short, regular, tall }

/// Extension on [BuildContext] for responsive layout queries.
///
/// Uses [MediaQuery.sizeOf] (which is more efficient than
/// [MediaQuery.of] because it only rebuilds on size changes).
extension ResponsiveBreakpointsContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;

  ResponsiveSizeClass get sizeClass {
    if (screenWidth >= Breakpoints.large) return ResponsiveSizeClass.large;
    if (screenWidth >= Breakpoints.expanded) {
      return ResponsiveSizeClass.expanded;
    }
    if (screenWidth >= Breakpoints.compact) return ResponsiveSizeClass.medium;
    return ResponsiveSizeClass.compact;
  }

  ResponsiveHeightClass get heightClass {
    if (screenHeight < Breakpoints.shortHeight) {
      return ResponsiveHeightClass.short;
    }
    if (screenHeight >= Breakpoints.tallHeight) {
      return ResponsiveHeightClass.tall;
    }
    return ResponsiveHeightClass.regular;
  }

  /// True on phones / compact layouts.
  bool get isCompact => screenWidth < Breakpoints.compact;

  /// True on tablets / medium layouts.
  bool get isMediumOrWider => screenWidth >= Breakpoints.medium;

  /// True on desktops / expanded layouts.
  bool get isExpandedOrWider => screenWidth >= Breakpoints.expanded;

  /// True when the screen is wide enough for a NavigationRail.
  bool get useNavigationRail => screenWidth >= Breakpoints.navigationRail;

  /// True when the window height is constrained (small phone portrait split).
  bool get isShortHeight => heightClass == ResponsiveHeightClass.short;
}
