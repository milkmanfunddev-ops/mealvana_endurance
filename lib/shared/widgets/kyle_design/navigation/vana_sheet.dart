/// Design SSOT component — **Vana Sheet** (the launcher and the summoned
/// glass sheet).
///
/// Spec: `spec/design/components/vana-sheet.md` in the QA repo, **PROPOSED**
/// (2026-09-10 revision, QA `9ffd92e`). Not yet ratified and not yet mirrored
/// to `docs/ssot/spec/design/components/vana-sheet.md` — the mirror waits on
/// tickets 04/05 of `.scratch/mealplanning`. Built against Q-VS1 (three
/// heights; this ticket ships the 75 % rest height, the grabber drag is ticket
/// 08) and Q-VS2 (the drawn speech-bubble mark) as the export answered them.
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
/// * **Launcher** — ~52 px circular glass, Vana's mark, no label.
/// * **Rise** 360 ms from the bottom edge; **condense** 470 ms back into the
///   launcher, transform origin at the launcher's own centre, rounding into a
///   circle as it shrinks. Every pop of [VanaSheetRoute] — scrim tap (VS-2),
///   system back (VS-2), the dismiss button, the full-screen hand-off (VS-3) —
///   runs the condense, so no dismissal slides the sheet off-screen (VS-9).
/// * The sheet does not resize while streaming (VS-4): its height depends on
///   the screen and the keyboard only.
///
/// What the sheet says is the persona's business: the body and composer are
/// slots the feature fills.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_materials.dart';
import '../../../../theme/kyle_design/app_theme.dart';
import '../materials/glass.dart';
import 'kyle_tab_bar.dart';

/// The launcher in the bottom-right utility slot. Place it with
/// [VanaLauncher.rightInset] / [VanaLauncher.bottomInset] in a screen-sized
/// [Stack] so it lines up with the tab bar and with the sheet's condense.
class VanaLauncher extends StatelessWidget {
  const VanaLauncher({
    super.key,
    required this.semanticLabel,
    required this.onTap,
  });

  /// "Ask Vana" — the launcher has no visible label.
  final String semanticLabel;
  final VoidCallback onTap;

  /// The utility slot's diameter (tab-bar.md Q2).
  static const double size = KyleTabBar.utilitySlotSize;

  /// Mirrors the tab bar's 14 px left anchor on the opposite corner.
  static const double rightInset = 14;

  /// Centred on the expanded tab bar, which sits 28 px off the bottom edge
  /// (home_shell_chrome.dart).
  static const double bottomInset =
      28 + (KyleTabBar.expandedHeight - size) / 2;

