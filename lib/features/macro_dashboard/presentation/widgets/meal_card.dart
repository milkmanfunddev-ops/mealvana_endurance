import 'package:flutter/material.dart';

import '../../domain/dashboard_models.dart';
import '../me_tokens.dart';

/// Logged meal card (macro-dashboard surface). No component spec yet — its
/// truths live in the surface spec or nowhere (surfaces/macro-dashboard.md
/// composition table); appearance follows the reference rendering.
class MealCard extends StatelessWidget {
  const MealCard({
    super.key,
    required this.item,
    required this.expanded,
    required this.showMacros,
    this.onToggle,
    this.onRemove,
    this.onEdit,
    this.onSaveAsFavorite,
    this.saveAsFavoriteLabel,
  });

  final MealItemData item;
  final bool expanded;

  /// Tracking-off hides kcal on timeline entries (intraday-display §5).
  final bool showMacros;
  final VoidCallback? onToggle;
  final VoidCallback? onRemove;
  final VoidCallback? onEdit;

  /// "Save as favorite" in the expanded ⋯ (Lee, 112-008). Shown only when
  /// both the callback and its label (from the content system) are given.
  final VoidCallback? onSaveAsFavorite;
  final String? saveAsFavoriteLabel;

  @override
  Widget build(BuildContext context) {
    final me = MeTokens.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: me.liftAlpha(0.045),
        border: Border.all(color: me.inkAlpha(0.08)),
        borderRadius: BorderRadius.circular(14),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: onToggle,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: MeTokens.orange,
                    ),
                    child: Icon(Icons.restaurant, size: 14, color: me.ground),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Compadre',
                            fontSize: 15,
                            color: me.ink,
                          ),
                        ),
                        if (showMacros) ...[
                          const SizedBox(height: 2),
                          Text.rich(
                            TextSpan(
                              style: TextStyle(
                                fontFamily: 'Apercu',
                                fontSize: 11,
                                color: me.inkAlpha(0.5),
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                              children: [
                                TextSpan(
                                  text: kcalStrOrUnknown(item.kcal),
                                  style: TextStyle(
                                    color: me.ink,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const TextSpan(text: ' kcal · '),
                                TextSpan(
                                  text: '${macroStrOrUnknown(item.carbsG)}C',
                                  style: const TextStyle(
                                    color: MeTokens.electrolyte,
                                  ),
                                ),
                                const TextSpan(text: ' · '),
                                TextSpan(
                                  text: '${macroStrOrUnknown(item.proteinG)}P',
                                  style: const TextStyle(
                                    color: MeTokens.proteinAccent,
                                  ),
                                ),
                                const TextSpan(text: ' · '),
                                TextSpan(
                                  text: '${macroStrOrUnknown(item.fatG)}F',
                                  style: const TextStyle(
                                    color: MeTokens.fatAccent,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Text(
                    '⋯',
                    style: TextStyle(
                      fontSize: 17,
                      height: 1,
                      color: me.inkAlpha(0.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(55, 0, 12, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _pillButton(
                          label: 'Edit food',
                          onTap: onEdit,
                          background: me.liftAlpha(0.05),
                          borderColor: me.inkAlpha(0.12),
                          ink: me.ink,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _pillButton(
                          label: 'Remove',
                          onTap: onRemove,
                          background: Colors.transparent,
                          // Destructive = dragonfruit only (tokens.md).
                          borderColor: MeTokens.dragonfruit,
                          ink: MeTokens.dragonfruit,
                        ),
                      ),
                    ],
                  ),
                  if (onSaveAsFavorite != null &&
                      saveAsFavoriteLabel != null) ...[
                    const SizedBox(height: 8),
                    _pillButton(
                      key: ValueKey('macro_dashboard.meal_${item.id}.favorite'),
                      label: saveAsFavoriteLabel!,
                      onTap: onSaveAsFavorite,
                      background: me.liftAlpha(0.05),
                      borderColor: me.inkAlpha(0.12),
                      ink: me.ink,
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _pillButton({
    Key? key,
    required String label,
    required VoidCallback? onTap,
    required Color background,
    required Color borderColor,
    required Color ink,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 7),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: background,
          border: Border.all(color: borderColor),
          borderRadius: BorderRadius.circular(100),
        ),
        child: Text(
          label,
          style: TextStyle(fontFamily: 'Apercu', fontSize: 12, color: ink),
        ),
      ),
    );
  }
}
