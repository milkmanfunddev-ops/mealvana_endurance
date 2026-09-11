/// Design SSOT component — **Vana Sheet** (the launcher and the summoned
/// glass sheet).
///
/// Spec: `docs/ssot/spec/design/components/vana-sheet.md`, **PROPOSED v1**
/// (Lee, 2026-09-11), authored app-side and awaiting Xuan. Q-VS1 (three
/// heights, the grabber dragging between them) and Q-VS2 (the drawn
/// speech-bubble mark) are confirmed.
///
/// Material: `docs/ssot/spec/design/tokens.md` §Materials — the launcher takes
/// `glass` with `lift`, dimmed like the collapsed tab-bar button it mirrors on
/// the opposite corner; the sheet takes `glass-sheet` including its scrim
/// (blackberry 60 %), inherited from the calendar sheet's ruling. Raw values
/// live in [AppMaterials] only. The spec's top radius 26 is the export's; the
/// `glass-sheet` token is 24 and the token governs.
///
/// Slot authority: `tab-bar.md` Q2 — the named bottom-right utility slot,
/// filled additively ([VanaLauncher.size] is [KyleTabBar.utilitySlotSize]).
///
/// Contracts held here:
/// * **Launcher** — ~52 px circular glass, Vana's mark, no label; with the
///   moment states it takes when Vana speaks first, in `vana_launcher.dart`.
/// * **Rise** 360 ms from the bottom edge; **condense** 470 ms back into the
///   launcher, transform origin at the launcher's own centre, rounding into a
///   circle as it shrinks. Every pop of [VanaSheetRoute] — scrim tap (VS-2),
///   system back (VS-2), the grabber dragged down (VS-7), the dismiss button,
///   the full-screen hand-off (VS-3) — runs the condense, so no dismissal
///   slides the sheet off-screen (VS-9). The composer lets go of focus as the
///   pop starts (the route's focus scope does that), so the keyboard goes too.
/// * **Heights** (Q-VS1, VS-7) — `auto`, 75 %, 100 % ([VanaSheetHeight]).
///   The feature picks the rest height; the grabber expands to 100 % and back,
///   and a drag down past the rest height dismisses through the condense.
///   The export's thresholds: 24 px up expands, 90 px down collapses or
///   dismisses, a tap on the grabber toggles, an upward pull at rest gives at
///   35 %.
/// * The sheet does not resize while streaming (VS-4): its height moves only
///   with the grabber, the rest height the feature gives it, and the keyboard.
///
/// What the sheet says is the persona's business: the body and composer are
/// slots the feature fills, composed from the inside's widgets in
/// `vana_sheet_conversation.dart` (status chip, message treatments, quick
/// replies, composer), exported from here.
library;

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_materials.dart';
import '../../../../theme/kyle_design/app_theme.dart';
import '../materials/glass.dart';
import 'vana_launcher.dart';

export 'vana_launcher.dart';
export 'vana_sheet_conversation.dart';

/// The sheet's three heights (Q-VS1). The page stays visible at the two
/// rest heights; that is the contract.
enum VanaSheetHeight {
  /// As tall as what it holds, up to 75 %: a sheet that is one message and a
  /// dismiss.
  auto,

  /// 75 % of the screen: the rest height of a sheet with a card and replies.
  threeQuarters,

  /// 100 %, expanded: up to the status bar.
  full,
}

/// The sheet's chrome: `glass-sheet`, grabber, the full-screen and dismiss
/// buttons at the top-right, then the feature's [body] and [composer]. It
/// owns its height: [rest] until the grabber expands it.
///
/// Always dark inside: `glass-sheet` is a dark-first material (tokens.md —
/// the light variant is deferred), so the content inherits the dark theme
/// whatever the app's mode.
class VanaSheet extends StatefulWidget {
  const VanaSheet({
    super.key,
    required this.body,
    required this.composer,
    required this.closeLabel,
    required this.fullScreenLabel,
    required this.onClose,
    required this.onFullScreen,
    this.rest = VanaSheetHeight.threeQuarters,
  }) : assert(rest != VanaSheetHeight.full, 'the sheet rests below 100 %');

  /// The conversation column. At [VanaSheetHeight.auto] it is laid out with
  /// a loose height and should be as tall as what it holds.
  final Widget body;

