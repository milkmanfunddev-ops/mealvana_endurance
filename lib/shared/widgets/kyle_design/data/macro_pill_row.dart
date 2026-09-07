/// Design SSOT component — **Macro Pill Row**.
///
/// Spec: `docs/ssot/spec/design/components/macro-pill-row.md` **v1**
/// (PROPOSED Lee 2026-09-03, awaiting Xuan).
///
/// A compact fact strip of small pills — `412 kcal · 58g C · 31g P · 12g F` —
/// stating what one meal carries, as the server sent it. Composed by
/// `MealCard`, `PlanTile`, the plan-bar tiles and the Review sheet; the host
/// decides *whether* it shows (the `show_macros` setting).
///
/// Contracts held here:
/// * **MP-1** — one short form: grams take a single capital letter unit
///   (`C` · `P` · `F`), kcal is spelled out; fixed order kcal · carbs ·
///   protein · fat.
/// * **MP-2** — a null macro drops its pill, never renders `0`; a real `0`
///   renders `0g`.
/// * **MP-3** — kcal and carbs both null → nothing at all (zero-size box).
/// * **MP-4** — no fiber / sugar / sodium; nothing is synthesised.
/// * **MP-5** — rounding is presentational (whole grams); no arithmetic.
/// * **MP-L1/L2** — one line first, whole-pill wrap as a last resort;
///   [compact] scales down for tiles.
///
/// Tokens: neutral text-on-surface only — `cream` on the dark ground,
/// `blackberry` on the light one, at reduced alpha for the fill and text.
/// No meaning-bound colour (tokens.md): this is a fact strip, not a status.
library;

import 'package:flutter/material.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';

class MacroPillRow extends StatelessWidget {
  const MacroPillRow({
    super.key,
    required this.kcal,
    this.carbsG,
    this.proteinG,
    this.fatG,
    this.compact = false,
  });

  final int? kcal;
  final double? carbsG;
  final double? proteinG;
  final double? fatG;

  /// Smaller type and tighter padding for tile / plan-bar use (MP-L2).
  final bool compact;

  /// MP-3 — whether this row would paint anything. Hosts can use it to skip
  /// their own spacing around an empty strip.
  bool get isEmpty => kcal == null && carbsG == null;

  /// The pill strings in MP-1 order, nulls dropped (MP-2). Exposed for hosts
  /// and tests; the strings are the contract.
  List<String> get labels => [
    if (kcal != null) '$kcal kcal',
    if (carbsG != null) '${carbsG!.round()}g C',
    if (proteinG != null) '${proteinG!.round()}g P',
    if (fatG != null) '${fatG!.round()}g F',
  ];

  @override
  Widget build(BuildContext context) {
    if (isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppColors.cream : AppColors.blackberry;
    final style = (compact ? AppTextStyles.nutritionFact : AppTextStyles.bodySmall)
        .copyWith(
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w500,
          height: 1.2,
          color: textColor.withValues(alpha: 0.75),
        );
    final padding = compact
        ? const EdgeInsets.symmetric(horizontal: 5, vertical: 2)
        : const EdgeInsets.symmetric(horizontal: 7, vertical: 3);

    return Wrap(
      spacing: compact ? AppSpacing.xxs : 6,
      runSpacing: AppSpacing.xxs,
      children: [
        for (final label in labels)
          Container(
            padding: padding,
            decoration: BoxDecoration(
              color: textColor.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(AppRadius.pill),
            ),
            child: Text(label, style: style, softWrap: false),
          ),
      ],
    );
  }
}
