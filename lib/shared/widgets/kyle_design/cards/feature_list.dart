/// Design SSOT component — **Feature List**.
///
/// Spec: `docs/ssot/spec/design/components/feature-list.md` **v1**
/// (PROPOSED Lee 2026-09-21, authored app-side, awaiting Xuan).
///
/// What a plan buys, as a list a person scrolls (mp-493 §2): a few headline
/// features, an "also includes" divider, and the rest. First use: the
/// paywall.
///
/// Contracts held here:
/// * **FL-1** — two tiers. [headline] rows carry a title and a line of body;
///   [more] rows are title-only and tighter. The divider sits between them
///   and only when there are [more] rows.
/// * **FL-2** — each row leads with a mark: a [FeatureListIcon] (an icon in a
///   `glass` disc, tokens §Materials) or, for the Vana line, the one
///   [VanaAvatar]. The AI features share one Vana row; the widget does not
///   know which features are AI, the caller groups them.
/// * **FL-3** — words come from the caller (the content system), never from
///   here; the list tints nothing but its marks' icons (electrolyte).
/// * **FL-4** — plain rows on the page's ground: not a content card, no fill,
///   no border. Each row reads as one sentence to a screen reader.
library;

import 'package:flutter/material.dart';

import '../../../../theme/kyle_design/app_colors.dart';
import '../../../../theme/kyle_design/app_spacing.dart';
import '../../../../theme/kyle_design/app_text_styles.dart';
import '../materials/glass.dart';

/// One feature: its mark, its name, and (headline rows) a line on it.
class FeatureListItem {
  const FeatureListItem({
    required this.leading,
    required this.title,
    this.body,
  });

  final Widget leading;
  final String title;

  /// Shown on headline rows only (FL-1).
  final String? body;
}

/// FL-2: an icon in a glass disc, the mark of an ordinary feature.
class FeatureListIcon extends StatelessWidget {
  const FeatureListIcon(this.icon, {super.key, this.size = 40});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: GlassSurface(
        borderRadius: BorderRadius.circular(size / 2),
        child: Center(
          child: Icon(icon, size: size * 0.5, color: AppColors.electrolyte),
        ),
      ),
    );
  }
}

class FeatureList extends StatelessWidget {
  const FeatureList({
    super.key,
    required this.headline,
    this.dividerLabel,
    this.more = const [],
  });

  final List<FeatureListItem> headline;

  /// The divider's words ("Also includes"); required when [more] is not
  /// empty.
  final String? dividerLabel;
  final List<FeatureListItem> more;

  static ValueKey<String> headlineKey(int i) =>
      ValueKey('feature_list.headline.$i');
  static ValueKey<String> moreKey(int i) => ValueKey('feature_list.more.$i');
  static const dividerKey = ValueKey('feature_list.divider');

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ink = isDark ? AppColors.textDark : AppColors.textLight;
    final secondary = isDark
        ? AppColors.textDarkSecondary
        : AppColors.textLightSecondary;
    final label = dividerLabel;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < headline.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.lg),
          _Row(
            key: headlineKey(i),
            item: headline[i],
            showBody: true,
            ink: ink,
            secondary: secondary,
          ),
        ],
        if (more.isNotEmpty && label != null) ...[
          const SizedBox(height: AppSpacing.xl),
          _Divider(label: label, color: secondary),
          const SizedBox(height: AppSpacing.lg),
          for (var i = 0; i < more.length; i++) ...[
            if (i > 0) const SizedBox(height: AppSpacing.sm),
            _Row(
              key: moreKey(i),
              item: more[i],
              showBody: false,
              ink: ink,
              secondary: secondary,
            ),
          ],
        ],
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.item,
    required this.showBody,
    required this.ink,
    required this.secondary,
  });

  final FeatureListItem item;
  final bool showBody;
  final Color ink;
  final Color secondary;

  @override
  Widget build(BuildContext context) {
    final body = showBody ? item.body : null;
    return MergeSemantics(
      child: Row(
        crossAxisAlignment: body == null
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(
            child: showBody
                ? item.leading
                : Transform.scale(scale: 0.8, child: item.leading),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: (showBody ? AppTextStyles.h5 : AppTextStyles.bodyLarge)
                      .copyWith(color: ink),
                ),
                if (body != null) ...[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    body,
                    style: AppTextStyles.bodyMedium.copyWith(color: secondary),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final line = Expanded(
      child: Container(height: 1, color: color.withValues(alpha: 0.3)),
    );
    return Row(
      key: FeatureList.dividerKey,
      children: [
        line,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
          child: Text(
            label.toUpperCase(),
            style: AppTextStyles.overline.copyWith(color: color),
          ),
        ),
        line,
      ],
    );
  }
}
