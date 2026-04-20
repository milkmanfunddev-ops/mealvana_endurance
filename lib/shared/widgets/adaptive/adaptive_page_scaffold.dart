import 'package:flutter/material.dart';
import '../../widgets/content_area.dart';

/// Canonical content width variants used across app screens.
enum AdaptiveContentWidth { narrow, standard, wide, fullBleed }

/// Standard responsive page scaffold that combines:
/// - optional safe area handling
/// - optional body width constraints
/// - full-bleed mode for layouts like coach portal
class AdaptivePageScaffold extends StatelessWidget {
  const AdaptivePageScaffold({
    super.key,
    required this.body,
    this.appBar,
    this.backgroundColor,
    this.contentWidth = AdaptiveContentWidth.standard,
    this.contentPadding,
    this.useSafeArea = false,
    this.safeAreaTop = true,
    this.safeAreaBottom = true,
    this.fullBleed = false,
    this.extendBodyBehindAppBar = false,
  });

  final Widget body;
  final PreferredSizeWidget? appBar;
  final Color? backgroundColor;
  final AdaptiveContentWidth contentWidth;
  final EdgeInsetsGeometry? contentPadding;
  final bool useSafeArea;
  final bool safeAreaTop;
  final bool safeAreaBottom;
  final bool fullBleed;
  final bool extendBodyBehindAppBar;

  Widget _wrapBody() {
    if (fullBleed || contentWidth == AdaptiveContentWidth.fullBleed) {
      return body;
    }

    switch (contentWidth) {
      case AdaptiveContentWidth.narrow:
        return ContentArea.narrow(padding: contentPadding, child: body);
      case AdaptiveContentWidth.wide:
        return ContentArea.wide(padding: contentPadding, child: body);
      case AdaptiveContentWidth.standard:
        return ContentArea(padding: contentPadding, child: body);
      case AdaptiveContentWidth.fullBleed:
        return body;
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget resolvedBody = _wrapBody();

    if (useSafeArea) {
      resolvedBody = SafeArea(
        top: safeAreaTop,
        bottom: safeAreaBottom,
        child: resolvedBody,
      );
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: appBar,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      body: resolvedBody,
    );
  }
}
