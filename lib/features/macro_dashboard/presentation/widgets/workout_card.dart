import 'package:flutter/material.dart';

import '../../domain/dashboard_models.dart';
import '../me_tokens.dart';

/// Workout card — component contract: docs/ssot/spec/design/components/
/// workout-card.md (RATIFIED v1). Reference rendering:
/// prototypes/macro-dashboard/index.html @ aa81d21.
///
/// Gestures (G1–G5, G7):
///  - Full right-swipe on PLANNED → [onMarkDone] (writes actual_time = now
///    upstream; planned_time is NEVER touched).
///  - Full right-swipe on DONE_CONFIRMED → [onMarkUndone] (clears
///    actual_time upstream).
///  - Right-swipe on DONE_VERIFIED is SUPPRESSED entirely (Q-D1): no reveal
///    renders, no translation past a token nudge — a Garmin fact is not
///    contradictable and no dead affordance is shown.
///  - Partial left-swipe reveals a labeled Delete in dragonfruit; deletion
///    happens only on the button press (two-step), never by the swipe.
///  - The card EMITS its state change via callbacks and never repaints only
///    itself (G7) — the surface owns whole-dashboard propagation (S-1).
class WorkoutCard extends StatefulWidget {
  const WorkoutCard({
    super.key,
    required this.data,
    this.onMarkDone,
    this.onMarkUndone,
    this.onDelete,
    this.onFuelTap,
  });

  final WorkoutCardData data;
  final VoidCallback? onMarkDone;
  final VoidCallback? onMarkUndone;
  final VoidCallback? onDelete;
  final VoidCallback? onFuelTap;

  @override
  State<WorkoutCard> createState() => _WorkoutCardState();
}

class _WorkoutCardState extends State<WorkoutCard> {
  double _dx = 0;
  bool _dragging = false;
  bool _revealOpen = false;

  static const double _deleteRevealWidth = 94;
  static const double _revealSettle = -108;
  static const double _openThreshold = -46;

  /// Q-D1: a verified card may translate at most this far — a token nudge —
  /// and never shows the done reveal.
  static const double _verifiedNudgeMax = 8;

  bool get _canToggle => !widget.data.isVerified;

