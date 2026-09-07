import 'package:flutter/material.dart';
import 'package:mealvana_endurance/theme/kyle_design/app_colors.dart';

/// Horizontal bar showing intensity distribution with colored segments.
///
/// Reference rendering: prototypes/create-activity-plan/v1.html (spec
/// docs/ssot/spec/design/surfaces/create-flow-fueling-controls.md) — a slim
/// (4px) fully-rounded full-width track whose segment widths are the zone
/// percentages, painted with the brand zone tokens:
/// - Electrolyte: Conversational (Z1-Z2)
/// - Orange: Tempo (Z3-Z4)
/// - Dragonfruit: All-Out (Z5+)
///
/// Props:
/// - conversationalPct: Percentage for Z1-Z2 (electrolyte segment)
/// - tempoPct: Percentage for Z3-Z4 (orange segment)
/// - allOutPct: Percentage for Z5+ (dragonfruit segment)
/// - enabled: Whether to show full opacity (true) or dimmed (false)
class IntensityCompositeBar extends StatelessWidget {
  const IntensityCompositeBar({
    super.key,
    required this.conversationalPct,
    required this.tempoPct,
    required this.allOutPct,
    this.height = 4.0,
    this.enabled = true,
  });

  final int conversationalPct;
  final int tempoPct;
  final int allOutPct;
  final double height;
  final bool enabled;

  // Zone colors — brand tokens (no raw literals; token registry rule).
  static const Color zoneConversationalColor = AppColors.electrolyte;
  static const Color zoneTempoColor = AppColors.orange;
  static const Color zoneAllOutColor = AppColors.dragonfruit;

  @override
  Widget build(BuildContext context) {
    // Validate that percentages sum to 100 (or close to it due to rounding)
    final total = conversationalPct + tempoPct + allOutPct;
    assert(
      total >= 99 && total <= 101,
      'Zone percentages must sum to 100 (got $total)',
    );

    // Calculate flex values (use at least 1 for zero percentages to avoid layout issues)
    final conversationalFlex = conversationalPct > 0 ? conversationalPct : 0;
    final tempoFlex = tempoPct > 0 ? tempoPct : 0;
    final allOutFlex = allOutPct > 0 ? allOutPct : 0;

    // Build semantic description of intensity distribution
    final semanticLabel =
        'Intensity distribution: '
        '$conversationalPct% conversational, '
        '$tempoPct% tempo, '
        '$allOutPct% all-out';

    return Semantics(
      label: semanticLabel,
      readOnly: true,
      child: Container(
        width: double.infinity,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(height / 2), // Fully rounded ends
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.2),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(height / 2),
          child: Row(
            children: [
              // Conversational zone (green)
              if (conversationalFlex > 0)
                Expanded(
                  flex: conversationalFlex,
                  child: Container(
                    color: enabled
                        ? zoneConversationalColor
                        : zoneConversationalColor.withValues(alpha: 0.4),
                  ),
                ),

              // Tempo zone (yellow)
              if (tempoFlex > 0)
                Expanded(
                  flex: tempoFlex,
                  child: Container(
                    color: enabled
                        ? zoneTempoColor
                        : zoneTempoColor.withValues(alpha: 0.4),
                  ),
                ),

              // All-Out zone (red)
              if (allOutFlex > 0)
                Expanded(
                  flex: allOutFlex,
                  child: Container(
                    color: enabled
                        ? zoneAllOutColor
                        : zoneAllOutColor.withValues(alpha: 0.4),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
