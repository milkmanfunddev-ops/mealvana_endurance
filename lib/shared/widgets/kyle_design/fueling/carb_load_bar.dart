/// Design SSOT component — **Carb Load Bar** (the loading-day loader).
///
/// Spec: `docs/ssot/spec/design/components/energy-card.md` §LOAD-face
/// amendment (RULED Xuan 2026-09-24, Q-D9 form 2026-09-25) — the face's
/// continuous loader bar; also recapped at a smaller height on the breakdown
/// page (`surfaces/carb-loading-dashboard.md`). Reference rendering:
/// prototype v22 (`fuel-timeline-standalone.html`, bundle sha
/// `f1c232d958a98bfe`) — track/fill gradients, tick geometry and the LOADED
/// variant below are that rendering's, verbatim.
///
/// Contracts held here:
/// * Continuous fill — never segmented; the unloaded track fades toward the
///   tail; the fill runs dimmer at its start and hottest at the leading edge.
/// * The cream pace tick marks where the ramp says the athlete should be
///   (`tickFrac`); it hides when nothing is owed, when the day is loaded,
///   and on every non-today variant — with the tick hidden the bar reads
///   fill-of-target, with it shown it reads pace.
/// * LOADED brightens the fill and its glow; fill is capped at 1.0 upstream
///   (engine CL-9) — this widget clamps defensively but never restyles an
///   overshoot (`547 of 544` renders as a full bar, actual grams live in the
///   copy).
/// * Glow: FIRST RATIFIED USE of the emphasis material (`tokens.md`
///   §Materials, desk 2026-09-25) alongside the LOAD face card. Layered
///   shadows per the ratified implementation reference
///   (`.scratch/carb-loading/glow-research.md`): a tight bright pass + a
///   wide soft pass — never `BackdropFilter`.
///
/// Tokens (`tokens.md`): fill/glow `orange` (Q-D3 — carbs are intake side),
/// tick `cream`, track `cream` at low alpha over the card surface.
library;

import 'package:flutter/material.dart';

import '../../../../theme/kyle_design/app_colors.dart';

class CarbLoadBar extends StatelessWidget {
  const CarbLoadBar({
    super.key,
    required this.fillFrac,
    required this.tickFrac,
    required this.loaded,
    this.height = 26,
  });

  /// 0..1 share of the day target eaten.
  final double fillFrac;

  /// 0..1 pace-tick position, or null when the tick is hidden.
  final double? tickFrac;

  final bool loaded;

  /// 26 on the LOAD face; the breakdown page recaps at 14.
  final double height;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(height / 2);
    final fill = fillFrac.clamp(0.0, 1.0);
    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Track: fades toward the tail.
              Container(
                decoration: BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(
                    color: AppColors.orange.withValues(alpha: 0.45),
                  ),
                  gradient: LinearGradient(
                    colors: [
                      AppColors.cream.withValues(alpha: 0.11),
                      AppColors.cream.withValues(alpha: 0.02),
                    ],
                  ),
                ),
              ),
              // Fill: dim start, hot leading edge; layered glow.
              if (fill > 0)
                Positioned(
                  left: height * 0.12,
                  top: height * 0.12,
                  bottom: height * 0.12,
                  width: (w - height * 0.24) * fill,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(height * 0.38),
                      gradient: loaded
                          ? const LinearGradient(
                              colors: [
                                AppColors.orange,
                                Color(0xFFFFB25C),
                                AppColors.orange,
                              ],
                            )
                          : LinearGradient(
                              colors: [
                                AppColors.orange.withValues(alpha: 0.55),
                                AppColors.orange,
                                const Color(0xFFFFB25C),
                                const Color(0xFFFFD9A4),
                              ],
                              stops: const [0.0, 0.52, 0.84, 1.0],
                            ),
                      boxShadow: [
                        // Tight bright pass.
                        BoxShadow(
                          color: AppColors.orange.withValues(
                            alpha: loaded ? 0.75 : 0.55,
                          ),
                          blurRadius: loaded ? 8 : 6,
                        ),
                        // Wide soft pass.
                        BoxShadow(
                          color: AppColors.orange.withValues(alpha: 0.25),
                          blurRadius: loaded ? 20 : 16,
                        ),
                      ],
                    ),
                  ),
                ),
              // Cream pace tick.
              if (tickFrac != null)
                Positioned(
                  left: (w - 2) * tickFrac!.clamp(0.0, 1.0),
                  top: -height * 0.15,
                  bottom: -height * 0.15,
                  width: 2,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.cream.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
