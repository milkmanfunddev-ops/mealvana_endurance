import 'package:flutter/material.dart';

import '../../domain/dashboard_models.dart';
import '../me_tokens.dart';

/// Workout card — component contract: docs/ssot/spec/design/components/
/// workout-card.md (RATIFIED v2 — Q-D6 unified-skip model). Reference
/// rendering: prototypes/macro-dashboard/index.html @ 5a22ca8.
///
/// Gestures (G1–G7):
///  - Full right-swipe on PLANNED / SKIPPED → [onMarkDone] (writes
///    actual_time = planned_time upstream — the card stays on its day and
///    slot; planned_time is NEVER touched; a skipped row's status returns to
///    planned). Suppressed on a FUTURE day's card (ruled 2026-08-18).
///  - Full right-swipe on DONE_CONFIRMED → [onMarkUndone] (clears
///    actual_time upstream → the day's unresolved state).
///  - ANY swipe on DONE_VERIFIED is SUPPRESSED entirely (G3, both
///    directions in v2): no reveal renders, no translation past a token
///    nudge, no Skip/Unskip affordance — a Garmin fact is not
///    contradictable and no dead affordance is shown.
///  - Partial left-swipe reveals a labeled, NEUTRAL button (dimmed cream on
///    a translucent field — never dragonfruit; skipping is not destructive):
///    `Skip` on PLANNED / DONE_CONFIRMED, `Unskip` on an actively-skipped
///    card. A passively skipped past-day card reveals no button (recovery
///    there is G1 only). Skip/unskip happen only on the button press, never
///    by the swipe itself.
///  - The card EMITS its state change via callbacks and never repaints only
///    itself (G7) — the surface owns whole-dashboard propagation (S-1).
class WorkoutCard extends StatefulWidget {
  const WorkoutCard({
    super.key,
    required this.data,
    this.onTap,
    this.onMarkDone,
    this.onMarkUndone,
    this.onSkip,
    this.onUnskip,
    this.onFuelTap,
  });

  final WorkoutCardData data;

  /// Tap into the card → the existing workout detail surface (the tapped-into
  /// view is deliberately untouched by this redesign — scope ruling). When
  /// the skip reveal is open, a tap closes the reveal instead.
  final VoidCallback? onTap;
  final VoidCallback? onMarkDone;
  final VoidCallback? onMarkUndone;

  /// G5 Skip press: upstream writes status = 'skipped' (and clears
  /// actual_time if the card was DONE_CONFIRMED).
  final VoidCallback? onSkip;

  /// G5 Unskip press: upstream clears status; planned_time untouched.
  final VoidCallback? onUnskip;
  final VoidCallback? onFuelTap;

  @override
  State<WorkoutCard> createState() => _WorkoutCardState();
}

class _WorkoutCardState extends State<WorkoutCard> {
  double _dx = 0;
  bool _dragging = false;
  bool _revealOpen = false;

  static const double _skipRevealWidth = 94;
  static const double _revealSettle = -108;
  static const double _openThreshold = -46;

  /// G3: a verified card may translate at most this far — a token nudge, in
  /// either direction — and never shows a reveal.
  static const double _verifiedNudgeMax = 8;

  /// Left-swipe (skip) and any translation at all: only a verified card is
  /// fully inert (G3).
  bool get _canToggle => !widget.data.isVerified;

  /// Right-swipe (mark done / undone): additionally suppressed on a
  /// planned/skipped card whose day is in the future — a workout that hasn't
  /// happened cannot be confirmed (ruled 2026-08-18). Undone stays available.
  bool get _canRightSwipe =>
      _canToggle && (widget.data.isDone || widget.data.markDoneAllowed);

