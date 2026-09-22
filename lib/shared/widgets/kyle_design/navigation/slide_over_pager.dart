/// Design SSOT component — **Slide-over Pager**.
///
/// Spec: `docs/ssot/spec/design/components/slide-over-pager.md` **v1**
/// (PROPOSED Lee 2026-09-21, authored app-side, awaiting Xuan).
///
/// Two pages, one move: the [second] page slides in from the trailing edge
/// over the [first], which drifts back and dims under the scrim of the
/// `glass-sheet` material as it is covered (mp-493 §1, §6). First use: the
/// paywall, from its opening clip to the features and plans.
///
/// Contracts held here:
/// * **SOP-1** — one way only: once [showSecond] is true the pager never
///   goes back, and no gesture moves it. The owner decides when.
/// * **SOP-2** — the move takes [duration] on an ease-out curve; the first
///   page moves a third as far as the second (parallax) and dims.
/// * **SOP-3** — Reduce Motion (or [animate] false) jumps: the second page is
///   there on the next frame, no slide. Reduce Motion is read by
///   [SlideOverPager.reduceMotionOf], which covers iOS's own flag.
/// * **SOP-4** — only the visible page is in the tree for input and
///   semantics; once the move ends the first page is removed, so whatever it
///   was playing stops.
library;

import 'package:flutter/widgets.dart';

import '../../../../theme/kyle_design/app_materials.dart';

class SlideOverPager extends StatefulWidget {
  const SlideOverPager({
    super.key,
    required this.first,
    required this.second,
    required this.showSecond,
    this.animate = true,
    this.duration = const Duration(milliseconds: 480),
  });

  final Widget first;
  final Widget second;

  /// SOP-1: false shows [first]; true moves to [second] for good.
  final bool showSecond;

  /// SOP-3: false jumps. Reduce Motion jumps whatever this says.
  final bool animate;

  /// SOP-2.
  final Duration duration;

  /// Whether the person asked for less motion: the platform's "disable
  /// animations" (Android, and a test's MediaQuery) or iOS Reduce Motion.
  /// Flutter reports iOS Reduce Motion only as
  /// `AccessibilityFeatures.reduceMotion`, which [MediaQueryData] does not
  /// carry, so both are read.
  static bool reduceMotionOf(BuildContext context) =>
      (MediaQuery.maybeDisableAnimationsOf(context) ?? false) ||
      (View.maybeOf(
            context,
          )?.platformDispatcher.accessibilityFeatures.reduceMotion ??
          false);

  static const firstKey = ValueKey('slide_over_pager.first');
  static const secondKey = ValueKey('slide_over_pager.second');

  @override
  State<SlideOverPager> createState() => _SlideOverPagerState();
}

class _SlideOverPagerState extends State<SlideOverPager>
    with SingleTickerProviderStateMixin {
  late final AnimationController _move = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: widget.showSecond ? 1 : 0,
  )..addStatusListener((_) => setState(() {}));

  late final Animation<double> _eased = CurvedAnimation(
    parent: _move,
    curve: Curves.easeOutCubic,
  );

  bool get _moved => _move.value > 0 || _move.isAnimating;

  @override
  void didUpdateWidget(covariant SlideOverPager old) {
    super.didUpdateWidget(old);
    if (!widget.showSecond || _moved) return; // SOP-1
    if (!widget.animate || SlideOverPager.reduceMotionOf(context)) {
      _move.value = 1; // SOP-3
    } else {
      _move.forward();
    }
  }

  @override
  void dispose() {
    _move.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final done = _move.isCompleted;
    final showingFirst = _move.isDismissed;
    return ClipRect(
      child: AnimatedBuilder(
        animation: _eased,
        builder: (context, _) {
          final t = _eased.value;
          return Stack(
            fit: StackFit.expand,
            children: [
              if (!done) // SOP-4
                FractionalTranslation(
                  key: SlideOverPager.firstKey,
                  translation: Offset(-t / 3, 0),
                  child: IgnorePointer(
                    ignoring: !showingFirst,
                    child: ExcludeSemantics(
                      excluding: !showingFirst,
                      child: widget.first,
                    ),
                  ),
                ),
              if (!done && !showingFirst)
                IgnorePointer(
                  key: const ValueKey('slide_over_pager.scrim'),
                  child: ColoredBox(
                    color: AppMaterials.sheetScrim.withValues(
                      alpha: AppMaterials.sheetScrim.a * t,
                    ),
                  ),
                ),
              if (!showingFirst)
                FractionalTranslation(
                  key: SlideOverPager.secondKey,
                  translation: Offset(1 - t, 0),
                  child: IgnorePointer(ignoring: !done, child: widget.second),
                ),
            ],
          );
        },
      ),
    );
  }
}
