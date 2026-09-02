/// Design SSOT component — **Feeding Card**.
///
/// Spec: `docs/ssot/spec/design/components/feeding-card.md` **v1** (RATIFIED
/// Xuan 2026-08-26). Reference rendering
/// `docs/ssot/spec/design/renderings/pre-workout@v2.html` — the steppers'
/// at-rest look, disc size and row layout are screenshot-held from it.
/// Food-row ICONS follow the PHASE-CARD VISUAL PARITY ruling as AMENDED
/// (surface `pre-workout-before-card.md`, Xuan 2026-09-01, qa `127e993`):
/// the shared per-food colour disc + white glyph, resolved by the surface
/// through [rowIcon] / [rowIconColor] (the `ExpandableFoodItemWidget`
/// pattern) — not the rendering's orange stroke-glyph discs. The dashed
/// "+ Add Food" pill is EXCLUDED from that ruling and stays as FC-7 specifies.
///
/// One pre-workout feeding (meal · snack · top-off) with its window label,
/// its DELIVERED header figure and its food rows. Which feedings exist, and
/// what a row change does to the summary stats, is the surface's
/// (`pre-workout-before-card.md` B-1/B-2).
///
/// Contracts held here:
/// * **FC-1** — the title arrives from the assembler (engine-threshold
///   naming); this card never invents one.
/// * **FC-2** — the header shows DELIVERED only ("52g" · "carbs"); no aim, no
///   DONE/AIM pair, no ±12.5 % window (FC-3). A fluid tier shows its oz.
/// * **FC-4** — a zero-carb card still renders when it carries fluid; on the
///   fasted path there is no carb figure.
/// * **FC-5** — rows show name, macros as an observation and a ± stepper
///   whose step and cap are the row's.
/// * **FC-6** — the hydration check (injected by the surface) is the first
///   row of the SNACK card on ≥ 2 h plans.
/// * **FC-7** — "+ Add Food" appends a row (expanded only).
/// * **FC-G1** — tapping the header toggles `expanded` in place, never
///   navigates. **FC-G2/G3** — ± emits a delivered-total change; the card
///   never repaints the summary itself.
///
/// Tokens: title, chevron, row borders, stepper discs and Add Food in
/// `orange`; text `cream`; the added-row tag in `electrolyte` (Q-D8).
library;

import 'package:flutter/material.dart';

import '../../../../features/nutrition_plan/domain/pre_workout_before_card_model.dart';
import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import 'fueling_glyphs.dart';

class FeedingCard extends StatefulWidget {
  const FeedingCard({
    super.key,
    required this.data,
    required this.onStep,
    required this.onAddFood,
    required this.rowIcon,
    required this.rowIconColor,
    this.hydrationCheck,
    this.initiallyExpanded = false,
  });

  final FeedingCardData data;

  /// FC-G2: the row's quantity changed (already clamped to `[0, cap]`).
  final void Function(FeedingFoodRow row, double newQuantity) onStep;

  /// FC-7.
  final ValueChanged<String> onAddFood;

  /// Parity ruling: the row's glyph and disc colour come from the shared
  /// per-food resolvers the surface injects (see `ActivityDetailHelpers`).
  final IconData Function(FeedingFoodRow row) rowIcon;
  final Color Function(FeedingFoodRow row) rowIconColor;

  /// FC-6: the hydration-check control, rendered as the first row when
  /// [FeedingCardData.hostsHydrationCheck] is true.
  final Widget? hydrationCheck;

  final bool initiallyExpanded;

  static Key cardKey(String tier) => Key('feeding_card.$tier');
  static Key headerKey(String tier) => Key('feeding_card.$tier.header');
  static Key titleKey(String tier) => Key('feeding_card.$tier.title');
  static Key carbsKey(String tier) => Key('feeding_card.$tier.carbs');
  static Key fluidKey(String tier) => Key('feeding_card.$tier.fluid');
  static Key rowKey(String foodId) => Key('feeding_row.$foodId');
  static Key incKey(String foodId) => Key('feeding_row.$foodId.inc');
  static Key decKey(String foodId) => Key('feeding_row.$foodId.dec');
  static Key qtyKey(String foodId) => Key('feeding_row.$foodId.qty');
  static Key noteKey(String foodId) => Key('feeding_row.$foodId.note');
  static Key addFoodKey(String tier) => Key('feeding_card.$tier.add_food');

  @override
  State<FeedingCard> createState() => _FeedingCardState();
}

class _FeedingCardState extends State<FeedingCard> {
  late bool _expanded = widget.initiallyExpanded;

