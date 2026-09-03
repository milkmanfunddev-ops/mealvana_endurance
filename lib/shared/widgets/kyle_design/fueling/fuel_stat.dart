/// Design SSOT component — **Fuel Stat** (figure + band).
///
/// Spec: `docs/ssot/spec/design/components/fuel-stat.md` **v1** (RATIFIED
/// Xuan 2026-08-26). Reference rendering
/// `docs/ssot/spec/design/renderings/pre-workout@v2.html` — the band/marker
/// values below (opacities, offsets) are that rendering's, verbatim. The
/// FIGURE typography follows the PHASE-CARD VISUAL PARITY ruling as AMENDED
/// (surface `pre-workout-before-card.md`, Xuan 2026-09-01, qa `127e993`):
/// the shared `MacroSummaryRow` figure style — `dataNumber` 16 px bold,
/// exactly the shared size — replaces the rendering's Sansita 30 hero.
/// Display only: every contract below (F-1/F-2, M-1…M-5) is unchanged.
///
/// One summary quantity (carbs · fluids · sodium) with its optional band.
/// Three instances compose the BEFORE summary row (surface
/// `pre-workout-before-card.md` v1).
///
/// Contracts held here (as amended by **AMENDMENT A1**, Xuan 2026-09-03 —
/// the fasted product state is retired, food-recommendation §7 / D-001):
/// * **F-1 (A1)** — two distinct "no number" states, not three: a real `0g`
///   TARGETED figure ("we recommend none", band suppressed) and "No fluid
///   target for this session" (the gate — "we're not stating a target").
///   The fasted `CARBS · NONE` row and its "No carbs this session" copy are
///   retired; the distinctness rule is unchanged for the remaining pair.
/// * **F-2** — sodium has no band, ever.
/// * **M-1** — two markers: the *delivered* diamond (moves with food rows)
///   and the *suggested* triangle (moves only with the engine target).
/// * **M-2** — signalling is one-way for fluid, two-way for carbs; only the
///   delivered marker recolours (to `dragonfruit`, Q-D9).
/// * **M-3** — the suggested marker on a band end is not an alarm.
/// * **M-4** — no basis signifier: every band renders identically whatever
///   `targetBasis` is (solid rail, no caption).
/// * **M-5** — figures arrive already in whole oz / g (the assembler's job).
///
/// Tokens (`tokens.md`): figure `electrolyte` (Q-D8, per-workout fuel side),
/// sodium figure `cream` at .8, suggested marker `orange`, delivered marker
/// `electrolyte` / `dragonfruit` (out-of-band, Q-D9), rail `cream` at .45.
library;

import 'package:flutter/material.dart';

import '../../../../features/nutrition_plan/domain/pre_workout_before_card_model.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import 'fueling_glyphs.dart';

class FuelStat extends StatelessWidget {
  const FuelStat({super.key, required this.data});

  final FuelStatData data;

  static Key figureKey(FuelQuantity q) => Key('fuel_stat.${q.name}.figure');
  static Key absentKey(FuelQuantity q) => Key('fuel_stat.${q.name}.absent');
  static Key bandKey(FuelQuantity q) => Key('fuel_stat.${q.name}.band');
  static Key deliveredMarkerKey(FuelQuantity q) =>
      Key('fuel_stat.${q.name}.delivered_marker');
  static Key suggestedMarkerKey(FuelQuantity q) =>
      Key('fuel_stat.${q.name}.suggested_marker');

  @override
  Widget build(BuildContext context) {
    final isSodium = data.quantity == FuelQuantity.sodium;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (data.showFigure)
          Text(
            '${data.delivered}${data.unit}',
            key: figureKey(data.quantity),
            textAlign: TextAlign.center,
            // Parity ruling: the shared `MacroSummaryRow` figure style.
            style: AppTextStyles.dataNumber.copyWith(
              color: isSodium ? creamAlpha(.8) : AppColors.electrolyte,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        const SizedBox(height: 6),
        Text(
          data.label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: AppTextStyles.apercu,
            fontSize: 11,
            letterSpacing: 11 * .1,
            color: creamAlpha(.65),
          ),
        ),
        if (data.absentLine != null) ...[
          const SizedBox(height: 8),
          Text(
            data.absentLine!,
            key: absentKey(data.quantity),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppTextStyles.apercu,
              fontSize: 11,
              height: 1.4,
              color: creamAlpha(.5),
            ),
          ),
        ],
        if (data.showBand) ...[
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Column(
              key: bandKey(data.quantity),
              children: [
                _Band(data: data),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _endLabel('${data.bandLow}${data.unit}'),
                    _endLabel('${data.bandHigh}${data.unit}'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _endLabel(String text) => Text(
    text,
    style: TextStyle(
      fontFamily: AppTextStyles.apercu,
      fontSize: 11,
      color: creamAlpha(.6),
    ),
  );
}

/// The rail (3 px, cream .45, radius 2) with the suggested triangle beneath
/// (orange, 8 wide × 5 high, 8 px below the rail top) and the delivered
/// diamond on it (9 × 9 rotated 45°, 3 px above the rail top).
class _Band extends StatelessWidget {
  const _Band({required this.data});

  final FuelStatData data;

  @override
  Widget build(BuildContext context) {
    final deliveredColor = data.deliveredOutOfBand
        ? AppColors.dragonfruit
        : AppColors.electrolyte;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final tX = width * data.bandFraction(data.target!);
        final dX = width * data.bandFraction(data.delivered);
        return SizedBox(
          height: 3,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: creamAlpha(.45),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              AnimatedPositioned(
                key: FuelStat.suggestedMarkerKey(data.quantity),
                duration: const Duration(milliseconds: 220),
                curve: const Cubic(.2, .8, .2, 1),
                left: tX - 4,
                top: 8,
                child: const CustomPaint(
                  size: Size(8, 5),
                  painter: _TrianglePainter(AppColors.orange),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 220),
                curve: const Cubic(.2, .8, .2, 1),
                left: dX - 4.5,
                top: -3,
                child: FuelStatDeliveredMarker(
                  key: FuelStat.deliveredMarkerKey(data.quantity),
                  color: deliveredColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The delivered (diamond) marker — exposed so tests can read its colour.
class FuelStatDeliveredMarker extends StatelessWidget {
  const FuelStatDeliveredMarker({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.7853981633974483, // 45°
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        width: 9,
        height: 9,
        color: color,
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  const _TrianglePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TrianglePainter oldDelegate) =>
      oldDelegate.color != color;
}
