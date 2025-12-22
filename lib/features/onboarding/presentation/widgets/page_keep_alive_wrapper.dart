import 'package:flutter/material.dart';

/// Wrapper widget to keep PageView pages alive
///
/// Prevents pages from being disposed when scrolling far away,
/// ensuring form state persists throughout the onboarding flow.
class PageKeepAliveWrapper extends StatefulWidget {
  const PageKeepAliveWrapper({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<PageKeepAliveWrapper> createState() => _PageKeepAliveWrapperState();
}

class _PageKeepAliveWrapperState extends State<PageKeepAliveWrapper>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return widget.child;
  }
}
