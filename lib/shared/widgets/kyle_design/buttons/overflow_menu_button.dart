/// Design SSOT component — **Overflow Menu** (the ⋯ button and its menu).
///
/// Spec: `docs/ssot/spec/design/components/overflow-menu.md` **v1**
/// (PROPOSED Lee 2026-09-22, authored app-side, awaiting Xuan).
///
/// Everything secondary on a screen, behind one ⋯ button in its top corner
/// (mp-493 §4, mp-494). First use: the paywall.
///
/// Contracts held here:
/// * **OM-1** — one 40 px `glass` circle with the ⋯ glyph, read as a button
///   by the caller's [OverflowMenuButton.semanticLabel].
/// * **OM-2** — a tap opens the menu under the button, its trailing edge on
///   the button's, kept inside the screen. It lists exactly the caller's
///   entries in the caller's order, on the `glass-sheet` recipe (all corners
///   rounded) over the standard sheet scrim. The scrim makes the ground dark
///   in both themes, so the words are always cream.
/// * **OM-3** — choosing an entry closes the menu first, then runs it (so a
///   confirmation it opens sits on the page, not on the menu). The scrim or
///   the back gesture closes it and runs nothing.
/// * **OM-4** — a destructive entry wears `dragonfruit` (the Q-D2 delete
///   treatment).
/// * **OM-5** — the menu fades in over 150 ms; with Reduce Motion it is
///   there on the next frame.
library;

import 'package:flutter/material.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_materials.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../materials/glass.dart';
import '../navigation/slide_over_pager.dart';

/// One line in the menu.
class OverflowMenuEntry {
  const OverflowMenuEntry({
    this.key,
    required this.label,
    required this.onSelected,
    this.destructive = false,
  });

  /// Put on the entry's row, so a test or a flow can find it.
  final Key? key;
  final String label;
  final VoidCallback onSelected;

  /// OM-4: dragonfruit.
  final bool destructive;
}

class OverflowMenuButton extends StatelessWidget {
  const OverflowMenuButton({
    super.key,
    required this.semanticLabel,
    required this.entries,
    required this.color,
  });

  static const menuKey = ValueKey('overflow_menu.menu');
  static const double size = 40;

  final String semanticLabel;
  final List<OverflowMenuEntry> entries;

  /// The ⋯ glyph's colour: the page's ink.
  final Color color;

  Future<void> _open(BuildContext context) async {
    final navigator = Navigator.of(context);
    final overlay = navigator.overlay!.context.findRenderObject()! as RenderBox;
    final box = context.findRenderObject()! as RenderBox;
    final anchor = Rect.fromPoints(
      box.localToGlobal(Offset.zero, ancestor: overlay),
      box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
    );
    final chosen = await navigator.push(
      _OverflowMenuRoute(
        anchor: anchor,
        entries: entries,
        barrierLabel: MaterialLocalizations.of(
          context,
        ).modalBarrierDismissLabel,
        reduceMotion: SlideOverPager.reduceMotionOf(context),
      ),
    );
    chosen?.onSelected();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _open(context),
        child: SizedBox.square(
          dimension: size,
          child: GlassSurface(
            borderRadius: BorderRadius.circular(size / 2),
            child: Center(
              child: ExcludeSemantics(
                child: Icon(Icons.more_horiz, size: 20, color: color),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OverflowMenuRoute extends PopupRoute<OverflowMenuEntry> {
  _OverflowMenuRoute({
    required this.anchor,
    required this.entries,
    required this.barrierLabel,
    required this.reduceMotion,
  });

  final Rect anchor;
  final List<OverflowMenuEntry> entries;
  final bool reduceMotion;

  @override
  final String barrierLabel;

  @override
  Color? get barrierColor => AppMaterials.sheetScrim;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration =>
      reduceMotion ? Duration.zero : const Duration(milliseconds: 150);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final menu = _OverflowMenuPanel(
      entries: entries,
      onChosen: (entry) => Navigator.of(context).pop(entry),
    );
    return CustomSingleChildLayout(
      delegate: _MenuLayout(
        anchor: anchor,
        padding: MediaQuery.paddingOf(context),
      ),
      child: menu,
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => reduceMotion
      ? child
      : FadeTransition(
          opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
          child: child,
        );
}

/// Trailing edge on the button's, just under it, kept inside the screen.
class _MenuLayout extends SingleChildLayoutDelegate {
  const _MenuLayout({required this.anchor, required this.padding});

  final Rect anchor;
  final EdgeInsets padding;

  static const double _gap = AppSpacing.xs;
  static const double _edge = AppSpacing.md;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      BoxConstraints(
        maxWidth: constraints.maxWidth - 2 * _edge,
        maxHeight:
            constraints.maxHeight - anchor.bottom - _gap - padding.bottom,
      );

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final left = (anchor.right - childSize.width).clamp(
      _edge,
      size.width - _edge - childSize.width,
    );
    return Offset(left, anchor.bottom + _gap);
  }

  @override
  bool shouldRelayout(_MenuLayout old) =>
      old.anchor != anchor || old.padding != padding;
}

class _OverflowMenuPanel extends StatelessWidget {
  const _OverflowMenuPanel({required this.entries, required this.onChosen});

  final List<OverflowMenuEntry> entries;
  final ValueChanged<OverflowMenuEntry> onChosen;

  static const _radius = BorderRadius.all(Radius.circular(AppRadius.lg));

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      key: OverflowMenuButton.menuKey,
      borderRadius: _radius,
      child: BackdropFilter(
        filter: AppMaterials.sheetBackdropFilter(),
        child: CustomPaint(
          foregroundPainter: const GlassRimPainter(borderRadius: _radius),
          child: DecoratedBox(
            decoration: BoxDecoration(color: AppMaterials.sheetVeil),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppMaterials.sheetFillTop,
                    AppMaterials.sheetFillBottom,
                  ],
                ),
              ),
              child: Material(
                type: MaterialType.transparency,
                child: IntrinsicWidth(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (i, entry) in entries.indexed) ...[
                        if (i > 0)
                          Divider(
                            height: 1,
                            thickness: 1,
                            color: AppColors.cream.withValues(alpha: 0.12),
                          ),
                        InkWell(
                          key: entry.key,
                          onTap: () => onChosen(entry),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              minHeight: 48,
                              minWidth: 200,
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.md,
                                vertical: AppSpacing.sm,
                              ),
                              child: Align(
                                alignment: AlignmentDirectional.centerStart,
                                widthFactor: 1,
                                child: Text(
                                  entry.label,
                                  style: AppTextStyles.bodyLarge.copyWith(
                                    color: entry.destructive
                                        ? AppColors.dragonfruit
                                        : AppColors.cream,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
