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
    this.onSwap,
  });

  final MealItemData item;
  final bool expanded;

  /// Tracking-off hides kcal on timeline entries (intraday-display §5).
  final bool showMacros;
  final VoidCallback? onToggle;
  final VoidCallback? onRemove;
  final VoidCallback? onSwap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.045),
        border: Border.all(color: MeTokens.creamAlpha(0.08)),
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
                    child: const Icon(
                      Icons.restaurant,
                      size: 14,
                      color: MeTokens.blackberry,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: 'Compadre',
                            fontSize: 15,
                            color: MeTokens.cream,
                          ),
                        ),
                        if (showMacros) ...[
                          const SizedBox(height: 2),
                          Text.rich(
                            TextSpan(
                              style: TextStyle(
                                fontFamily: 'Apercu',
                                fontSize: 11,
                                color: MeTokens.creamAlpha(0.5),
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                              children: [
                                TextSpan(
                                  text: kcalStr(item.kcal),
                                  style: const TextStyle(
                                    color: MeTokens.cream,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const TextSpan(text: ' kcal · '),
                                TextSpan(
                                  text: '${item.carbsG.round()}C',
                                  style: const TextStyle(
                                    color: MeTokens.electrolyte,
                                  ),
                                ),
                                const TextSpan(text: ' · '),
                                TextSpan(
                                  text: '${item.proteinG.round()}P',
                                  style: const TextStyle(
                                    color: MeTokens.proteinAccent,
                                  ),
                                ),
                                const TextSpan(text: ' · '),
                                TextSpan(
                                  text: '${item.fatG.round()}F',
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
                      color: MeTokens.creamAlpha(0.4),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(55, 0, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: _pillButton(
                      label: 'Swap food',
                      onTap: onSwap,
                      background: Colors.white.withValues(alpha: 0.05),
                      borderColor: MeTokens.creamAlpha(0.12),
                      ink: MeTokens.cream,
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
            ),
        ],
      ),
    );
  }

  Widget _pillButton({
    required String label,
    required VoidCallback? onTap,
    required Color background,
    required Color borderColor,
    required Color ink,
  }) {
    return GestureDetector(
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