  FeedingCardData get d => widget.data;
  String get _tier => d.tier.engineName;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: FeedingCard.cardKey(_tier),
      decoration: BoxDecoration(
        color: fuelingCardFill,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: orangeAlpha(.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [_header(), if (_expanded) _body()],
      ),
    );
  }

  Widget _header() {
    return GestureDetector(
      key: FeedingCard.headerKey(_tier),
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _expanded = !_expanded),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            FuelingChevron(
              expanded: _expanded,
              size: 15,
              color: AppColors.orange,
              strokeWidth: 2.5,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    d.title,
                    key: FeedingCard.titleKey(_tier),
                    style: const TextStyle(
                      fontFamily: AppTextStyles.sansita,
                      fontWeight: FontWeight.w700,
                      fontSize: 17,
                      height: 1.15,
                      color: AppColors.orange,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    d.windowLabel,
                    style: TextStyle(
                      fontFamily: AppTextStyles.apercu,
                      fontSize: 9.5,
                      letterSpacing: 9.5 * .12,
                      color: creamAlpha(.5),
                    ),
                  ),
                  if (!_expanded && d.rows.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      d.foodsLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: AppTextStyles.apercu,
                        fontSize: 12,
                        color: creamAlpha(.75),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (d.carbsDelivered != null)
              _figure(
                key: FeedingCard.carbsKey(_tier),
                value: '${d.carbsDelivered}g',
                label: 'CARBS',
              ),
            if (d.carbsDelivered != null && d.fluidOz != null)
              const SizedBox(width: 14),
            if (d.fluidOz != null)
              _figure(
                key: FeedingCard.fluidKey(_tier),
                value: '${d.fluidOz}oz',
                label: 'FLUIDS',
              ),
          ],
        ),
      ),
    );
  }

  /// Header figure: Sansita 700 16 cream over an 8 px uppercase label.
  Widget _figure({
    required Key key,
    required String value,
    required String label,
  }) {
    return Column(
      key: key,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontFamily: AppTextStyles.sansita,
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: AppColors.cream,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontFamily: AppTextStyles.apercu,
            fontSize: 8,
            letterSpacing: 8 * .08,
            color: creamAlpha(.5),
          ),
        ),
      ],
    );
  }

  Widget _body() {
    final children = <Widget>[
      if (d.hostsHydrationCheck && widget.hydrationCheck != null)
        widget.hydrationCheck!,
      for (final row in d.rows)
        _FoodRow(
          row: row,
          onStep: widget.onStep,
          icon: widget.rowIcon(row),
          iconColor: widget.rowIconColor(row),
        ),
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Center(
          child: _AddFoodButton(
            key: FeedingCard.addFoodKey(_tier),
            onTap: () => widget.onAddFood(d.category),
          ),
        ),
      ),
    ];
    return Container(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: orangeAlpha(.25))),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// FC-5: name · macros-as-observation · ± stepper (36 px discs).
class _FoodRow extends StatelessWidget {
  const _FoodRow({
    required this.row,
    required this.onStep,
    required this.icon,
    required this.iconColor,
  });

  final FeedingFoodRow row;
  final void Function(FeedingFoodRow row, double newQuantity) onStep;
  final IconData icon;
  final Color iconColor;

  String get _sub {
    final parts = <String>[];
    if (row.carbsG > 0) parts.add('${row.carbsG.round()}g carbs');
    if (row.fluidMl > 0) parts.add('${(row.fluidMl / 29.5735).round()} oz');
    if (row.sodiumMg > 0) parts.add('${row.sodiumMg.round()}mg sodium');
    return parts.isEmpty ? 'nothing yet' : parts.join(' · ');
  }

  static String formatQuantity(double q) =>
      q % 1 == 0 ? q.toInt().toString() : q.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    return Container(
      key: FeedingCard.rowKey(row.id),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        border: Border.all(color: orangeAlpha(.45)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Parity ruling: the shared food-row chip
          // (`expandable_food_item_widget.dart` — per-food colour disc,
          // white glyph, `foodIcon` / `controlIcon` sizes).
          Container(
            width: AppIconSizes.foodIcon,
            height: AppIconSizes.foodIcon,
            decoration: BoxDecoration(shape: BoxShape.circle, color: iconColor),
            child: Icon(icon, size: AppIconSizes.controlIcon, color: Colors.white),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // F-7: the name wraps to a second line (the rendering sets no
                // nowrap on it) — "Rice Cake (plain)" must never lose its
                // parenthetical to an ellipsis at phone width (ops bug
                // 2026-08-26-food-row-names-truncate-at-narrow-width).
                Text(
                  row.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: fuelingDisplayStyle(fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  _sub,
                  style: TextStyle(
                    fontFamily: AppTextStyles.apercu,
                    fontSize: 10.5,
                    color: creamAlpha(.5),
                  ),
                ),
                if (row.note != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    row.note!,
                    key: FeedingCard.noteKey(row.id),
                    style: const TextStyle(
                      fontFamily: AppTextStyles.apercu,
                      fontSize: 9,
                      letterSpacing: 9 * .05,
                      color: AppColors.electrolyte,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 11),
          _disc(
            key: FeedingCard.decKey(row.id),
            glyph: '−',
            onTap: () => onStep(row, _clamp(row.quantity - row.step)),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 28),
            child: Text(
              formatQuantity(row.quantity),
              key: FeedingCard.qtyKey(row.id),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Apercu Mono',
                fontSize: 15,
                color: AppColors.cream,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _disc(
            key: FeedingCard.incKey(row.id),
            glyph: '+',
            onTap: () => onStep(row, _clamp(row.quantity + row.step)),
          ),
        ],
      ),
    );
  }

  double _clamp(double q) => q.clamp(0.0, row.cap);

  Widget _disc({
    required Key key,
    required String glyph,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.orange),
        ),
        alignment: Alignment.center,
        child: Text(
          glyph,
          style: const TextStyle(
            fontFamily: AppTextStyles.apercu,
            fontSize: 20,
            height: 1,
            color: AppColors.orange,
          ),
        ),
      ),
    );
  }
}

/// "+ Add Food" — dashed orange pill, 44 px tall, Sansita 700 14.
class _AddFoodButton extends StatelessWidget {
  const _AddFoodButton({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: CustomPaint(
        painter: const _DashedPillPainter(AppColors.orange),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          alignment: Alignment.center,
          child: const Text(
            '+ Add Food',
            style: TextStyle(
              fontFamily: AppTextStyles.sansita,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.orange,
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedPillPainter extends CustomPainter {
  const _DashedPillPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(100),
    );
    final path = Path()..addRRect(rrect);
    const dash = 4.0, gap = 3.0;
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + dash), paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPillPainter oldDelegate) =>
      oldDelegate.color != color;
}
