import 'package:flutter/material.dart';

import '../../../../theme/kyle_design/app_spacing.dart';

/// Holds chat parts back until the turn's prose has arrived (or the stream
/// ended), then reveals them with a staggered fade + slide — the
/// 2026-09-04 walkthrough: parts popping in above where the bubble was
/// about to land read jarringly, so the typing dots stay until Vana has
/// said something, and the widgets cascade in underneath.
///
/// One latch: once shown, always shown. A gate recreated while its parts
/// are already on screen (list recycling on scroll-back) shows them at
/// once — the entrance belongs to the live reveal only. Honors the
/// platform "reduce motion" setting by revealing without animation.
class PartEntrance extends StatefulWidget {
  const PartEntrance({super.key, required this.show, required this.children});

  /// Whether the parts may render. While false the gate is empty, keeping
  /// the typing indicator company; the false → true edge runs the entrance.
  final bool show;

  final List<Widget> children;

  @override
  State<PartEntrance> createState() => _PartEntranceState();
}

class _PartEntranceState extends State<PartEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _revealed = widget.show;
    if (_revealed) _controller.value = 1;
  }

  @override
  void didUpdateWidget(PartEntrance oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.show && !_revealed) {
      _revealed = true;
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
        _controller.value = 1;
      } else {
        _controller.forward();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.show) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppSpacing.xs),
        for (var i = 0; i < widget.children.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.xs),
          FadeTransition(
            opacity: _stagger(i),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.35),
                end: Offset.zero,
              ).animate(_stagger(i)),
              child: widget.children[i],
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
      ],
    );
  }

  /// The cascade: each part starts ~60ms after the one above it, capped so
  /// a long batch still lands inside ~550ms.
  Animation<double> _stagger(int index) {
    final start = (0.18 * index.clamp(0, 4)).clamp(0.0, 0.7);
    return CurvedAnimation(
      parent: _controller,
      curve: Interval(start, 1, curve: Curves.easeOut),
    );
  }
}