  /// The composer row, pinned under the body.
  final Widget composer;

  final String closeLabel;
  final String fullScreenLabel;

  /// Dismiss — the caller pops the route, which condenses. The grabber
  /// dragged down past the rest height calls it too.
  final VoidCallback onClose;

  /// VS-3 — the caller opens the chat route with the same conversation.
  final VoidCallback onFullScreen;

  /// Where the sheet rests: [VanaSheetHeight.auto] or
  /// [VanaSheetHeight.threeQuarters]. A change animates.
  final VanaSheetHeight rest;

  /// The 75 % rest height, a fraction of the screen.
  static const double restHeightFraction = 0.75;

  static const Duration riseDuration = Duration(milliseconds: 360);
  static const Cubic riseCurve = Cubic(0.2, 0.85, 0.2, 1);
  static const Duration condenseDuration = Duration(milliseconds: 470);
  static const Cubic condenseCurve = Cubic(0.45, 0, 0.55, 1);

  /// A change of height, and the spring back from a drag (the export's
  /// height transition).
  static const Duration settleDuration = Duration(milliseconds: 320);

  /// Where the condense ends: scaled to 2 % and faded to 70 %, then gone.
  static const double condensedScale = 0.02;
  static const double condensedOpacity = 0.7;

  /// The export's drag thresholds, in logical pixels.
  static const double expandDrag = 24;
  static const double dismissDrag = 90;

  /// A flick this fast counts as a drag past the threshold.
  static const double flingVelocity = 700;

  /// How much of an upward pull at rest the sheet follows.
  static const double stretchFactor = 0.35;

  /// The chrome row above the body: grabber and buttons. The whole row is
  /// the grabber's drag target.
  static const double chromeHeight = 48;

  static final ThemeData _dark = AppTheme.darkTheme;

  @override
  State<VanaSheet> createState() => _VanaSheetState();
}

