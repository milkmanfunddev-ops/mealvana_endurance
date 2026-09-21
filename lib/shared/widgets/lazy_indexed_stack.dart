import 'package:flutter/material.dart';

/// An [IndexedStack] that builds a child the first time its index is
/// selected, and keeps it alive from then on.
///
/// A plain `IndexedStack` builds every child on the first frame, so a tab
/// nobody opened still runs its `initState`, its `ref.watch`es and whatever
/// server calls those start. On the `/main` shell that meant the three Food
/// tabs each called `vana-action` at launch, for athletes who only looked at
/// the Timeline (ai-cost audit E1; mp-432, ticket approved as mp-468).
///
/// Unvisited slots hold [placeholder] (a zero-size box by default), so the
/// children list keeps its length and every visited child keeps its position
/// — which is what keeps its [State], and so its scroll offset, across a
/// switch away and back.
class LazyIndexedStack extends StatefulWidget {
  const LazyIndexedStack({
    super.key,
    required this.index,
    required this.itemCount,
    required this.itemBuilder,
    this.placeholder = const SizedBox.shrink(),
    this.alignment = AlignmentDirectional.topStart,
    this.sizing = StackFit.loose,
  });

  /// The slot on screen. Selecting it builds its child if it is the first time.
  final int index;

  final int itemCount;

  /// Builds slot `i`'s child. Called only for slots that have been selected.
  final Widget Function(BuildContext context, int index) itemBuilder;

  /// What stands in a slot that has never been selected.
  final Widget placeholder;

  final AlignmentGeometry alignment;
  final StackFit sizing;

  @override
  State<LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<LazyIndexedStack> {
  final Set<int> _visited = <int>{};

  @override
  void initState() {
    super.initState();
    _markVisited();
  }

  @override
  void didUpdateWidget(LazyIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _markVisited();
  }

  void _markVisited() {
    final index = widget.index;
    if (index >= 0 && index < widget.itemCount) _visited.add(index);
  }

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: widget.index,
      alignment: widget.alignment,
      sizing: widget.sizing,
      children: [
        for (var i = 0; i < widget.itemCount; i++)
          if (_visited.contains(i))
            widget.itemBuilder(context, i)
          else
            widget.placeholder,
      ],
    );
  }
}
