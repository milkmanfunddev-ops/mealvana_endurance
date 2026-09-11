/// Design SSOT component — **Vana Sheet**'s launcher, and the **Vana
/// Moment** states it takes when Vana speaks first.
///
/// Specs: `docs/ssot/spec/design/components/vana-sheet.md` **PROPOSED v1**
/// (the launcher and its mark, Q-VS2) and
/// `docs/ssot/spec/design/components/vana-moment.md` **PROPOSED v1** (Lee,
/// 2026-09-11; both authored app-side, awaiting Xuan). The numbers are the
/// companion export's.
///
/// Contracts held here:
/// * **QUIET** — ~52 px circular `glass` with `lift`, dimmed like the
///   collapsed tab-bar button it mirrors, Vana's mark in cream, no label.
/// * **RING** — the mark drops in (scale 0.7 → 1.12 → 1 over 420 ms, the
///   export's `chDrop`) at 35 % while three dashed strokes trace the bubble
///   path, electrolyte to orange, fading out over their last 500 ms.
/// * **PILL** — a to-do's one line beside the mark, the launcher growing
///   leftwards into a capsule up to 240 px of text, clipped short of the
///   collapsed tab bar so the two never overlap.
/// * **TINTED** — the moment's tone (`orange` to-do, `electrolyte` news)
///   with a cream highlight from the top, the mark in `blackberry`.
/// * **Reduced motion** — no drop and no trace: a ring is drawn tinted.
///
/// Which state and for how long is the feature's: this widget draws the
/// state it is given and animates between them.
library;

import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_materials.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../materials/glass.dart';
import 'kyle_tab_bar.dart';

/// What the launcher is showing (vana-moment spec, States).
enum VanaLauncherState { quiet, ring, pill, tinted }

/// A moment's tone: a to-do is `orange`, news is `electrolyte`.
enum VanaLauncherTone { toDo, news }

/// The launcher in the bottom-right utility slot. Place it with
/// [VanaLauncher.rightInset] / [VanaLauncher.bottomInset] in a screen-sized
/// [Stack] so it lines up with the tab bar and with the sheet's condense. It
/// grows to the left when its pill shows.
class VanaLauncher extends StatefulWidget {
  const VanaLauncher({
    super.key,
    required this.semanticLabel,
    required this.onTap,
    this.state = VanaLauncherState.quiet,
    this.tone = VanaLauncherTone.toDo,
    this.pill,
  });

  /// "Ask Vana", or what the moment says — the launcher has no visible label
  /// at rest.
  final String semanticLabel;
  final VoidCallback onTap;

  final VanaLauncherState state;
  final VanaLauncherTone tone;

  /// The pill's one line. Shown in [VanaLauncherState.pill] only.
  final String? pill;

  /// The utility slot's diameter (tab-bar.md Q2).
  static const double size = KyleTabBar.utilitySlotSize;

  /// Mirrors the tab bar's 14 px left anchor on the opposite corner.
  static const double rightInset = 14;

  /// Centred on the expanded tab bar, which sits 28 px off the bottom edge
  /// (home_shell_chrome.dart).
  static const double bottomInset = 28 + (KyleTabBar.expandedHeight - size) / 2;

  /// The export's pill: at most 240 px of text, 16 px in from the capsule's
  /// left edge.
  static const double pillMaxWidth = 240;
  static const double pillInset = 16;

  static const Duration ringDuration = Duration(milliseconds: 2000);
  static const Duration dropDuration = Duration(milliseconds: 420);
  static const Duration traceFadeDelay = Duration(milliseconds: 1500);
  static const Cubic dropCurve = Cubic(0.2, 0.85, 0.2, 1);

  /// The pill opening and closing (the export's max-width transition).
  static const Duration pillDuration = Duration(milliseconds: 380);

  /// The tint coming in (the export's background transition).
  static const Duration tintDuration = Duration(milliseconds: 420);

  /// The launcher's centre on a screen of [screen] size — where the sheet
  /// condenses to.
  static Offset centerOn(Size screen) => Offset(
    screen.width - rightInset - size / 2,
    screen.height - bottomInset - size / 2,
  );

