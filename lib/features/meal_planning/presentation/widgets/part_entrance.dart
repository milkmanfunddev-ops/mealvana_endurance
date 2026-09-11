import 'package:flutter/material.dart';

import '../../../../theme/kyle_design/app_spacing.dart';

/// Holds chat parts back until the turn's prose has arrived (or the stream
/// ended), then reveals them with a fade that matches the prose — the
/// 2026-09-04 walkthrough: parts popping in above where the bubble was
/// about to land read jarringly, so the typing dots stay until Vana has
/// said something. 2026-09-07 (Lee): the parts used to slide + fade in a
/// quick cascade while the text faded, which still read as the meals
/// "popping" in; now the transcript's height grows smoothly and the parts
/// fade in over the same beat as the text, with only a soft stagger.
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
      duration: const Duration(milliseconds: 520),
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
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    // AnimatedSize so the space the parts need opens up smoothly instead of
    // the transcript jumping by a card's height the frame they arrive.
    return AnimatedSize(
      duration: reduce ? Duration.zero : const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topLeft,
      child: !widget.show
          ? const SizedBox(width: double.infinity)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AppSpacing.xs),
                for (var i = 0; i < widget.children.length; i++) ...[
                  if (i > 0) const SizedBox(height: AppSpacing.xs),
                  FadeTransition(
                    opacity: _stagger(i),
                    child: widget.children[i],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
              ],
            ),
    );
  }

  /// A soft stagger: each part starts ~50ms after the one above it, capped
  /// so a long batch still lands inside the same beat as the prose fade.
  Animation<double> _stagger(int index) {
    final start = (0.1 * index.clamp(0, 4)).clamp(0.0, 0.4);
    return CurvedAnimation(
      parent: _controller,
      curve: Interval(start, 1, curve: Curves.easeOut),
    );
  }
}