  void _onDragStart(DragStartDetails _) {
    setState(() => _dragging = true);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    final width = context.size?.width ?? 300;
    var dx = _dx + details.delta.dx;
    if (dx > 0 && !_canToggle) {
      // G3 suppression: no reveal, token nudge only.
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
    final committed = _canToggle && _dx > width * 0.42;
    final openDelete = _dx < _openThreshold;
    setState(() {
      _dragging = false;
      _revealOpen = openDelete && !committed;
      _dx = _revealOpen ? _revealSettle : 0;
    });
    if (committed) {
      if (widget.data.isDone) {
        widget.onMarkUndone?.call();
      } else {
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
    final width = MediaQuery.sizeOf(context).width;
    final commit = _canToggle && _dx > width * 0.42;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: Stack(
        children: [
          // Right-swipe underlay (mark done / undone). Never rendered for a
          // verified card — G3's "no reveal renders".
          if (_dx > 0 && _canToggle)
            Positioned.fill(child: _doneUnderlay(commit)),
          // Left-swipe delete reveal.
          if (_dx < 0)
            Positioned(
              top: 0,
              right: 0,
              bottom: 0,
              child: _deleteReveal(),
            ),
          GestureDetector(
            // deferToChild: the hit area must follow the translated card —
            // an opaque full-width listener would swallow taps meant for
            // the revealed Delete button.
            behavior: HitTestBehavior.deferToChild,
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
                color: done
                    ? const Color.fromRGBO(54, 38, 62, 1)
                    : const Color.fromRGBO(55, 31, 57, 1),
                borderRadius: BorderRadius.circular(14),
                border: done
                    ? Border.all(color: MeTokens.electrolyteAlpha(0.3))
                    : null,
              ),
              foregroundDecoration: done
                  ? null
                  : _DottedBorderDecoration(
                      color: MeTokens.electrolyteAlpha(0.55),
                      strokeWidth: 1.5,
                      radius: 14,
                    ),
              padding: const EdgeInsets.all(13),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _iconDisc(done),
                  const SizedBox(width: 12),
                  Expanded(child: _body(done)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _doneUnderlay(bool commit) {
    final undoing = widget.data.isDone;
    final Color fill;
    final Color ink;
    if (undoing) {
      fill = commit
          ? MeTokens.creamAlpha(0.9)
          : MeTokens.creamAlpha(0.13);
      ink = commit ? MeTokens.blackberry : MeTokens.creamAlpha(0.75);
    } else {
      // The done-swipe fill is electrolyte — the burn/verified domain.
      fill = commit
          ? MeTokens.electrolyte
          : MeTokens.electrolyteAlpha(0.22);
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
            Icon(
              undoing ? Icons.replay : Icons.check,
              size: 17,
              color: ink,
            ),
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

  Widget _deleteReveal() {
    final enabled = _canToggle;
    return SizedBox(
      width: _deleteRevealWidth,
      child: Semantics(
        button: true,
        enabled: enabled,
        label: 'Delete',
        child: InkWell(
          onTap: enabled
              ? () {
                  _closeReveal();
                  widget.onDelete?.call();
                }
              : null,
          child: Container(
            // Destructive = dragonfruit, and nothing else (tokens.md).
            color: enabled
                ? MeTokens.dragonfruit
                : MeTokens.creamAlpha(0.09),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.delete_outline,
                  size: 16,
                  color: enabled
                      ? MeTokens.cream
                      : MeTokens.creamAlpha(0.32),
                ),
                const SizedBox(height: 4),
                Text(
                  'Delete',
                  style: TextStyle(
                    fontFamily: 'Apercu',
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: enabled
                        ? MeTokens.cream
                        : MeTokens.creamAlpha(0.32),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconDisc(bool done) {
    final icon = Icon(
      _sportIcon(widget.data.sport),
      size: 19,
      color: done ? MeTokens.blackberry : MeTokens.electrolyteAlpha(0.85),
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
    // Planned: hollow disc with the same dotted "not yet" edge as the card.
    return SizedBox(
      width: 40,
      height: 40,
      child: CustomPaint(
        painter: _DottedCirclePainter(
          color: MeTokens.electrolyteAlpha(0.6),
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

  Widget _body(bool done) {
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
            _chip(done),
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
        // End-of-day skipped prompt: planned treatment + a nudge to settle
        // "no sync" vs "didn't happen" — the athlete is the tiebreaker
        // (platform-resolution confirmation rung). Styling reuses the
        // reference rendering's swipe-hint row; exact copy pending design.
        if (data.state == WorkoutCardState.skippedPrompt) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.help_outline,
                size: 12,
                color: MeTokens.creamAlpha(0.4),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  'Did this happen? Swipe right to mark done',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Apercu',
                    fontSize: 10,
                    color: MeTokens.creamAlpha(0.4),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _chip(bool done) {
    final data = widget.data;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: done
            ? MeTokens.electrolyteAlpha(0.16)
            : MeTokens.electrolyteAlpha(0.1),
        borderRadius: BorderRadius.circular(100),
        border: done
            ? null
            : Border.all(color: MeTokens.electrolyteAlpha(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (done) ...[
            Icon(
              Icons.check,
              size: 9,
              color: done
                  ? MeTokens.electrolyte
                  : MeTokens.electrolyteAlpha(0.9),
            ),
            const SizedBox(width: 3),
          ],
          Text(
            data.chipLabel,
            style: TextStyle(
              fontFamily: 'Apercu',
              fontSize: 9.5,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.4,
              color: done
                  ? MeTokens.electrolyte
                  : MeTokens.electrolyteAlpha(0.9),
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
        canvas.drawPath(
          metric.extractPath(distance, distance + dash),
          paint,
        );
        distance += dash + gap;
      }
    }
  }
}