  void _onDragStart(DragStartDetails _) {
    setState(() => _dragging = true);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final width = context.size?.width ?? 300;
    var dx = _dx + details.delta.dx;
    if (!_canToggle) {
      // G3 suppression (both directions): no reveal, token nudge only.
      dx = dx.clamp(-_verifiedNudgeMax, _verifiedNudgeMax);
    } else if (!_canRightSwipe && dx > 0) {
      // Future-day planned card: no done reveal, token nudge only.
      dx = dx.clamp(0, _verifiedNudgeMax);
    }
    if (dx < _revealSettle) {
      dx = _revealSettle + (dx - _revealSettle) * 0.22; // rubber-band
    }
    if (dx > width * 0.72) dx = width * 0.72;
    setState(() => _dx = dx);
  }

  void _onDragEnd(DragEndDetails _) {
    final width = context.size?.width ?? 300;
    final committed = _canRightSwipe && _dx > width * 0.42;
    final openSkip = _canToggle && _dx < _openThreshold;
    setState(() {
      _dragging = false;
      _revealOpen = openSkip && !committed;
      _dx = _revealOpen ? _revealSettle : 0;
    });
    if (committed) {
      if (widget.data.isDone) {
        widget.onMarkUndone?.call();
      } else {
        // PLANNED or SKIPPED → DONE_CONFIRMED (G1; a skipped row's status
        // returns to planned upstream).
        widget.onMarkDone?.call();
      }
    }
  }

