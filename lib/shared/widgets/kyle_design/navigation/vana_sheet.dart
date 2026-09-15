/// Design SSOT component — **Vana Sheet** (the launcher and the summoned
/// glass sheet).
///
/// Spec: `docs/ssot/spec/design/components/vana-sheet.md`, **PROPOSED v2**
/// (app-authored 2026-09-15 for ticket 27, awaiting Xuan's ratification in the
/// QA repo). v2 replaces Q-VS1's three heights with one (mp-265). Q-VS2 (the
/// drawn speech-bubble mark) stands.
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
///   system back (VS-2), a drag down (VS-7), the dismiss button, the
///   full-screen hand-off (VS-3) — runs the condense, so no dismissal slides
///   the sheet off-screen (VS-9). The composer lets go of focus as the pop
///   starts (the route's focus scope does that), so the keyboard goes too.
/// * **One height** (mp-265) — [VanaSheet.heightFraction] of the screen, and
///   the contents scroll inside it. Nothing grows with what the sheet holds,
///   on send, or while Vana streams; there is no expanded state. Full screen
///   is only the full-screen button. Only the keyboard takes room from it.
/// * **Dismiss by drag** (VS-7) — a plain drag down, by the platform bottom
///   sheet's own rule: past half the sheet, or a flick. No custom thresholds.
/// * One widget tree shape, so nothing remounts the composer mid-drag.
///
/// What the sheet says is the persona's business: the body and composer are
/// slots the feature fills, composed from the inside's widgets in
/// `vana_sheet_conversation.dart` (status chip, message treatments, quick
/// replies, composer), exported from here.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_materials.dart';
import '../../../../theme/kyle_design/app_theme.dart';
import '../materials/glass.dart';
import 'vana_launcher.dart';

export 'vana_launcher.dart';
export 'vana_sheet_conversation.dart';

/// The sheet's chrome: `glass-sheet`, grabber, the full-screen and dismiss
/// buttons at the top-right, then the feature's [body] and [composer], at one
/// height.
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
  });

  /// The conversation, laid out in the room between the chrome and the
  /// composer. It scrolls itself.
  final Widget body;

  /// The composer row, pinned under the body.
  final Widget composer;

  final String closeLabel;
  final String fullScreenLabel;

  /// Dismiss — the caller pops the route, which condenses. A drag down past
  /// the dismiss rule calls it too.
  final VoidCallback onClose;

  /// VS-3 — the caller opens the chat route with the same conversation.
  final VoidCallback onFullScreen;

  /// The one height, a fraction of the screen (mp-265).
  static const double heightFraction = 0.75;

  static const Duration riseDuration = Duration(milliseconds: 360);
  static const Cubic riseCurve = Cubic(0.2, 0.85, 0.2, 1);
  static const Duration condenseDuration = Duration(milliseconds: 470);
  static const Cubic condenseCurve = Cubic(0.45, 0, 0.55, 1);

  /// The spring back from a drag that did not dismiss.
  static const Duration settleDuration = Duration(milliseconds: 320);

  /// Where the condense ends: scaled to 2 % and faded to 70 %, then gone.
  static const double condensedScale = 0.02;
  static const double condensedOpacity = 0.7;

  /// The platform bottom sheet's dismiss rule (Material `BottomSheet`): a
  /// drag past this share of the sheet's height, or a flick faster than
  /// [minFlingVelocity], dismisses.
  static const double closeProgressThreshold = 0.5;
  static const double minFlingVelocity = 700;

  /// The chrome row above the body: grabber and buttons. The whole row is
  /// the drag target.
  static const double chromeHeight = 48;

  static final ThemeData _dark = AppTheme.darkTheme;

  @override
  State<VanaSheet> createState() => _VanaSheetState();
}

class _VanaSheetState extends State<VanaSheet>
    with SingleTickerProviderStateMixin {
  /// How far down the finger has moved the sheet.
  double _offset = 0;

  /// The spring back, from [_fromOffset] to rest.
  late final AnimationController _settle = AnimationController(
    vsync: this,
    duration: VanaSheet.settleDuration,
    value: 1,
  )..addListener(() => setState(() {}));
  double _fromOffset = 0;

  /// The height as last laid out, for the dismiss rule.
  double _height = 0;

  @override
  void dispose() {
    _settle.dispose();
    super.dispose();
  }

  void _springBack() {
    _fromOffset = _offset;
    _offset = 0;
    _settle.forward(from: 0);
  }

  void _dragStart(DragStartDetails _) {
    _fromOffset = 0;
    _settle.value = 1;
  }

  void _dragUpdate(DragUpdateDetails details) {
    setState(
      () => _offset = math.max(0, _offset + (details.primaryDelta ?? 0)),
    );
  }

  void _dragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    final dismiss =
        velocity > VanaSheet.minFlingVelocity ||
        (velocity >= 0 &&
            _offset > _height * VanaSheet.closeProgressThreshold);
    _springBack();
    // VS-7: the VS-2 path, and the condense.
    if (dismiss) widget.onClose();
  }

  void _dragCancel() => _springBack();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screen = MediaQuery.sizeOf(context).height;
        final room = constraints.hasBoundedHeight
            ? constraints.maxHeight
            : screen;
        final height = math.min(screen * VanaSheet.heightFraction, room);
        _height = height;
        final offset = _settle.isAnimating
            ? _fromOffset *
                  (1 - VanaSheet.riseCurve.transform(_settle.value))
            : _offset;

        return Theme(
          data: VanaSheet._dark,
          child: Transform.translate(
            offset: Offset(0, offset),
            child: SizedBox(
              width: double.infinity,
              height: height,
              child: GlassSheetSurface(
                child: Material(
                  type: MaterialType.transparency,
                  child: Column(
                    children: [
                      _chrome(),
                      Expanded(child: widget.body),
                      SafeArea(top: false, child: widget.composer),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// The grabber row. Dragging anywhere on it (the buttons keep their taps)
  /// moves the sheet down; the transcript below keeps its own scroll.
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
            const Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.only(top: 10),
                child: _Grabber(),
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