class _VanaSheetState extends State<VanaSheet>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  /// The drag in progress, as the sheet shows it: down moves the sheet down,
  /// up stretches it (at rest only).
  double _offset = 0;
  double _dragged = 0;

  /// A height change or spring back, from these to the current height.
  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: VanaSheet.settleDuration,
    value: 1,
  )..addListener(() => setState(() {}));
  double _fromHeight = 0;
  double _fromOffset = 0;

  /// The last laid-out height, and the last height `auto` took.
  double? _height;
  double? _autoHeight;

  /// From 100 % down to the rest height, as last laid out. A drag down from
  /// 100 % that passes the rest line by the dismiss distance dismisses.
  double _collapseDistance = 0;

  VanaSheetHeight get _current =>
      _expanded ? VanaSheetHeight.full : widget.rest;

  @override
  void didUpdateWidget(VanaSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rest != widget.rest && !_expanded) _goTo(expanded: false);
  }

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  /// Animates from wherever the sheet is now to [expanded] or the rest.
  void _goTo({required bool expanded}) {
    _fromHeight = _height ?? 0;
    _fromOffset = math.max(0, _offset);
    _offset = 0;
    _expanded = expanded;
    _settle.forward(from: 0);
  }

  /// Back to the rest height. The composer lets go, so the keyboard goes
  /// with the room it was typing in.
  void _collapse() {
    FocusScope.of(context).focusedChild?.unfocus();
    _goTo(expanded: false);
  }

  void _toggle() => _expanded ? _collapse() : _goTo(expanded: true);

  void _dragStart(DragStartDetails _) {
    _settle.value = 1;
    _dragged = 0;
  }

  void _dragUpdate(DragUpdateDetails details) {
    _dragged += details.primaryDelta ?? 0;
    setState(() {
      _offset = _dragged >= 0
          ? _dragged
          : _expanded
          ? 0
          : _dragged * VanaSheet.stretchFactor;
    });
  }

  void _dragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final down =
        _dragged > VanaSheet.dismissDrag || velocity > VanaSheet.flingVelocity;
    final up =
        _dragged < -VanaSheet.expandDrag || velocity < -VanaSheet.flingVelocity;
    final pastRest =
        _expanded && _dragged > _collapseDistance + VanaSheet.dismissDrag;
    _dragged = 0;
    if (down && _expanded && !pastRest) {
      _collapse();
    } else if (down) {
      // VS-7: past the shortest height is the VS-2 path, and the condense.
      _goTo(expanded: false);
      widget.onClose();
    } else if (up && !_expanded) {
      _goTo(expanded: true);
    } else {
      _goTo(expanded: _expanded);
    }
  }

  void _dragCancel() {
    _dragged = 0;
    _goTo(expanded: _expanded);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screen = MediaQuery.sizeOf(context).height;
        final room = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : screen;
        final threeQuarters = math.min(
          screen * VanaSheet.restHeightFraction,
          room,
        );
        double? heightOf(VanaSheetHeight h) => switch (h) {
          VanaSheetHeight.full => room,
          VanaSheetHeight.threeQuarters => threeQuarters,
          VanaSheetHeight.auto =>
            _autoHeight == null ? null : math.min(_autoHeight!, threeQuarters),
        };

        // Null: as tall as what it holds.
        double? height;
        var offset = math.max(0.0, _offset);
        if (_settle.isAnimating) {
          final t = VanaSheet.riseCurve.transform(_settle.value);
          height = lerpDouble(
            _fromHeight,
            heightOf(_current) ?? threeQuarters,
            t,
          );
          offset = _fromOffset * (1 - t);
        } else {
          final stretch = math.max(0.0, -_offset);
          final base = heightOf(_current);
          if (_current != VanaSheetHeight.auto || stretch > 0) {
            height = math.min(room, (base ?? threeQuarters) + stretch);
          }
        }
        final contentSized = height == null;
        _collapseDistance = room - (heightOf(widget.rest) ?? threeQuarters);

        // One tree shape at every height: a change of shape would remount
        // the sheet mid-drag and take the composer's focus with it.
        final surface = GlassSheetSurface(
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              mainAxisSize: contentSized ? MainAxisSize.min : MainAxisSize.max,
              children: [
                _chrome(),
                Flexible(
                  fit: contentSized ? FlexFit.loose : FlexFit.tight,
                  child: widget.body,
                ),
                SafeArea(top: false, child: widget.composer),
              ],
            ),
          ),
        );

        return Theme(
          data: VanaSheet._dark,
          child: Transform.translate(
            offset: Offset(0, offset),
            child: _SizeReporter(
              onLayout: (size) {
                _height = size.height;
                if (contentSized) _autoHeight = size.height;
              },
              child: SizedBox(
                width: double.infinity,
                height: height,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: contentSized ? threeQuarters : double.infinity,
                  ),
                  child: surface,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// The grabber row. Dragging anywhere on it (the buttons keep their taps)
  /// moves the sheet; a tap on the grabber toggles 100 %. The transcript below
  /// keeps its own scroll.
  Widget _chrome() {
    return GestureDetector(
      key: const ValueKey('vana_sheet.handle'),
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: _dragStart,
      onVerticalDragUpdate: _dragUpdate,
      onVerticalDragEnd: _dragEnd,
      onVerticalDragCancel: _dragCancel,
      child: SizedBox(
        height: VanaSheet.chromeHeight,
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggle,
                // A 44 px target round the 36 × 5 bar.
                child: const SizedBox(
                  width: 88,
                  height: 36,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: EdgeInsets.only(top: 10),
                      child: _Grabber(),
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 6,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ChromeButton(
                    key: const ValueKey('vana_sheet.full_screen'),
                    icon: FontAwesomeIcons.upRightAndDownLeftFromCenter,
                    label: widget.fullScreenLabel,
                    onTap: widget.onFullScreen,
                  ),
                  _ChromeButton(
                    key: const ValueKey('vana_sheet.close'),
                    icon: FontAwesomeIcons.xmark,
                    label: widget.closeLabel,
                    onTap: widget.onClose,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reports its child's laid-out size, so the sheet can animate from the
/// height it actually has, `auto` included.
class _SizeReporter extends SingleChildRenderObjectWidget {
  const _SizeReporter({required this.onLayout, super.child});

  final ValueChanged<Size> onLayout;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderSizeReporter(onLayout);

  @override
  void updateRenderObject(
    BuildContext context,
    _RenderSizeReporter renderObject,
  ) => renderObject.onLayout = onLayout;
}

class _RenderSizeReporter extends RenderProxyBox {
  _RenderSizeReporter(this.onLayout);

  ValueChanged<Size> onLayout;

  @override
  void performLayout() {
    super.performLayout();
    onLayout(size);
  }
}

/// The calendar sheet's grabber, so a second summoned sheet does not invent a
/// second vocabulary. The drag is the whole chrome row's.
class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('vana_sheet.grabber'),
      width: 36,
      height: 5,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(3),
        color: AppMaterials.sheetGrabber,
      ),
    );
  }
}

/// A 30 px circular chrome button on the sheet's glass, in a 44 px target.
class _ChromeButton extends StatelessWidget {
  const _ChromeButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final FaIconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      label: label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox.square(
          dimension: 44,
          child: Center(
            child: GlassSurface(
              borderRadius: BorderRadius.circular(15),
              nested: true,
              child: SizedBox.square(
                dimension: 30,
                child: Center(
                  child: FaIcon(icon, size: 12, color: AppColors.cream),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Summons a [VanaSheet] over the current screen (VS-1) without navigating
/// away from it: a popup route, so the page underneath keeps its state and
/// scroll position, the scrim tap and system back pop it (VS-2), and every
/// pop condenses into the launcher (VS-9).
class VanaSheetRoute<T> extends PopupRoute<T> {
  VanaSheetRoute({
    required this.builder,
    required this.barrierLabel,
    super.settings,
  });

  /// Builds the [VanaSheet].
  final WidgetBuilder builder;

  @override
  final String barrierLabel;

  @override
  Color get barrierColor => AppMaterials.sheetScrim;

  @override
  bool get barrierDismissible => true;

  @override
  Duration get transitionDuration => VanaSheet.riseDuration;

  @override
  Duration get reverseTransitionDuration => VanaSheet.condenseDuration;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final media = MediaQuery.of(context);
    return _VanaSheetMotion(
      animation: animation,
      origin: VanaLauncher.centerOn(media.size),
      // The sheet sits on the keyboard and stops under the status bar; its
      // height inside that room is its own.
      padding: EdgeInsets.only(
        top: media.padding.top,
        bottom: media.viewInsets.bottom,
      ),
      child: builder(context),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) => child;
}

/// Rise on the way in, condense on the way out. The direction comes from the
/// animation's status, so whatever pops the route gets the condense. The tree
/// is the same shape both ways, so the sheet keeps its state as it goes.
class _VanaSheetMotion extends AnimatedWidget {
  const _VanaSheetMotion({
    required Animation<double> animation,
    required this.origin,
    required this.padding,
    required this.child,
  }) : super(listenable: animation);

  /// The launcher's centre, on the screen.
  final Offset origin;
  final EdgeInsets padding;
  final Widget child;

  Animation<double> get _animation => listenable as Animation<double>;

  @override
  Widget build(BuildContext context) {
    final a = _animation;
    final condensing =
        a.status == AnimationStatus.reverse ||
        a.status == AnimationStatus.dismissed;
    final rise = condensing ? 1.0 : VanaSheet.riseCurve.transform(a.value);
    final c = condensing ? VanaSheet.condenseCurve.transform(1 - a.value) : 0.0;
    return Transform.scale(
      scale: 1 - c * (1 - VanaSheet.condensedScale),
      alignment: Alignment.topLeft,
      origin: origin,
      child: Padding(
        padding: padding,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: FractionalTranslation(
            translation: Offset(0, 1 - rise),
            child: Opacity(
              opacity: 1 - c * (1 - VanaSheet.condensedOpacity),
              child: ClipPath(
                clipper: _CondenseClipper(c),
                clipBehavior: c == 0 ? Clip.none : Clip.antiAlias,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The corners round from the sheet's 24 into a circle as it shrinks.
class _CondenseClipper extends CustomClipper<Path> {
  const _CondenseClipper(this.progress);

  final double progress;

  @override
  Path getClip(Size size) {
    final radius =
        AppMaterials.sheetTopRadius +
        progress * (size.shortestSide / 2 - AppMaterials.sheetTopRadius);
    return Path()..addRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
    );
  }

  @override
  bool shouldReclip(_CondenseClipper oldClipper) =>
      oldClipper.progress != progress;
}