  void _closeReveal() {
    setState(() {
      _revealOpen = false;
      _dx = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final done = data.isDone;
    final skipped = data.isSkipped;
    final width = MediaQuery.sizeOf(context).width;
    final commit = _canRightSwipe && _dx > width * 0.42;

    // Skins (reference rendering @ 5a22ca8, decorate()): done = solid fill +
    // solid electrolyte border; planned = dotted electrolyte edge; skipped =
    // the planned treatment DRAINED TO NEUTRAL (dotted cream edge, dimmed
    // fill — no electrolyte, no orange anywhere on the card).
    final Color fill;
    final Border? border;
    final Decoration? dottedEdge;
    if (done) {
      fill = const Color.fromRGBO(54, 38, 62, 1);
      border = Border.all(color: MeTokens.electrolyteAlpha(0.3));
      dottedEdge = null;
    } else if (skipped) {
      fill = const Color.fromRGBO(255, 255, 255, 0.03);
      border = null;
      dottedEdge = _DottedBorderDecoration(
        color: MeTokens.creamAlpha(0.26),
        strokeWidth: 1.5,
        radius: 14,
      );
    } else {
      fill = const Color.fromRGBO(55, 31, 57, 1);
      border = null;
      dottedEdge = _DottedBorderDecoration(
        color: MeTokens.electrolyteAlpha(0.55),
        strokeWidth: 1.5,
        radius: 14,
      );
    }

    final card = ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          // Right-swipe underlay (mark done / undone). Never rendered for a
          // verified card (G3) nor for a future-day planned card.
          if (_dx > 0 && _canRightSwipe)
            Positioned.fill(child: _doneUnderlay(commit)),
          // Left-swipe skip reveal — never for a verified card (G3).
          if (_dx < 0 && _canToggle)
            Positioned(top: 0, right: 0, bottom: 0, child: _skipReveal()),
          GestureDetector(
            // deferToChild: the hit area must follow the translated card —
            // an opaque full-width listener would swallow taps meant for
            // the revealed Skip button.
            behavior: HitTestBehavior.deferToChild,
            onTap: () {
              if (_revealOpen) {
                _closeReveal();
              } else {
                widget.onTap?.call();
              }
            },
            onHorizontalDragStart: _onDragStart,
            onHorizontalDragUpdate: _onDragUpdate,
            onHorizontalDragEnd: _onDragEnd,
            child: AnimatedContainer(
              duration: _dragging
                  ? Duration.zero
                  : const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              transform: Matrix4.translationValues(_dx, 0, 0),
              decoration: BoxDecoration(
                color: fill,
                borderRadius: BorderRadius.circular(14),
                border: border,
              ),
              foregroundDecoration: dottedEdge,
              padding: const EdgeInsets.all(13),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _iconDisc(done, skipped),
                  const SizedBox(width: 12),
                  Expanded(child: _body(done, skipped)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
    // Outside-tap dismiss: the reference rendering's reveal never
    // auto-dismisses — that is prototype defect W-6, which the SSOT lists as
    // a known reference-rendering defect NOT to encode (workout-card.md,
    // "Known reference-rendering defects"). A tap landing anywhere outside
    // this card closes an open reveal; taps inside (card body, Skip/Unskip
    // button) keep their existing behavior via the GestureDetector above.
    return TapRegion(
      onTapOutside: (_) {
        if (_revealOpen) _closeReveal();
      },
      child: card,
    );
  }

  Widget _doneUnderlay(bool commit) {
    final undoing = widget.data.isDone;
    final Color fill;
    final Color ink;
    if (undoing) {
      fill = commit ? MeTokens.creamAlpha(0.9) : MeTokens.creamAlpha(0.13);
      ink = commit ? MeTokens.blackberry : MeTokens.creamAlpha(0.75);
    } else {
      // The done-swipe fill is electrolyte — the burn/verified domain.
      fill = commit ? MeTokens.electrolyte : MeTokens.electrolyteAlpha(0.22);
      ink = commit ? MeTokens.blackberry : MeTokens.electrolyte;
    }
    final opacity = ((_dx - 6) / 44).clamp(0.0, 1.0);
    return Container(
      color: fill,
      padding: const EdgeInsets.symmetric(horizontal: 17),
      alignment: Alignment.centerLeft,
      child: Opacity(
        opacity: opacity,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(undoing ? Icons.replay : Icons.check, size: 17, color: ink),
            const SizedBox(width: 8),
            Text(
              undoing ? 'Mark undone' : 'Mark done',
              style: TextStyle(
                fontFamily: 'Apercu',
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: ink,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// G4: the left-swipe reveal. Neutral treatment — dimmed cream on a
  /// translucent field (reference: rgba(cream,0.14) field, cream ink) —
  /// NEVER dragonfruit: skipping is not destructive and the token contract
  /// forbids it. `Skip` on PLANNED / DONE_CONFIRMED, `Unskip` on an actively
  /// skipped card; a passively skipped past-day card has nothing to un-skip,
  /// so the field carries no button (recovery there is G1 only).
  Widget _skipReveal() {
    final data = widget.data;
    final unskip = data.isSkipped && data.skipActive;
    final hasButton = !data.isSkipped || data.skipActive;
    return SizedBox(
      width: _skipRevealWidth,
      child: Container(
        color: MeTokens.creamAlpha(0.14),
        child: hasButton
            ? Semantics(
                button: true,
                label: unskip ? 'Unskip' : 'Skip',
                child: InkWell(
                  key: ValueKey(
                    unskip
                        ? 'macro_dashboard.unskip_button'
                        : 'macro_dashboard.skip_button',
                  ),
                  onTap: () {
                    _closeReveal();
                    if (unskip) {
                      widget.onUnskip?.call();
                    } else {
                      widget.onSkip?.call();
                    }
                  },
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        unskip ? Icons.replay : Icons.block,
                        size: 16,
                        color: MeTokens.cream,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        unskip ? 'Unskip' : 'Skip',
                        style: const TextStyle(
                          fontFamily: 'Apercu',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: MeTokens.cream,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _iconDisc(bool done, bool skipped) {
    final icon = Icon(
      _sportIcon(widget.data.sport),
      size: 19,
      color: done
          ? MeTokens.blackberry
          : skipped
          ? MeTokens.creamAlpha(0.42)
          : MeTokens.electrolyteAlpha(0.85),
    );
    if (done) {
      return Container(
        width: 40,
        height: 40,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: MeTokens.electrolyte,
        ),
        alignment: Alignment.center,
        child: icon,
      );
    }
    // Planned: hollow disc with the same dotted "not yet" edge as the card;
    // skipped: the same disc drained to neutral.
    return SizedBox(
      width: 40,
      height: 40,
      child: CustomPaint(
        painter: _DottedCirclePainter(
          color: skipped
              ? MeTokens.creamAlpha(0.3)
              : MeTokens.electrolyteAlpha(0.6),
          strokeWidth: 1.5,
        ),
        child: Center(child: icon),
      ),
    );
  }

  IconData _sportIcon(String sport) => switch (sport) {
    'swimming' => Icons.pool,
    'cycling' => Icons.directions_bike,
    'strength' => Icons.fitness_center,
    _ => Icons.directions_run,
  };

  Widget _body(bool done, bool skipped) {
    final data = widget.data;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                data.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: 'Compadre',
                  fontSize: 17,
                  color: MeTokens.cream,
                ),
              ),
            ),
            const SizedBox(width: 8),
            _chip(done, skipped),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          data.metaLabel,
          style: TextStyle(
            fontFamily: 'Apercu',
            fontSize: 11,
            color: MeTokens.creamAlpha(0.55),
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        // The fuel link is an orange (intake) element; a SKIPPED card carries
        // no orange and its fuel windows have left the day (S-2), so the
        // link is not rendered there.
        if (!skipped) ...[
          const SizedBox(height: 5),
          GestureDetector(
            onTap: widget.onFuelTap,
            child: const Text(
              'Pre · During · Recovery fuel ›',
              style: TextStyle(
                fontFamily: 'Apercu',
                fontSize: 10.5,
                color: MeTokens.orange,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _chip(bool done, bool skipped) {
    final data = widget.data;
    // Chip skins: done = electrolyte on translucent electrolyte; planned =
    // electrolyte outline; skipped = neutral (dimmed cream) — the chip is the
    // whole signal of a skipped card.
    final Color chipFill;
    final Border? chipBorder;
    final Color ink;
    if (done) {
      chipFill = MeTokens.electrolyteAlpha(0.16);
      chipBorder = null;
      ink = MeTokens.electrolyte;
    } else if (skipped) {
      chipFill = MeTokens.creamAlpha(0.07);
      chipBorder = Border.all(color: MeTokens.creamAlpha(0.22));
      ink = MeTokens.creamAlpha(0.6);
    } else {
      chipFill = MeTokens.electrolyteAlpha(0.1);
      chipBorder = Border.all(color: MeTokens.electrolyteAlpha(0.35));
      ink = MeTokens.electrolyteAlpha(0.9);
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: chipFill,
        borderRadius: BorderRadius.circular(100),
        border: chipBorder,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (done) ...[
            Icon(Icons.check, size: 9, color: ink),
            const SizedBox(width: 3),
          ],
          Text(
            data.chipLabel,
            style: TextStyle(
              fontFamily: 'Apercu',
              fontSize: 9.5,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.4,
              color: ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dotted circle (the planned card's hollow icon disc).
class _DottedCirclePainter extends CustomPainter {
  const _DottedCirclePainter({required this.color, required this.strokeWidth});

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..addOval(
        Rect.fromLTWH(
          strokeWidth / 2,
          strokeWidth / 2,
          size.width - strokeWidth,
          size.height - strokeWidth,
        ),
      );
    const dash = 2.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DottedCirclePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

/// Dotted rounded-rect border (the planned card's "not yet" edge — Flutter
/// has no native dotted BorderStyle).
class _DottedBorderDecoration extends Decoration {
  const _DottedBorderDecoration({
    required this.color,
    required this.strokeWidth,
    required this.radius,
  });

  final Color color;
  final double strokeWidth;
  final double radius;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) =>
      _DottedBorderPainter(this);
}

class _DottedBorderPainter extends BoxPainter {
  _DottedBorderPainter(this.decoration);

  final _DottedBorderDecoration decoration;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final rect = offset & (configuration.size ?? Size.zero);
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(decoration.strokeWidth / 2),
      Radius.circular(decoration.radius),
    );
    final paint = Paint()
      ..color = decoration.color
      ..style = PaintingStyle.stroke
      ..strokeWidth = decoration.strokeWidth
      ..strokeCap = StrokeCap.round;

    final path = Path()..addRRect(rrect);
    const dash = 2.0;
    const gap = 4.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
        distance += dash + gap;
      }
    }
  }
}
