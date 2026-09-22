import 'package:flutter/material.dart';

import '../../../../shared/widgets/kyle_design/kyle_design.dart';
import '../../../content/application/content_service.dart';
import '../../../content/domain/content_keys.dart';

/// What Pro includes (mp-493 §2): four headline features, the "also
/// includes" divider, then the rest. The AI features share the one Vana
/// line. The paywall and the Subscription screen (mp-495 §2) show the same
/// list from the same content keys; this is the one place it is composed.
///
/// [ticks] marks every ordinary feature with a tick instead of its own icon,
/// the Subscription screen's tick list; the Vana line keeps the avatar
/// either way. Built from `FeatureList` (kyle_design, spec
/// `docs/ssot/spec/design/components/feature-list.md`).
class ProFeatureList extends StatelessWidget {
  const ProFeatureList({super.key, required this.content, this.ticks = false});

  final ContentService content;
  final bool ticks;

  @override
  Widget build(BuildContext context) {
    String t(String key) => content.getValue(key);
    Widget mark(IconData icon) => FeatureListIcon(ticks ? Icons.check : icon);
    FeatureListItem more(IconData icon, String key) =>
        FeatureListItem(leading: mark(icon), title: t(key));
    return FeatureList(
      headline: [
        FeatureListItem(
          leading: mark(Icons.bolt),
          title: t(ContentKeys.paywallFeatureFuelTitle),
          body: t(ContentKeys.paywallFeatureFuelBody),
        ),
        FeatureListItem(
          leading: const VanaAvatar(size: 40),
          title: t(ContentKeys.paywallFeatureVanaTitle),
          body: t(ContentKeys.paywallFeatureVanaBody),
        ),
        FeatureListItem(
          leading: mark(Icons.shopping_basket_outlined),
          title: t(ContentKeys.paywallFeatureShoppingTitle),
          body: t(ContentKeys.paywallFeatureShoppingBody),
        ),
        FeatureListItem(
          leading: mark(Icons.watch_outlined),
          title: t(ContentKeys.paywallFeatureSyncTitle),
          body: t(ContentKeys.paywallFeatureSyncBody),
        ),
      ],
      dividerLabel: t(ContentKeys.paywallFeaturesDivider),
      more: [
        more(Icons.restaurant_menu, ContentKeys.paywallFeatureRecipes),
        more(Icons.directions_bike, ContentKeys.paywallFeatureBrick),
        more(Icons.water_drop_outlined, ContentKeys.paywallFeatureHydration),
        more(Icons.science_outlined, ContentKeys.paywallFeatureFormulas),
        more(Icons.track_changes, ContentKeys.paywallFeatureTargets),
      ],
    );
  }
}
