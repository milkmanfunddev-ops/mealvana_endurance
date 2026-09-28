import 'package:flutter/material.dart';

import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../../shared/widgets/kyle_design/materials/glass.dart';
import '../../../content/application/content_service.dart';
import '../../../content/domain/content_keys.dart';

/// The paywall's four headline features as a carousel (Lee, 2026-09-26;
/// changes mp-493 §2 / mp-538's presentation): one glass card per feature,
/// swiped sideways under the clip, with a dot per card. The "also includes"
/// rows are no longer on the paywall; the Subscription screen still shows
/// them through [ProFeatureList].
///
/// The four are the same as [ProFeatureList]'s headline, from the same
/// content keys: the fuel plan, Vana (the AI features on the one line), the
/// shopping list and training sync. Each card reads as one sentence to a
/// screen reader.
class ProFeatureCarousel extends StatefulWidget {
  const ProFeatureCarousel({super.key, required this.content});

  final ContentService content;

  /// Each card's height. A `PageView` needs one; this fits the longest body
  /// (Vana's, three lines at a phone width) with its title beside the mark.
  static const double cardHeight = 172;

  /// How much of the width one card takes; the next card peeks in.
  static const double viewportFraction = 0.86;

  static ValueKey<String> cardKey(int i) =>
      ValueKey('pro_feature_carousel.card.$i');
  static const dotsKey = ValueKey('pro_feature_carousel.dots');

  @override
  State<ProFeatureCarousel> createState() => _ProFeatureCarouselState();
}

class _ProFeatureCarouselState extends State<ProFeatureCarousel> {
  final _controller = PageController(
    viewportFraction: ProFeatureCarousel.viewportFraction,
  );
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.textDark : AppColors.textLight;
    final secondary = isDark
        ? AppColors.textDarkSecondary
        : AppColors.textLightSecondary;
    String t(String key) => widget.content.getValue(key);

    final cards = [
      _Feature(
        leading: const FeatureListIcon(Icons.bolt),
        title: t(ContentKeys.paywallFeatureFuelTitle),
        body: t(ContentKeys.paywallFeatureFuelBody),
      ),
      _Feature(
        leading: const VanaAvatar(size: 40),
        title: t(ContentKeys.paywallFeatureVanaTitle),
        body: t(ContentKeys.paywallFeatureVanaBody),
      ),
      _Feature(
        leading: const FeatureListIcon(Icons.shopping_basket_outlined),
        title: t(ContentKeys.paywallFeatureShoppingTitle),
        body: t(ContentKeys.paywallFeatureShoppingBody),
      ),
      _Feature(
        leading: const FeatureListIcon(Icons.watch_outlined),
        title: t(ContentKeys.paywallFeatureSyncTitle),
        body: t(ContentKeys.paywallFeatureSyncBody),
      ),
    ];

    return Column(
      children: [
        SizedBox(
          height: ProFeatureCarousel.cardHeight,
          child: PageView.builder(
            controller: _controller,
            itemCount: cards.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: _FeatureCard(
                key: ProFeatureCarousel.cardKey(i),
                feature: cards[i],
                ink: ink,
                secondary: secondary,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        ExcludeSemantics(
          child: Row(
            key: ProFeatureCarousel.dotsKey,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < cards.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xxs,
                  ),
                  child: _Dot(active: i == _page, inactiveColor: secondary),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Feature {
  const _Feature({
    required this.leading,
    required this.title,
    required this.body,
  });

  final Widget leading;
  final String title;
  final String body;
}

/// One card: the mark beside the title, the body under them, on `glass`.
class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    super.key,
    required this.feature,
    required this.ink,
    required this.secondary,
  });

  final _Feature feature;
  final Color ink;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: GlassSurface(
        borderRadius: BorderRadius.circular(AppSpacing.lg),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ExcludeSemantics(child: feature.leading),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      feature.title,
                      style: AppTextStyles.h5.copyWith(color: ink),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Expanded(
                child: Text(
                  feature.body,
                  style: AppTextStyles.bodyMedium.copyWith(color: secondary),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.active, required this.inactiveColor});

  final bool active;
  final Color inactiveColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 6,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active
              ? AppColors.electrolyte
              : inactiveColor.withValues(alpha: 0.3),
        ),
      ),
    );
  }
}
