/// Design SSOT component — **Tab Bar** (v2, liquid glass).
///
/// Spec: `docs/ssot/spec/design/components/tab-bar.md` **v1** (RATIFIED Xuan
/// 2026-09-06, ruling-desk block; ships as `home-shell@v1`). Material:
/// `docs/ssot/spec/design/tokens.md` §Materials (`glass`). Companion
/// artifact: the archived home-shell export — it ILLUSTRATES; the spec and
/// tokens numbers govern (phase-card-parity). The tab-switch refraction and
/// drag-tracking are drawn in NEITHER — the spec's observable properties are
/// the only truth.
///
/// Contracts held here:
/// * **Q1 states** — `EXPANDED`: left-anchored glass pill, icon+label items,
///   cream-fill highlight (blackberry ink) on the active item. `COLLAPSED`:
///   one ~52 px circular glass button showing ONLY the active tab's icon,
///   count-independent (Q3). The morph travels to/from the LEFT corner (Q2
///   coherence); the collapse trigger (scroll thresholds + hysteresis) is
///   the composing screen's, pinned by `home-shell.gestures.yaml`, never
///   prose.
/// * **Q2** — left anchor plus a named, EMPTY bottom-right utility slot
///   ([utilitySlotSize] + [utilitySlotGap]); the bar never occupies it. The
///   future occupant inherits the old FAB's clearance rule (workout-card
///   G1/G4 swipe travel).
/// * **Q3** — 3–5 destinations; the expanded pill holds both extremes
///   without truncation, the collapsed button is count-independent.
/// * **Q4** — composition rule (held by the composing screen): the Fuel
///   Timeline item carries a HOUSE glyph, and no destination's icon may be
///   a calendar glyph while the date header renders one.
/// * **Tab-switch transition (contractual, all three parts):** (1) highlight
///   TRAVEL — position and width both animate, 340 ms
///   cubic-bezier(0.32,0.72,0,1), no crossfade, no teleport; (2)
///   finger-tracking DRAG — the highlight follows the finger with no
///   snapping until release, release commits to the nearest destination and
///   the travel completes from the release position; (3) REFRACTION in
///   transit — the traveling highlight lenses the content behind it
///   ([GlassLens], displacement + falloff from [AppMaterials]); the lens is
///   active mid-transit and absent at rest. Mid-transit frames are
///   golden-held.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_materials.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../materials/glass.dart';

/// One destination of the [KyleTabBar]. 3–5 per bar (tab-bar.md Q3).
class KyleTabBarDestination {
  const KyleTabBarDestination({
    required this.id,
    required this.icon,
    required this.label,
  });

  final String id;
  final IconData icon;
  final String label;
}

/// The liquid-glass tab bar. Anchor it at the bottom-LEFT of a screen-level
/// [Stack]; the composing screen drives [collapsed] from its scroll
/// position (thresholds + hysteresis pinned in the gesture manifest).
class KyleTabBar extends StatefulWidget {
  const KyleTabBar({
    super.key,
    required this.destinations,
    required this.activeId,
    required this.onSelect,
    this.collapsed = false,
    this.onCollapsedTap,
    this.maxWidth,
  }) : assert(
         destinations.length >= 3 && destinations.length <= 5,
         'tab-bar.md Q3: 3 to 5 destinations',
       );

  final List<KyleTabBarDestination> destinations;
  final String activeId;
  final ValueChanged<String> onSelect;

  /// Q1 COLLAPSED state; the widget animates the morph itself.
  final bool collapsed;

  /// Tap on the collapsed button — the composing screen re-expands (scrolls
  /// to top) per the manifest's rule.
  final VoidCallback? onCollapsedTap;

  /// Width available to the expanded pill (the screen subtracts margins and
  /// the utility-slot clearance before passing it).
  final double? maxWidth;

  // ---- Q2: the named, EMPTY bottom-right utility slot ----
  /// Diameter reserved at the bottom-right corner. NOTHING renders there in
  /// v1; a future occupant fills it additively and inherits the FAB
  /// clearance rule (no overlap with a workout card's swipe-reveal travel).
  static const double utilitySlotSize = 52.0;

  /// Gap between the bar's available width and the utility slot.
  static const double utilitySlotGap = 8.0;