  /// How much text the pill may hold on a screen [screenWidth] wide: up to
  /// [pillMaxWidth], and never into the collapsed tab bar at the left edge.
  static double pillRoomOn(double screenWidth) {
    const collapsedBar =
        14 + KyleTabBar.collapsedSize + KyleTabBar.utilitySlotGap;
    final room = screenWidth - rightInset - size - pillInset - collapsedBar;
    return math.max(0, math.min(pillMaxWidth, room));
  }

  @override
  State<VanaLauncher> createState() => _VanaLauncherState();
}

class _VanaLauncherState extends State<VanaLauncher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ring = AnimationController(
    vsync: this,
    duration: VanaLauncher.ringDuration,
  );

  /// The drop, as the export keys it: 0.7 → 1.12 at 55 %, → 1.
  static final Animatable<double> _drop = TweenSequence<double>([
    TweenSequenceItem(
      tween: Tween(
        begin: 0.7,
        end: 1.12,
      ).chain(CurveTween(curve: VanaLauncher.dropCurve)),
      weight: 55,
    ),
    TweenSequenceItem(
      tween: Tween(
        begin: 1.12,
        end: 1.0,
      ).chain(CurveTween(curve: VanaLauncher.dropCurve)),
      weight: 45,
    ),
  ]);

  bool get _reduced => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncRing();
  }

  @override
  void didUpdateWidget(VanaLauncher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) _syncRing();
  }

  void _syncRing() {
    if (widget.state == VanaLauncherState.ring && !_reduced) {
      if (!_ring.isAnimating) _ring.forward(from: 0);
    } else {
      _ring.stop();
      _ring.value = 0;
    }
  }

  @override
  void dispose() {
    _ring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = _reduced;
    final ringing = widget.state == VanaLauncherState.ring && !reduced;
    final tinted =
        widget.state == VanaLauncherState.tinted ||
        widget.state == VanaLauncherState.pill ||
        (widget.state == VanaLauncherState.ring && reduced);
    final pill = widget.pill ?? '';
    final pillOpen = widget.state == VanaLauncherState.pill && pill.isNotEmpty;
    final ink = tinted ? AppColors.blackberry : AppColors.cream;
    final tone = switch (widget.tone) {
      VanaLauncherTone.toDo => AppColors.orange,
      VanaLauncherTone.news => AppColors.electrolyte,
    };
    final radius = BorderRadius.circular(VanaLauncher.size / 2);
    final motion = reduced ? Duration.zero : null;

    return Semantics(
      // Its own node: without it the label merges up into the app's root and
      // the whole screen reads as the launcher.
      container: true,
      button: true,
      label: widget.semanticLabel,
      excludeSemantics: true,
      child: GestureDetector(
        key: const ValueKey('vana_sheet.launcher'),
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedBuilder(
          animation: _ring,
          builder: (context, _) {
            final t = _ring.value * VanaLauncher.ringDuration.inMilliseconds;
            final drop = ringing
                ? _drop.transform(
                    math.min(1, t / VanaLauncher.dropDuration.inMilliseconds),
                  )
                : 1.0;
            return Transform.scale(
              scale: drop,
              alignment: Alignment.centerRight,
              child: GlassSurface(
                borderRadius: radius,
                lift: true,
                dimmed: true,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: AnimatedOpacity(
                        key: const ValueKey('vana_launcher.tint'),
                        opacity: tinted ? 1 : 0,
                        duration: motion ?? VanaLauncher.tintDuration,
                        curve: Curves.ease,
                        child: _Tint(color: tone, radius: radius),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Pill(
                          text: pill,
                          open: pillOpen,
                          ink: ink,
                          duration: motion ?? VanaLauncher.pillDuration,
                        ),
                        SizedBox.square(
                          dimension: VanaLauncher.size,
                          child: Center(
                            child: CustomPaint(
                              size: const Size.square(30),
                              painter: VanaMarkPainter(
                                color: ink,
                                opacity: ringing ? 0.35 : 1,
                              ),
                              foregroundPainter: ringing
                                  ? _TracePainter(elapsedMs: t)
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// The TINTED fill: the tone, and a cream highlight from the top.
class _Tint extends StatelessWidget {
  const _Tint({required this.color, required this.radius});

  final Color color;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(borderRadius: radius, color: color),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppMaterials.momentTintHighlight,
              AppMaterials.momentTintHighlight.withValues(alpha: 0),
            ],
            stops: const [0, AppMaterials.momentTintHighlightStop],
          ),
        ),
      ),
    );
  }
}

/// The pill's line, opening leftwards out of the launcher.
class _Pill extends StatelessWidget {
  const _Pill({
    required this.text,
    required this.open,
    required this.ink,
    required this.duration,
  });

  final String text;
  final bool open;
  final Color ink;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final room = VanaLauncher.pillRoomOn(MediaQuery.sizeOf(context).width);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: open ? 1 : 0),
      duration: duration,
      curve: VanaLauncher.dropCurve,
      builder: (context, t, child) => t == 0
          ? const SizedBox.shrink()
          : ClipRect(
              child: Align(
                alignment: Alignment.centerRight,
                widthFactor: t,
                child: Opacity(opacity: t, child: child),
              ),
            ),
      child: Padding(
        padding: const EdgeInsets.only(left: VanaLauncher.pillInset),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: room),
          child: Text(
            text,
            key: const ValueKey('vana_launcher.pill'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            // Chrome, like the tab bar's labels: it holds one line at any
            // text size.
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              fontFamily: AppTextStyles.apercu,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: ink,
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
  const VanaMarkPainter({required this.color, this.opacity = 1});

  final Color color;

  /// The mark dims under the ring's trace.
  final double opacity;

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

  /// Scales the canvas from the export's view box into [size].
  static void fitViewBox(Canvas canvas, Size size) {
    final scale = math.min(size.width, size.height) / _viewBoxSize;
    canvas.scale(scale);
    canvas.translate(-_viewBoxOrigin, -_viewBoxOrigin);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    fitViewBox(canvas, size);
    canvas.drawPath(
      bubble(),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _strokeWidth
        ..strokeJoin = StrokeJoin.round
        ..color = color.withValues(alpha: color.a * opacity),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(VanaMarkPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.opacity != opacity;
}

/// The RING's trace: three dashed strokes chasing round the bubble path, a
/// long electrolyte tail into an orange head, twice round every 1.8 s, with a
/// blurred copy under them for the glow. They fade out over the ring's last
/// 500 ms.
class _TracePainter extends CustomPainter {
  _TracePainter({required this.elapsedMs});

  final double elapsedMs;

  /// One lap is the path's length; the export runs two laps per 1.8 s.
  static const double _lapsPerMs = 2 / 1800;

  /// Each stroke's length as a share of the path, and how far behind the
  /// head it starts. All three end at the head.
  static final List<(double, double, Color)> _strokes = [
    (0.28, 0.35, AppColors.electrolyte),
    (
      0.165,
      0.56,
      Color.lerp(AppColors.electrolyte, AppColors.orangeLight, 0.3)!,
    ),
    (0.072, 1, AppColors.orange),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final fadeFrom = VanaLauncher.traceFadeDelay.inMilliseconds;
    final fadeSpan = VanaLauncher.ringDuration.inMilliseconds - fadeFrom;
    final fade = (1 - (elapsedMs - fadeFrom) / fadeSpan).clamp(0.0, 1.0);
    if (fade == 0) return;
    final metric = VanaMarkPainter.bubble().computeMetrics().first;
    final head = (elapsedMs * _lapsPerMs + 0.28) % 1;

    canvas.save();
    VanaMarkPainter.fitViewBox(canvas, size);
    for (final glow in [true, false]) {
      for (final (length, opacity, color) in _strokes) {
        canvas.drawPath(
          _dash(metric, head - length, head),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeWidth = glow ? 9 : 4
            ..maskFilter = glow
                ? const MaskFilter.blur(
                    BlurStyle.normal,
                    AppMaterials.momentTraceGlowSigma,
                  )
                : null
            ..color = color.withValues(
              alpha: opacity * fade * (glow ? 0.7 : 0.5),
            ),
        );
      }
    }
    canvas.restore();
  }

  /// The stretch of [metric] from [from] to [to], as shares of its length;
  /// wraps past the path's start.
  static Path _dash(PathMetric metric, double from, double to) {
    final length = metric.length;
    double at(double share) => (share % 1 + 1) % 1 * length;
    final start = at(from);
    final end = at(to);
    if (start <= end) return metric.extractPath(start, end);
    return metric.extractPath(start, length)
      ..addPath(metric.extractPath(0, end), Offset.zero);
  }

  @override
  bool shouldRepaint(_TracePainter oldDelegate) =>
      oldDelegate.elapsedMs != elapsedMs;
}
