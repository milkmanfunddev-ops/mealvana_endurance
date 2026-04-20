import 'package:flutter/widgets.dart';

/// Centers and constrains its [child] on wide screens.
///
/// On screens wider than [maxWidth], the child is centered within a
/// [ConstrainedBox]. On screens at or below [maxWidth], the child is
/// passed through unchanged.
///
/// This is the standard "body-level constraint" pattern recommended by
/// Code with Andrea (`ResponsiveCenter`) and Google's Material 3 codelabs.
/// Scaffold chrome (AppBar, NavigationRail) spans full width naturally,
/// while body content is centered and constrained.
///
/// Three preset constructors cover common use cases:
/// - [ContentArea] — 600 px (forms, settings, detail screens)
/// - [ContentArea.wide] — 800 px (lists, tab screens, content pages)
/// - [ContentArea.narrow] — 480 px (auth screens, simple forms, onboarding)
class ContentArea extends StatelessWidget {
  const ContentArea({
    super.key,
    required this.child,
    this.maxWidth = 600,
    this.padding,
  });

  /// 800 px — for lists, tab screens, and content-heavy pages.
  const ContentArea.wide({
    super.key,
    required this.child,
    this.padding,
  }) : maxWidth = 800;

  /// 480 px — for auth screens, simple forms, and onboarding.
  const ContentArea.narrow({
    super.key,
    required this.child,
    this.padding,
  }) : maxWidth = 480;

  final Widget child;

  /// Maximum width of the content area on wide screens.
  final double maxWidth;

  /// Optional horizontal padding applied inside the constraint.
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;

    // On narrow screens, just pass through (with optional padding).
    if (screenWidth <= maxWidth) {
      if (padding != null) {
        return Padding(padding: padding!, child: child);
      }
      return child;
    }

    // On wide screens, center + constrain.
    Widget result = Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );

    if (padding != null) {
      result = Padding(padding: padding!, child: result);
    }

    return result;
  }
}
