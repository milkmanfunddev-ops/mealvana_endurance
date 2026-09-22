/// Design SSOT component — **Plan Card** (and its pinned tray).
///
/// Spec: `docs/ssot/spec/design/components/plan-card.md` **v1**
/// (PROPOSED Lee 2026-09-22, authored app-side, awaiting Xuan).
///
/// One subscription plan a person picks before one action buys it
/// (mp-493 §3). First use: the paywall, where the two plans stay pinned
/// above one Continue button through the whole scroll.
///
/// Contracts held here:
/// * **PC-1** — a card shows a title and the billed price, and whatever the
///   caller adds: the normal price struck through (founding prices,
///   mp-453 §2), a per-month line, a trial note and a badge. Every word and
///   price comes from the caller; the card computes nothing.
/// * **PC-2** — a tap selects the card; it never buys. The selected card
///   carries the ink border and a filled check; the other a faint border
///   and an empty ring, at the same border width so nothing shifts.
/// * **PC-3** — the billed price is the largest price on the card; the
///   per-month line sits under it, smaller (the store's rule that the amount
///   billed is the most prominent).
/// * **PC-4** — a card reads as one selectable item in a mutually exclusive
///   group.
/// * **PC-5** — [PlanCardTray] pins an optional header, the cards and one
///   action at the bottom of the page on `glass` chrome; the cards inside
///   stay solid content cards (tokens §Materials, boundaries).
library;

import 'package:flutter/material.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_materials.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../materials/glass.dart';

class PlanCard extends StatelessWidget {
  const PlanCard({
    super.key,
    required this.title,
    required this.price,
    this.regularPrice,
    this.detail,
    this.note,
    this.badge,
    required this.selected,
    required this.onSelected,
  });

  static const frameKey = ValueKey('plan_card.frame');
  static const priceKey = ValueKey('plan_card.price');
  static const regularPriceKey = ValueKey('plan_card.regular_price');
  static const detailKey = ValueKey('plan_card.detail');
  static const noteKey = ValueKey('plan_card.note');
  static const badgeKey = ValueKey('plan_card.badge');

  /// The plan's name ("Annual").
  final String title;

  /// What the store bills, with its period ("$199.99 / year").
  final String price;

  /// The normal price, struck through beside [price] (PC-1).
  final String? regularPrice;

  /// A smaller line under the price ("$16.67 a month", PC-3).
  final String? detail;

  /// The trial note ("7 days free").
  final String? note;

  /// A short pill beside the title ("Save 33%").
  final String? badge;

  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.textDark : AppColors.textLight;
    final secondary = isDark
        ? AppColors.textDarkSecondary
        : AppColors.textLightSecondary;
    // The trial note: electrolyte on the dark ground; on the light card the
    // accent is too faint to read (Q-PC1), so it takes the ink.
    final accent = isDark ? AppColors.electrolyte : AppColors.textLight;
    final regular = regularPrice;
    final detailText = detail;
    final noteText = note;
    final badgeText = badge;

    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: InkWell(
        onTap: onSelected,
        borderRadius: AppRadius.cardRadius,
        child: DecoratedBox(
          key: frameKey,
          decoration: BoxDecoration(
            color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
            borderRadius: AppRadius.cardRadius,
            border: Border.all(
              color: selected ? ink : ink.withValues(alpha: 0.2),
              width: 2,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Icon(
                    selected
                        ? Icons.check_circle
                        : Icons.radio_button_unchecked,
                    size: 22,
                    color: selected ? ink : ink.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              style: AppTextStyles.h5.copyWith(color: ink),
                            ),
                          ),
                          if (badgeText != null) ...[
                            const SizedBox(width: AppSpacing.xs),
                            _Badge(text: badgeText),
                          ],
                        ],
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Wrap(
                        spacing: AppSpacing.xs,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            key: priceKey,
                            price,
                            style: AppTextStyles.bodyLarge.copyWith(
                              color: ink,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (regular != null)
                            Text(
                              key: regularPriceKey,
                              regular,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: secondary,
                                decoration: TextDecoration.lineThrough,
                                decorationColor: secondary,
                              ),
                            ),
                        ],
                      ),
                      if (detailText != null || noteText != null)
                        Wrap(
                          spacing: AppSpacing.sm,
                          children: [
                            if (detailText != null)
                              Text(
                                key: detailKey,
                                detailText,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: secondary,
                                ),
                              ),
                            if (noteText != null)
                              Text(
                                key: noteKey,
                                noteText,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: accent,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      key: PlanCard.badgeKey,
      decoration: const BoxDecoration(
        color: AppColors.electrolyte,
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.pill)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: 2,
        ),
        child: Text(
          text,
          style: AppTextStyles.smallLabel.copyWith(
            color: AppColors.blackberry,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// PC-5: the tray pinned at the bottom of the page — an optional [header]
/// (the "Founding member" line), the [cards], then one [action] — on `glass`
/// chrome with the sheet's top radius. The page scrolls above it; the tray
/// never moves. Its bottom padding clears the home indicator.
class PlanCardTray extends StatelessWidget {
  const PlanCardTray({
    super.key,
    this.header,
    required this.cards,
    required this.action,
  });

  final Widget? header;
  final List<Widget> cards;
  final Widget action;

  static const _radius = BorderRadius.vertical(
    top: Radius.circular(AppMaterials.sheetTopRadius),
  );

  @override
  Widget build(BuildContext context) {
    final head = header;
    return GlassSurface(
      borderRadius: _radius,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (head != null) ...[
                head,
                const SizedBox(height: AppSpacing.xs),
              ],
              for (final (i, card) in cards.indexed) ...[
                if (i > 0) const SizedBox(height: AppSpacing.xs),
                card,
              ],
              const SizedBox(height: AppSpacing.md),
              action,
            ],
          ),
        ),
      ),
    );
  }
}
