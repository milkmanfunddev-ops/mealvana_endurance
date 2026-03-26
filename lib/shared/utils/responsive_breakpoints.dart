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
}

/// Extension on [BuildContext] for responsive layout queries.
///
/// Uses [MediaQuery.sizeOf] (which is more efficient than
/// [MediaQuery.of] because it only rebuilds on size changes).
extension ResponsiveBreakpointsContext on BuildContext {
  double get screenWidth => MediaQuery.sizeOf(this).width;

  /// True on phones / compact layouts.
  bool get isCompact => screenWidth < Breakpoints.compact;

  /// True on tablets / medium layouts.
  bool get isMediumOrWider => screenWidth >= Breakpoints.medium;

  /// True on desktops / expanded layouts.
  bool get isExpandedOrWider => screenWidth >= Breakpoints.expanded;

  /// True when the screen is wide enough for a NavigationRail.
  bool get useNavigationRail => screenWidth >= Breakpoints.navigationRail;
}
