import 'package:flutter/material.dart';

/// Scroll-safe page body used for compact-height devices.
///
/// It applies the standard Flutter pattern:
/// LayoutBuilder -> SingleChildScrollView -> ConstrainedBox(minHeight)
/// so content can center/expand on tall screens while staying scrollable
/// on short screens.
class AdaptiveScrollableBody extends StatelessWidget {
  const AdaptiveScrollableBody({
    super.key,
    required this.child,
    this.footer,
    this.padding = EdgeInsets.zero,
    this.physics = const ClampingScrollPhysics(),
    this.safeAreaTop = true,
    this.safeAreaBottom = true,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.onDrag,
  });

  final Widget child;
  final Widget? footer;
  final EdgeInsetsGeometry padding;
  final ScrollPhysics physics;
  final bool safeAreaTop;
  final bool safeAreaBottom;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;

  Widget _buildScrollableContent({required bool includeBottomSafeArea}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: physics,
          keyboardDismissBehavior: keyboardDismissBehavior,
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (footer == null) {
      return SafeArea(
        top: safeAreaTop,
        bottom: safeAreaBottom,
        child: _buildScrollableContent(includeBottomSafeArea: safeAreaBottom),
      );
    }

    return Column(
      children: [
        Expanded(
          child: SafeArea(
            top: safeAreaTop,
            bottom: false,
            child: _buildScrollableContent(includeBottomSafeArea: false),
          ),
        ),
        SafeArea(top: false, bottom: safeAreaBottom, child: footer!),
      ],
    );
  }
}