  // ---- geometry (export-exact where the spec doesn't override) ----
  static const double expandedHeight = 60.0;
  static const double collapsedSize = 52.0;
  static const double pillPadding = 5.0;
  static const double itemWidth = 92.0;
  static const double expandedItemHeight = 50.0;
  static const double collapsedItemSize = 42.0;

  /// Travel/morph timing — reference values ratified into the manifest
  /// (tb4 pins): 340 ms, cubic-bezier(0.32, 0.72, 0, 1).
  static const Duration switchDuration = Duration(milliseconds: 340);
  static const Cubic switchCurve = Cubic(0.32, 0.72, 0, 1);

  @override
  State<KyleTabBar> createState() => _KyleTabBarState();
}

class _KyleTabBarState extends State<KyleTabBar>
    with TickerProviderStateMixin {
  late final AnimationController _morph; // 0 = expanded, 1 = collapsed
  late final AnimationController _travel; // one run per highlight move
  late int _activeIndex;
  int _travelFromIndex = 0;
  double? _travelFromX; // overrides _travelFromIndex after a drag release
  double? _dragX; // highlight centre while a drag is live

  @override
  void initState() {
    super.initState();
    _activeIndex = _indexOf(widget.activeId);
    _travelFromIndex = _activeIndex;
    _morph = AnimationController(
      vsync: this,
      duration: KyleTabBar.switchDuration,
      value: widget.collapsed ? 1 : 0,
    );
    _travel = AnimationController(
      vsync: this,
      duration: KyleTabBar.switchDuration,
      value: 1,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) _travelFromX = null;
      });
  }

  @override
  void didUpdateWidget(KyleTabBar old) {
    super.didUpdateWidget(old);
    if (widget.collapsed != old.collapsed) {
      widget.collapsed
          ? _morph.animateTo(1, curve: KyleTabBar.switchCurve)
          : _morph.animateTo(0, curve: KyleTabBar.switchCurve);
    }
    final newIndex = _indexOf(widget.activeId);
    if (newIndex != _activeIndex) {
      _travelFromIndex = _activeIndex;
      _travelFromX ??= null;
      _activeIndex = newIndex;
      _travel.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _morph.dispose();
    _travel.dispose();
    super.dispose();
  }

  int _indexOf(String id) {
    final i = widget.destinations.indexWhere((d) => d.id == id);
    return i < 0 ? 0 : i;
  }

  double _itemWidth() {
    final n = widget.destinations.length;
    final available = widget.maxWidth;
    if (available == null) return KyleTabBar.itemWidth;
    return math.min(
      KyleTabBar.itemWidth,
      (available - 2 * KyleTabBar.pillPadding) / n,
    );
  }

  double _itemCenter(int index, double itemW) =>
      KyleTabBar.pillPadding + (index + 0.5) * itemW;

  // ---- drag-tracking (transition part 2) ----
  void _onDragStart(DragStartDetails d) {
    if (_morph.value > 0.01) return;
    setState(() => _dragX = d.localPosition.dx);
  }

  void _onDragUpdate(DragUpdateDetails d) {
    if (_dragX == null) return;
    final itemW = _itemWidth();
    final min = _itemCenter(0, itemW);
    final max = _itemCenter(widget.destinations.length - 1, itemW);
    setState(() => _dragX = d.localPosition.dx.clamp(min, max));
  }

  void _onDragEnd(DragEndDetails d) {
    final x = _dragX;
    if (x == null) return;
    final itemW = _itemWidth();
    var nearest = 0;
    var best = double.infinity;
    for (var i = 0; i < widget.destinations.length; i++) {
      final dist = (x - _itemCenter(i, itemW)).abs();
      if (dist < best) {
        best = dist;
        nearest = i;
      }
    }
    // The travel completes from the release position — for a same-item
    // release didUpdateWidget won't fire, so run it here either way.
    setState(() {
      _travelFromX = x;
      _dragX = null;
      _travelFromIndex = _activeIndex;
      _activeIndex = nearest;
    });
    _travel.forward(from: 0);
    if (widget.destinations[nearest].id != widget.activeId) {
      widget.onSelect(widget.destinations[nearest].id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_morph, _travel]),
      builder: (context, _) {
        final p = _morph.value;
        if (p >= 0.999) return _collapsedButton();
        return _pill(p);
      },
    );
  }

  Widget _collapsedButton() {
    final active = widget.destinations[_activeIndex];
    return Semantics(
      button: true,
      label: active.label,
      child: GestureDetector(
        key: const ValueKey('kyle_tab_bar.collapsed_button'),
        onTap: widget.onCollapsedTap,
        child: GlassSurface(
          borderRadius: BorderRadius.circular(KyleTabBar.collapsedSize / 2),
          lift: true,
          dimmed: true,
          child: SizedBox(
            width: KyleTabBar.collapsedSize,
            height: KyleTabBar.collapsedSize,
            child: Icon(active.icon, size: 20, color: AppColors.cream),
          ),
        ),
      ),
    );
  }

  Widget _pill(double p) {
    final n = widget.destinations.length;
    final itemW = _itemWidth();
    final expandedW = n * itemW + 2 * KyleTabBar.pillPadding;
    double lerp(double a, double b) => a + (b - a) * p;
    final pillW = lerp(expandedW, KyleTabBar.collapsedSize);
    final pillH = lerp(KyleTabBar.expandedHeight, KyleTabBar.collapsedSize);
    final itemH = lerp(
      KyleTabBar.expandedItemHeight,
      KyleTabBar.collapsedItemSize,
    );
    final labelFade = math.max(0.0, 1 - p * 1.8);

    // ---- highlight travel (transition part 1) ----
    final t = KyleTabBar.switchCurve.transform(_travel.value);
    final toCenter = _itemCenter(_activeIndex, itemW);
    final fromCenter = _travelFromX ?? _itemCenter(_travelFromIndex, itemW);
    final dragging = _dragX != null;
    final center = dragging ? _dragX! : fromCenter + (toCenter - fromCenter) * t;
    // Width morphs through the move: the capsule stretches along the travel
    // and relaxes at rest (tb4: position AND width both animate).
    final stretch = dragging
        ? 0.0
        : (toCenter - fromCenter).abs() * 0.3 * math.sin(math.pi * t);
    final highlightW = (itemW + stretch) * (1 - p);

    // The liquid bubble (PROPOSED 2026-09-06, Bevel reference): a raised
    // glass lens over the active item that bulges past the pill's border
    // and refracts the labels + page beneath it, at rest and in transit.
    // It sits OUTSIDE the pill's clip so the overflow reads (Bevel's
    // silhouette); it fades out through the collapse morph (the collapsed
    // button is its own glass circle).
    final motion = dragging ? 1.0 : math.sin(math.pi * t);
    final bulge =
        (AppMaterials.tabLensBulgePx +
            AppMaterials.tabLensTransitBulgePx * motion) *
        (1 - p);
    final lensH = itemH + 2 * bulge;
    final lensW = math.max(0.0, highlightW + 2 * bulge);
    final lensVisibility = (1 - p * 1.8).clamp(0.0, 1.0);
    // The crisp rider: whichever tab the lens is OVER renders above the
    // glass. Settled/travel: the destination, full strength. DRAG (Xuan
    // 2026-09-07 iteration 4): the nearest item to the finger, with
    // strength = how centered the lens is over it — tabs hand off
    // crisply under the finger instead of refracting to mush.
    int riderIndex = _activeIndex;
    double riderStrength = 1.0;
    if (dragging) {
      var best = double.infinity;
      for (var i = 0; i < n; i++) {
        final d = (_dragX! - _itemCenter(i, itemW)).abs();
        if (d < best) {
          best = d;
          riderIndex = i;
        }
      }
      riderStrength = (1 - best / itemW).clamp(0.0, 1.0);
    }
    final riderVisible = lensVisibility > 0 && riderStrength > 0;
    // Bevel behavior, iteration 3 (Xuan 2026-09-07: the target must be IN
    // FOCUS for the whole transition): the destination's crisp copy is
    // STATIC at the destination slot, above the glass, from the moment the
    // travel starts — the lens slides in underneath it. Only tabs the lens
    // passes over get refracted. While dragging the lens glides empty over
    // the static row.
    return GestureDetector(
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          GlassSurface(
            borderRadius: BorderRadius.circular(100),
            lift: true,
            dimmed: true,
            child: SizedBox(
              width: pillW,
              height: pillH,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: Row(
                  children: [
                    // Constant padding (export-exact): shrinking it made the
                    // morph end with the icon at x=21 while the collapsed
                    // button centers at x=26 — the 5px sideways snap in
                    // Xuan's second report.
                    const SizedBox(width: KyleTabBar.pillPadding),
                    for (var i = 0; i < n; i++)
                      _item(
                        i,
                        p,
                        itemW,
                        labelFade,
                        // Faded out to the degree its crisp copy renders
                        // above the glass.
                        carriedByLens: i == riderIndex && riderVisible
                            ? riderStrength * lensVisibility
                            : 0.0,
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (lensVisibility > 0)
            Positioned(
              left: center - lensW / 2,
              top: (pillH - itemH) / 2 - bulge,
              width: lensW,
              height: lensH,
              child: IgnorePointer(
                child: LiquidLensBubble(
                  key: const ValueKey('kyle_tab_bar.highlight'),
                  radius: lensH / 2,
                  visibility: lensVisibility,
                  motion: motion,
                ),
              ),
            ),
          // The focused tab's content — STATIC at the destination slot,
          // ABOVE the glass layer: crisp by construction for the entire
          // transition (the lens slides in underneath it), zooming in as
          // the lens arrives.
          if (riderVisible)
            Positioned(
              left: _itemCenter(riderIndex, itemW) - itemW / 2,
              top: (pillH - itemH) / 2,
              width: itemW,
              height: itemH,
              child: IgnorePointer(
                child: Opacity(
                  opacity: lensVisibility * riderStrength,
                  child: Center(
                    child: Transform.scale(
                      scale: 1 +
                          (AppMaterials.tabLensFocusZoom - 1) *
                              (dragging ? riderStrength : t) *
                              lensVisibility,
                      child: _itemContent(
                        widget.destinations[riderIndex],
                        AppColors.cream,
                        labelFade,
                        p,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _item(
    int i,
    double p,
    double itemW,
    double labelFade, {
    double carriedByLens = 0.0,
  }) {
    final d = widget.destinations[i];
    final active = i == _activeIndex;
    double lerp(double a, double b) => a + (b - a) * p;
    // Non-active items shrink away during the morph; the active one narrows
    // to the collapsed icon button (export-exact interpolation).
    final w = active ? lerp(itemW, KyleTabBar.collapsedItemSize) : itemW * (1 - p);
    // No cream fill under the active item anymore (liquid bubble,
    // PROPOSED 2026-09-06): active ink is cream on glass.
    final ink = active
        ? AppColors.cream
        : AppColors.cream.withValues(alpha: 0.72 * math.max(0.0, 1 - p * 1.8));
    if (w <= 0.5) return const SizedBox.shrink();
    return ClipRect(
      child: SizedBox(
        width: w,
        child: Semantics(
          button: true,
          selected: active,
          label: d.label,
          child: GestureDetector(
            key: ValueKey('kyle_tab_bar.item.${d.id}'),
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (!active) widget.onSelect(d.id);
            },
            child: Opacity(
              opacity: (1 - carriedByLens).clamp(0.0, 1.0),
              child: _itemContent(d, ink, labelFade, p),
            ),
          ),
        ),
      ),
    );
  }

  /// One item's icon + label — shared by the in-row items and the crisp
  /// copy riding the lens, so the two can never drift apart.
  Widget _itemContent(
    KyleTabBarDestination d,
    Color ink,
    double labelFade,
    double p,
  ) {
    double lerp(double a, double b) => a + (b - a) * p;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(d.icon, size: 20, color: ink),
        // The slot's HEIGHT always animates (14 -> 0); only the paint
        // fades. Gating the slot on labelFade removed ~6px of reserved
        // height in one frame at p=0.555 and made the icon jump-recenter
        // (the collapse hitch in Xuan's recording).
        SizedBox(
          height: lerp(14, 0),
          child: Opacity(
            opacity: labelFade,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                d.label,
                maxLines: 1,
                overflow: TextOverflow.visible,
                softWrap: false,
                style: TextStyle(
                  fontFamily: AppTextStyles.apercu,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                  height: 1.0,
                  color: ink,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