  /// The launcher's centre on a screen of [screen] size — where the sheet
  /// condenses to.
  static Offset centerOn(Size screen) => Offset(
    screen.width - rightInset - size / 2,
    screen.height - bottomInset - size / 2,
  );

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        key: const ValueKey('vana_sheet.launcher'),
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: GlassSurface(
          borderRadius: BorderRadius.circular(size / 2),
          lift: true,
          dimmed: true,
          child: const SizedBox.square(
            dimension: size,
            child: Center(
              child: CustomPaint(
                size: Size.square(30),
                painter: VanaMarkPainter(color: AppColors.cream),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Vana's mark (Q-VS2): a speech-bubble outline drawn as a path, the first
/// branded glyph on the shell. Geometry is the export's, a 52 × 52 bubble in a
/// −8…60 view box stroked at 4.
class VanaMarkPainter extends CustomPainter {
  const VanaMarkPainter({required this.color});

  final Color color;

  static const double _viewBoxOrigin = -8;
  static const double _viewBoxSize = 68;
  static const double _strokeWidth = 4;

  static Path bubble() => Path()
    ..moveTo(26, 0)
    ..cubicTo(40.4, 0, 52, 10.3, 52, 23)
    ..cubicTo(52, 35.7, 40.4, 46, 26, 46)
    ..cubicTo(22.6, 46, 19.4, 45.4, 16.4, 44.4)
    ..lineTo(5, 52)
    ..lineTo(8.6, 40.2)
    ..cubicTo(3.3, 36, 0, 29.9, 0, 23)
    ..cubicTo(0, 10.3, 11.6, 0, 26, 0)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = math.min(size.width, size.height) / _viewBoxSize;
    canvas.save();
    canvas.scale(scale);
    canvas.translate(-_viewBoxOrigin, -_viewBoxOrigin);
    canvas.drawPath(
      bubble(),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(VanaMarkPainter oldDelegate) => oldDelegate.color != color;
}

/// The sheet's chrome: `glass-sheet`, grabber, the full-screen and dismiss
/// buttons at the top-right, then the feature's [body] and [composer].
///
/// Always dark inside: `glass-sheet` is a dark-first material (tokens.md —
/// the light variant is deferred), so the content inherits the dark theme
/// whatever the app's mode.
class VanaSheet extends StatelessWidget {
  const VanaSheet({
    super.key,
    required this.body,
    required this.composer,
    required this.closeLabel,
    required this.fullScreenLabel,
    required this.onClose,
    required this.onFullScreen,
  });

  /// The conversation column.
  final Widget body;

  /// The composer row, pinned under the body.
  final Widget composer;

  final String closeLabel;
  final String fullScreenLabel;

  /// Dismiss — the caller pops the route, which condenses.
  final VoidCallback onClose;

  /// VS-3 — the caller opens the chat route with the same conversation.
  final VoidCallback onFullScreen;

  /// Q-VS1 rest height, a fraction of the screen. The page stays visible
  /// above it — that is the contract.
  static const double restHeightFraction = 0.75;

  static const Duration riseDuration = Duration(milliseconds: 360);
  static const Cubic riseCurve = Cubic(0.2, 0.85, 0.2, 1);
  static const Duration condenseDuration = Duration(milliseconds: 470);
  static const Cubic condenseCurve = Cubic(0.45, 0, 0.55, 1);

  /// Where the condense ends: scaled to 2 % and faded to 70 %, then gone.
  static const double condensedScale = 0.02;
  static const double condensedOpacity = 0.7;

  static final ThemeData _dark = AppTheme.darkTheme;

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _dark,
      child: GlassSheetSurface(
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            children: [
              SizedBox(
                height: 48,
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
                            label: fullScreenLabel,
                            onTap: onFullScreen,
                          ),
                          _ChromeButton(
                            key: const ValueKey('vana_sheet.close'),
                            icon: FontAwesomeIcons.xmark,
                            label: closeLabel,
                            onTap: onClose,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(child: body),
              SafeArea(top: false, child: composer),
            ],
          ),
        ),
      ),
    );
  }
}

/// The calendar sheet's grabber, so a second summoned sheet does not invent a
/// second vocabulary. Visual only here; the drag is ticket 08.
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
        color: AppColors.cream.withValues(alpha: 0.3),
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

  /// The sheet's height on this screen: the rest height, or less when the
  /// keyboard leaves less room.
  static double heightFor(MediaQueryData media) {
    final room =
        media.size.height - media.viewInsets.bottom - media.padding.top;
    return math.max(
      0,
      math.min(media.size.height * VanaSheet.restHeightFraction, room),
    );
  }

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    final media = MediaQuery.of(context);
    final height = heightFor(media);
    final top = media.size.height - media.viewInsets.bottom - height;
    final launcher = VanaLauncher.centerOn(media.size);
    return Align(
      alignment: Alignment.topLeft,
      child: Padding(
        padding: EdgeInsets.only(top: top),
        child: SizedBox(
          width: media.size.width,
          height: height,
          child: _VanaSheetMotion(
            animation: animation,
            height: height,
            // The launcher's centre, in the sheet's own coordinates.
            origin: Offset(launcher.dx, launcher.dy - top),
            child: builder(context),
          ),
        ),
      ),
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
/// animation's status, so whatever pops the route gets the condense.
class _VanaSheetMotion extends AnimatedWidget {
  const _VanaSheetMotion({
    required Animation<double> animation,
    required this.height,
    required this.origin,
    required this.child,
  }) : super(listenable: animation);

  final double height;
  final Offset origin;
  final Widget child;

  Animation<double> get _animation => listenable as Animation<double>;

  @override
  Widget build(BuildContext context) {
    final a = _animation;
    final condensing =
        a.status == AnimationStatus.reverse ||
        a.status == AnimationStatus.dismissed;
    if (!condensing) {
      final v = VanaSheet.riseCurve.transform(a.value);
      return Transform.translate(
        offset: Offset(0, (1 - v) * height),
        child: child,
      );
    }
    final c = VanaSheet.condenseCurve.transform(1 - a.value);
    final scale = 1 - c * (1 - VanaSheet.condensedScale);
    // The corners round from the sheet's 24 into a circle as it shrinks.
    final radius =
        AppMaterials.sheetTopRadius +
        c * (height / 2 - AppMaterials.sheetTopRadius);
    return Transform.scale(
      scale: scale,
      alignment: Alignment.topLeft,
      origin: origin,
      child: Opacity(
        opacity: 1 - c * (1 - VanaSheet.condensedOpacity),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: child,
        ),
      ),
    );
  }
}
